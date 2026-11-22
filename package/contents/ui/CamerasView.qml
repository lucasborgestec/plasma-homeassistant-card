/*
    SPDX-License-Identifier: MIT
*/
import QtQuick
import QtQuick.Layouts
import QtWebSockets
import org.kde.taskmanager as TaskManager
import org.kde.kwindowsystem as KWS
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3

import "../code/entities.js" as Entities

ColumnLayout {
    id: view
    spacing: Kirigami.Units.smallSpacing

    readonly property var cams: Entities.parseLines(Plasmoid.configuration.cameras)
    property var urls: ({})            // camera entity_id -> HLS url
    property int msgId: 1

    // Manual on/off switch (persisted). Off = no connection to Home Assistant at all.
    readonly property bool camsOn: Plasmoid.configuration.camerasEnabled
    onCamsOnChanged: if (!camsOn) urls = ({})
    function setCams(on) { Plasmoid.configuration.camerasEnabled = on; }

    onCamsChanged: {
        urls = ({});
        if (ws.authed) cams.forEach(c => requestStream(c.id));
    }

    // --- Only play while the card is visible (no window on top of it)
    property rect globalRect: Qt.rect(0, 0, 0, 0)
    function updateRect() {
        const p = view.mapToGlobal(0, 0);
        globalRect = Qt.rect(Math.round(p.x), Math.round(p.y), Math.round(view.width), Math.round(view.height));
    }
    onWidthChanged: updateRect()
    onHeightChanged: updateRect()
    Component.onCompleted: Qt.callLater(updateRect)
    Timer { interval: 3000; repeat: true; running: Plasmoid.configuration.pauseWhenCovered; onTriggered: view.updateRect() }

    TaskManager.VirtualDesktopInfo { id: vdInfo }
    TaskManager.ActivityInfo { id: actInfo }
    TaskManager.TasksModel {
        id: coveringWindows
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: true
        virtualDesktop: vdInfo.currentDesktop
        filterByActivity: true
        activity: actInfo.currentActivity
        filterMinimized: true
        filterHidden: true
        filterByRegion: TaskManager.RegionFilterMode.Intersect
        regionGeometry: view.globalRect
    }
    readonly property bool cardVisible: !Plasmoid.configuration.pauseWhenCovered
                                        || KWS.KWindowSystem.showingDesktop
                                        || coveringWindows.count === 0

    // --- Home Assistant websocket: asks for an HLS url per camera ("camera/stream")
    function wsUrl() { return root.haUrl.replace(/^http/, "ws") + "/api/websocket"; }

    function requestStream(camId) {
        if (ws.status !== WebSocket.Open || !ws.authed) return;
        const id = msgId++;
        ws.pending[id] = camId;
        ws.sendTextMessage(JSON.stringify({ id: id, type: "camera/stream", entity_id: camId }));
    }

    WebSocket {
        id: ws
        property bool authed: false
        property var pending: ({})
        url: view.wsUrl()
        active: root.token !== "" && view.camsOn && view.cams.length > 0
        onStatusChanged: {
            if (ws.status === WebSocket.Closed || ws.status === WebSocket.Error) {
                authed = false;
                pending = ({});
                if (view.camsOn) reconnect.start();
            }
        }
        onTextMessageReceived: msg => {
            const m = JSON.parse(msg);
            if (m.type === "auth_required") {
                sendTextMessage(JSON.stringify({ type: "auth", access_token: root.token }));
            } else if (m.type === "auth_ok") {
                authed = true;
                view.cams.forEach(c => view.requestStream(c.id));
            } else if (m.type === "auth_invalid") {
                console.warn("Home Assistant card: invalid token");
            } else if (m.type === "result" && pending[m.id]) {
                const cam = pending[m.id];
                delete pending[m.id];
                if (m.success) {
                    let o = Object.assign({}, view.urls);
                    o[cam] = root.haUrl + m.result.url;
                    view.urls = o;
                } else {
                    console.warn("Home Assistant card: no stream for", cam, m.error ? m.error.message : "");
                    retryTimer.start();
                }
            }
        }
    }
    Timer {
        id: reconnect
        interval: 10000
        onTriggered: {
            if (!view.camsOn) return;
            ws.active = false;
            ws.active = Qt.binding(() => root.token !== "" && view.camsOn && view.cams.length > 0);
        }
    }
    Timer { id: retryTimer; interval: 10000; onTriggered: view.cams.forEach(c => { if (!view.urls[c.id]) view.requestStream(c.id); }) }

    Repeater {
        model: view.cams
        delegate: CameraTile {
            required property var modelData
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: modelData.name || Entities.prettyId(modelData.id)
            active: view.cardVisible && view.camsOn
            off: !view.camsOn
            onTurnOn: view.setCams(true)
            source: view.urls[modelData.id] ?? ""
            onFailed: {
                // HLS session expired or dropped: ask for a fresh one
                let o = Object.assign({}, view.urls); delete o[modelData.id]; view.urls = o;
                view.requestStream(modelData.id);
            }
        }
    }

    PC3.Label {
        visible: view.cams.length === 0 || root.token === ""
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
        text: root.token === "" ? i18n("Set a Home Assistant token in the widget settings.")
                                : i18n("Add some cameras in the widget settings.")
        font: Kirigami.Theme.smallFont
        opacity: 0.6
    }

    // Power button (top-right corner of the card)
    PC3.ToolButton {
        parent: view.parent
        visible: view.camsOn && view.cams.length > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Kirigami.Units.smallSpacing
        z: 10
        icon.name: "system-shutdown-symbolic"
        icon.color: "white"
        display: PC3.AbstractButton.IconOnly
        text: i18n("Turn cameras off")
        PC3.ToolTip.text: text
        PC3.ToolTip.visible: hovered
        PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
        onClicked: view.setCams(false)
        background: Rectangle { radius: height / 2; color: Qt.rgba(0, 0, 0, parent.hovered ? 0.6 : 0.4) }
    }
}
