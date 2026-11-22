/*
    SPDX-License-Identifier: MIT
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.quickcharts as Charts

import "../code/entities.js" as Entities

ColumnLayout {
    id: view
    spacing: Kirigami.Units.smallSpacing

    readonly property var sensors: Entities.parseLines(Plasmoid.configuration.sensors)
    readonly property string rxId: Plasmoid.configuration.downloadEntity.trim()
    readonly property string txId: Plasmoid.configuration.uploadEntity.trim()
    readonly property bool hasNetwork: rxId !== "" || txId !== ""
    readonly property int warnTemp: Plasmoid.configuration.warningTemperature
    readonly property int critTemp: Plasmoid.configuration.criticalTemperature

    property var states: ({})          // entity_id -> HA state object
    property bool online: false
    property bool failed: false

    readonly property int histLen: 60
    property var rxHist: Array(histLen).fill(0)
    property var txHist: Array(histLen).fill(0)

    function setState(id, s) {
        let o = Object.assign({}, states);
        o[id] = s;
        states = o;
        if (s) { online = true; failed = false; } else if (!online) { failed = true; }
    }

    function refresh() {
        sensors.forEach(t => root.getState(t.id, s => setState(t.id, s)));
        if (rxId) root.getState(rxId, s => { setState(rxId, s); rxHist = [rateMbit(s) || 0, ...rxHist.slice(0, histLen - 1)]; });
        if (txId) root.getState(txId, s => { setState(txId, s); txHist = [rateMbit(s) || 0, ...txHist.slice(0, histLen - 1)]; });
    }

    function num(s) { return s ? parseFloat(s.state) : NaN; }
    function unitOf(s) { return s && s.attributes ? (s.attributes.unit_of_measurement || "") : ""; }
    function rateMbit(s) { return Entities.toMbit(num(s), unitOf(s)); }

    function fmtValue(s) {
        if (!s) return "–";
        const v = num(s), u = unitOf(s);
        if (isNaN(v)) return s.state;               // text states ("on", "home", …)
        const digits = Math.abs(v) >= 100 || Number.isInteger(v) ? 0 : 1;
        let txt = Entities.isTemperatureUnit(u) ? String(Math.round(v)) : v.toLocaleString(Qt.locale(), 'f', digits);
        return u ? txt + " " + u : txt;
    }
    function fmtRate(s) {
        if (!s) return "–";
        const mbit = rateMbit(s);
        if (isNaN(mbit)) return fmtValue(s);
        if (mbit < 1) return i18nc("network rate", "%1 kb/s", Math.round(mbit * 1000));
        return i18nc("network rate", "%1 Mb/s", mbit.toLocaleString(Qt.locale(), 'f', mbit < 10 ? 1 : 0));
    }
    function valueColor(s) {
        const v = num(s);
        if (!Entities.isTemperatureUnit(unitOf(s)) || isNaN(v)) return Kirigami.Theme.textColor;
        return v >= critTemp ? Kirigami.Theme.negativeTextColor
             : v >= warnTemp ? Kirigami.Theme.neutralTextColor
             : Kirigami.Theme.textColor;
    }
    function defaultIcon(s) {
        const dc = s && s.attributes ? s.attributes.device_class : "";
        switch (dc) {
            case "temperature": return "temperature-normal";
            case "humidity": return "weather-showers-symbolic";
            case "power": case "energy": return "battery-full-charging-symbolic";
            case "battery": return "battery-good-symbolic";
            case "data_rate": return "network-transmit-receive-symbolic";
            default: return "view-statistics-symbolic";
        }
    }

    Timer {
        interval: Math.max(1, Plasmoid.configuration.refreshInterval) * 1000
        repeat: true
        running: root.token !== ""
        triggeredOnStart: true
        onTriggered: view.refresh()
    }

    // --- Sensors
    PC3.Label {
        visible: view.sensors.length > 0
        text: Plasmoid.configuration.sensorsTitle || i18n("Sensors")
        font: Kirigami.Theme.smallFont
        opacity: 0.6
        Layout.leftMargin: Kirigami.Units.smallSpacing
    }
    Repeater {
        model: view.sensors
        delegate: RowLayout {
            required property var modelData
            readonly property var st: view.states[modelData.id] ?? null
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing * 2
            Kirigami.Icon {
                source: modelData.icon || view.defaultIcon(st)
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                opacity: 0.8
            }
            PC3.Label {
                Layout.fillWidth: true
                text: modelData.name || (st && st.attributes && st.attributes.friendly_name) || Entities.prettyId(modelData.id)
                elide: Text.ElideRight
            }
            PC3.Label {
                text: view.fmtValue(st)
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: view.valueColor(st)
            }
        }
    }

    Kirigami.Separator {
        visible: view.sensors.length > 0 && view.hasNetwork
        Layout.fillWidth: true
        opacity: 0.5
        Layout.topMargin: 2
        Layout.bottomMargin: 2
    }

    // --- Network
    PC3.Label {
        visible: view.hasNetwork
        text: Plasmoid.configuration.networkTitle || i18n("Network")
        font: Kirigami.Theme.smallFont
        opacity: 0.6
        Layout.leftMargin: Kirigami.Units.smallSpacing
    }
    RowLayout {
        visible: view.hasNetwork
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        Kirigami.Icon { visible: view.rxId !== ""; source: "go-down-symbolic"; implicitWidth: 16; implicitHeight: 16; color: Kirigami.Theme.highlightColor }
        PC3.Label { visible: view.rxId !== ""; text: view.fmtRate(view.states[view.rxId]); font.weight: Font.DemiBold; font.features: { "tnum": 1 }; Layout.fillWidth: true }
        Kirigami.Icon { visible: view.txId !== ""; source: "go-up-symbolic"; implicitWidth: 16; implicitHeight: 16; color: Kirigami.Theme.positiveTextColor }
        PC3.Label { visible: view.txId !== ""; text: view.fmtRate(view.states[view.txId]); font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
    }
    Charts.LineChart {
        visible: view.hasNetwork
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 30
        direction: Charts.XYChart.ZeroAtEnd
        interpolate: true
        fillOpacity: 0.15
        lineWidth: 1.5
        yRange { automatic: true; minimum: 1 }
        valueSources: [
            Charts.ArraySource { array: view.rxHist },
            Charts.ArraySource { array: view.txHist }
        ]
        colorSource: Charts.ArraySource { array: [Kirigami.Theme.highlightColor, Kirigami.Theme.positiveTextColor] }
    }

    Item { Layout.fillHeight: true; visible: !view.hasNetwork }

    // --- Status / first-run hints
    PC3.Label {
        visible: root.token === "" || view.failed || (view.sensors.length === 0 && !view.hasNetwork)
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.token === "" ? i18n("Set a Home Assistant token in the widget settings.")
            : (view.sensors.length === 0 && !view.hasNetwork) ? i18n("Add some entities in the widget settings.")
            : i18n("Can't reach Home Assistant at %1", root.haUrl)
        font: Kirigami.Theme.smallFont
        opacity: 0.6
    }
}
