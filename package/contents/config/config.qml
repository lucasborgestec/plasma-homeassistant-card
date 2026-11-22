import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "go-home"
        source: "config/ConfigGeneral.qml"
    }
}
