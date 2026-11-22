/*
    SPDX-License-Identifier: MIT
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    preferredRepresentation: fullRepresentation

    readonly property string haUrl: Plasmoid.configuration.haUrl.replace(/\/+$/, "")
    readonly property string inlineToken: Plasmoid.configuration.token.trim()
    property string fileToken: ""
    readonly property string token: inlineToken !== "" ? inlineToken : fileToken
    readonly property bool cameraMode: Plasmoid.configuration.mode === "cameras"

    // Reads the token from a file so it doesn't have to live in the Plasma config.
    function readTokenFile() {
        const path = Plasmoid.configuration.tokenFile.trim();
        if (inlineToken !== "" || path === "") {
            return;
        }
        // Expand a leading "~" and quote the rest for the shell.
        const expanded = path.startsWith("~/") ? '"$HOME"/' + shellQuote(path.slice(2)) : shellQuote(path);
        exec.connectSource("cat -- " + expanded);
    }
    function shellQuote(s) {
        const q = String.fromCharCode(39);                 // single quote
        return q + s.split(q).join(q + "\\" + q + q) + q;  // ' -> '\''
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            root.fileToken = (data["stdout"] || "").trim();
            disconnectSource(source);
        }
    }
    Component.onCompleted: readTokenFile()
    Connections {
        target: Plasmoid.configuration
        function onTokenFileChanged() { root.readTokenFile(); }
        function onTokenChanged() { root.readTokenFile(); }
    }

    // GET /api/states/<entity_id>; cb receives the parsed state object or null.
    function getState(entityId, cb) {
        if (!token) {
            return;
        }
        const xhr = new XMLHttpRequest();
        xhr.open("GET", haUrl + "/api/states/" + encodeURIComponent(entityId));
        xhr.setRequestHeader("Authorization", "Bearer " + token);
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            if (xhr.status === 200) {
                try { cb(JSON.parse(xhr.responseText)); } catch (e) { cb(null); }
            } else {
                cb(null);
            }
        };
        xhr.send();
    }

    toolTipMainText: Plasmoid.title
    toolTipSubText: token === "" ? i18n("No Home Assistant token configured") : haUrl

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: Kirigami.Units.gridUnit * 12
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        Layout.preferredHeight: Kirigami.Units.gridUnit * 17

        Loader {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            source: root.cameraMode ? "CamerasView.qml" : "SensorsView.qml"
        }
    }
}
