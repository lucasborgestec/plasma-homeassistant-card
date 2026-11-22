/*
    SPDX-License-Identifier: MIT
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_haUrl: haUrl.text
    property alias cfg_token: token.text
    property alias cfg_tokenFile: tokenFile.text
    property string cfg_mode
    property alias cfg_sensorsTitle: sensorsTitle.text
    property alias cfg_sensors: sensors.text
    property alias cfg_refreshInterval: refreshInterval.value
    property alias cfg_warningTemperature: warnTemp.value
    property alias cfg_criticalTemperature: critTemp.value
    property alias cfg_networkTitle: networkTitle.text
    property alias cfg_downloadEntity: downloadEntity.text
    property alias cfg_uploadEntity: uploadEntity.text
    property alias cfg_cameras: cameras.text
    property alias cfg_pauseWhenCovered: pauseWhenCovered.checked

    // Unused here but declared so the config dialog doesn't warn about them.
    property bool cfg_camerasEnabled
    property bool cfg_camerasEnabledDefault
    property string cfg_haUrlDefault
    property string cfg_tokenDefault
    property string cfg_tokenFileDefault
    property string cfg_modeDefault
    property string cfg_sensorsTitleDefault
    property string cfg_sensorsDefault
    property int cfg_refreshIntervalDefault
    property int cfg_warningTemperatureDefault
    property int cfg_criticalTemperatureDefault
    property string cfg_networkTitleDefault
    property string cfg_downloadEntityDefault
    property string cfg_uploadEntityDefault
    property string cfg_camerasDefault
    property bool cfg_pauseWhenCoveredDefault

    readonly property bool cameraMode: cfg_mode === "cameras"

    // --- "Test connection"
    property string testResult: ""
    function testConnection() {
        testResult = i18n("Testing…");
        const doTest = (tok) => {
            const xhr = new XMLHttpRequest();
            xhr.open("GET", haUrl.text.replace(/\/+$/, "") + "/api/");
            xhr.setRequestHeader("Authorization", "Bearer " + tok);
            xhr.onreadystatechange = () => {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                testResult = xhr.status === 200 ? i18n("Connected ✓")
                           : xhr.status === 401 ? i18n("Invalid token (401)")
                           : xhr.status === 0 ? i18n("Can't reach the server")
                           : i18n("HTTP error %1", xhr.status);
            };
            xhr.send();
        };
        if (token.text.trim() !== "") {
            doTest(token.text.trim());
        } else {
            testResult = i18n("Using the token file — save and check the widget itself.");
        }
    }

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Home Assistant") }

        QQC2.TextField {
            id: haUrl
            Kirigami.FormData.label: i18n("URL:")
            placeholderText: "http://homeassistant.local:8123"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        }
        QQC2.TextField {
            id: token
            Kirigami.FormData.label: i18n("Access token:")
            echoMode: TextInput.Password
            placeholderText: i18n("Paste a long-lived access token, or leave empty to use the file below")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        }
        QQC2.TextField {
            id: tokenFile
            Kirigami.FormData.label: i18n("…or token file:")
            enabled: token.text.trim() === ""
            placeholderText: "~/.config/homeassistant/token"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        }
        RowLayout {
            QQC2.Button {
                text: i18n("Test connection")
                icon.name: "network-connect"
                onClicked: page.testConnection()
            }
            QQC2.Label { text: page.testResult }
        }
        QQC2.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("Create the token in Home Assistant: your profile → Security → Long-lived access tokens. A token typed here is stored in plain text in the Plasma config; a file (chmod 600) keeps it out of it.")
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Content") }

        QQC2.ComboBox {
            id: modeBox
            Kirigami.FormData.label: i18n("This widget shows:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Sensors and network"), value: "sensors" },
                { text: i18n("Cameras"), value: "cameras" }
            ]
            currentIndex: page.cfg_mode === "cameras" ? 1 : 0
            onActivated: page.cfg_mode = currentValue
        }

        // ---------- Sensors mode
        QQC2.TextField {
            id: sensorsTitle
            visible: !page.cameraMode
            Kirigami.FormData.label: i18n("Sensors title:")
            placeholderText: i18n("Sensors")
        }
        QQC2.TextArea {
            id: sensors
            visible: !page.cameraMode
            Kirigami.FormData.label: i18n("Sensors:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            Layout.preferredHeight: Kirigami.Units.gridUnit * 6
            font.family: "monospace"
            placeholderText: "sensor.cpu_temperature ; Server ; network-server-symbolic\nsensor.living_room_temperature ; Living room"
        }
        QQC2.Label {
            visible: !page.cameraMode
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("One entity per line: entity_id ; label ; icon. Label and icon are optional.")
        }
        RowLayout {
            visible: !page.cameraMode
            Kirigami.FormData.label: i18n("Temperature colors:")
            QQC2.Label { text: i18n("warning from") }
            QQC2.SpinBox { id: warnTemp; from: -50; to: 200 }
            QQC2.Label { text: i18n("critical from") }
            QQC2.SpinBox { id: critTemp; from: -50; to: 200 }
        }
        QQC2.SpinBox {
            id: refreshInterval
            visible: !page.cameraMode
            Kirigami.FormData.label: i18n("Refresh every (s):")
            from: 1; to: 3600
        }
        QQC2.TextField {
            id: networkTitle
            visible: !page.cameraMode
            Kirigami.FormData.label: i18n("Network title:")
            placeholderText: i18n("Network")
        }
        QQC2.TextField {
            id: downloadEntity
            visible: !page.cameraMode
            Kirigami.FormData.label: i18n("Download entity:")
            placeholderText: "sensor.router_wan_download"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        }
        QQC2.TextField {
            id: uploadEntity
            visible: !page.cameraMode
            Kirigami.FormData.label: i18n("Upload entity:")
            placeholderText: "sensor.router_wan_upload"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        }

        // ---------- Cameras mode
        QQC2.TextArea {
            id: cameras
            visible: page.cameraMode
            Kirigami.FormData.label: i18n("Cameras:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            Layout.preferredHeight: Kirigami.Units.gridUnit * 5
            font.family: "monospace"
            placeholderText: "camera.front_door ; Front door\ncamera.living_room ; Living room"
        }
        QQC2.Label {
            visible: page.cameraMode
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("One camera per line: entity_id ; label. Cameras start turned off; click a tile to start streaming and use the power button to stop.")
        }
        QQC2.CheckBox {
            id: pauseWhenCovered
            visible: page.cameraMode
            Kirigami.FormData.label: i18n("Save resources:")
            text: i18n("Pause video while a window covers the widget")
        }
    }
}
