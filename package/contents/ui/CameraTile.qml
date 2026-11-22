/*
    SPDX-License-Identifier: MIT
*/
import QtQuick
import QtQuick.Effects
import QtMultimedia
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Item {
    id: tile
    property string title
    property string source
    property bool active: true
    property bool off: false
    signal turnOn()
    signal failed()

    readonly property var player: playerLoader.item
    readonly property bool playing: tile.active && player !== null
                                    && player.playbackState === MediaPlayer.PlayingState
                                    && player.mediaStatus !== MediaPlayer.LoadingMedia
                                    && player.mediaStatus !== MediaPlayer.StalledMedia
                                    && player.hasVideo
    property bool hasFrame: false
    property bool runPlayer: true

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 10
        color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        VideoOutput {
            id: out
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            visible: tile.playing || (tile.runPlayer && !tile.active)
        }
        // Last frame, shown while paused / loading
        Image {
            id: lastFrame
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            visible: !tile.playing && tile.hasFrame && !tile.off
            cache: false
        }
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: frame.radius
        visible: false
        layer.enabled: true
    }

    // The player is recreated from scratch on every resume: stop()/play() on the
    // Qt FFmpeg backend stalls on live HLS streams.
    Loader {
        id: playerLoader
        active: tile.runPlayer && tile.source !== ""
        sourceComponent: MediaPlayer {
            videoOutput: out
            source: tile.source
            playbackOptions.playbackIntent: PlaybackOptions.LowLatencyStreaming
            Component.onCompleted: play()
            onErrorOccurred: (error, msg) => { console.warn("Home Assistant card:", tile.title, msg); restart.start(); }
            onMediaStatusChanged: {
                if (mediaStatus === MediaPlayer.EndOfMedia) restart.start();
                else if (mediaStatus === MediaPlayer.BufferedMedia) { tile.hasFrame = false; watchdog.restart(); }
            }
            onPositionChanged: watchdog.restart()
        }
    }

    // If the video stops advancing for 20 s, ask for a new url and recreate the player
    Timer { id: watchdog; interval: 20000; running: tile.active; onTriggered: tile.failed() }
    Timer { id: restart; interval: 5000; onTriggered: if (tile.active) tile.failed() }

    onOffChanged: if (off) { hasFrame = false; lastFrame.source = ""; }

    // Off state
    Column {
        anchors.centerIn: parent
        visible: tile.off
        spacing: 4
        Kirigami.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "camera-off-symbolic"
            implicitWidth: 28; implicitHeight: 28
            opacity: 0.6
        }
        PC3.Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: i18n("Click to turn on")
            font: Kirigami.Theme.smallFont
            opacity: 0.6
        }
    }

    onActiveChanged: {
        if (active) {
            runPlayer = true;
            return;
        }
        restart.stop();
        const wasPlaying = player !== null && player.playbackState === MediaPlayer.PlayingState && player.hasVideo;
        if (!wasPlaying) { runPlayer = false; return; }
        // Grab the last frame before destroying the player
        stopFallback.start();
        out.grabToImage(r => {
            lastFrame.source = r.url;
            tile.hasFrame = true;
            if (!tile.active) { stopFallback.stop(); tile.runPlayer = false; }
        });
    }
    Timer { id: stopFallback; interval: 1000; onTriggered: if (!tile.active) tile.runPlayer = false }

    PC3.BusyIndicator {
        anchors.centerIn: parent
        visible: !tile.playing && tile.active && !tile.off
        running: visible
        implicitWidth: 32; implicitHeight: 32
        opacity: 0.6
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 6
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.45)
        implicitWidth: lbl.implicitWidth + 16
        implicitHeight: lbl.implicitHeight + 4
        Row {
            anchors.centerIn: parent
            spacing: 5
            Rectangle {
                width: 6; height: 6; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: tile.playing ? "#ff453a" : "#8e8e93"
            }
            PC3.Label {
                id: lbl
                text: tile.title
                font: Kirigami.Theme.smallFont
                color: "white"
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.off ? tile.turnOn() : Qt.openUrlExternally(root.haUrl)
    }
}
