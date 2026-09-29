import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var state: null
    property color ink: Color.foreground
    property color surface: Color.background
    spacing: Style.space(7)
    Controls.TextField {
        id: location
        Layout.fillWidth: true
        placeholderText: "Location label"
        maximumLength: 80
        text: root.state ? root.state.weatherConfig.name || "" : ""
        color: root.ink
        palette.base: root.surface
    }
    RowLayout {
        Controls.TextField {
            id: latitude
            Layout.fillWidth: true
            placeholderText: "Latitude"
            maximumLength: 12
            text: root.state && root.state.weatherConfig.latitude !== undefined ? String(root.state.weatherConfig.latitude) : ""
            color: root.ink
            palette.base: root.surface
        }
        Controls.TextField {
            id: longitude
            Layout.fillWidth: true
            placeholderText: "Longitude"
            maximumLength: 12
            text: root.state && root.state.weatherConfig.longitude !== undefined ? String(root.state.weatherConfig.longitude) : ""
            color: root.ink
            palette.base: root.surface
        }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "Enabling sends these coordinates to api.open-meteo.com. No automatic location lookup. Updates every 15 minutes while visible."
        color: root.ink
        font.pixelSize: Style.space(11)
    }
    RowLayout {
        PerchAction {
            text: "Save & enable"
            ink: root.ink
            surface: root.surface
            onClicked: if (root.state)
                root.state.saveWeather(location.text, latitude.text, longitude.text, true)
        }
        PerchAction {
            text: "Disable"
            ink: root.ink
            surface: root.surface
            onClicked: if (root.state)
                root.state.saveWeather(location.text, latitude.text, longitude.text, false)
        }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: root.state ? root.state.weatherError || (root.state.preferences ? root.state.preferences.error : "") : ""
        textFormat: Text.PlainText
        color: root.ink
        font.pixelSize: Style.space(11)
    }
    Item {
        Layout.fillHeight: true
    }
}
