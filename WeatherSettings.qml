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
    RowLayout {
        Layout.fillWidth: true
        Controls.TextField {
            id: city
            Layout.fillWidth: true
            placeholderText: "Search city"
            maximumLength: 100
            color: root.ink
            palette.base: root.surface
            onAccepted: if (root.state)
                root.state.searchLocation(text)
        }
        PerchAction {
            text: "Search"
            enabled: !!root.state && !root.state.locationBusy
            ink: root.ink
            surface: root.surface
            onClicked: root.state.searchLocation(city.text)
        }
    }
    Repeater {
        model: root.state && root.state.locations !== undefined ? root.state.locations : []
        delegate: PerchAction {
            required property var modelData
            Layout.fillWidth: true
            text: modelData.name + " · " + modelData.detail
            ink: root.ink
            surface: root.surface
            onClicked: {
                location.text = modelData.name;
                latitude.text = String(modelData.latitude);
                longitude.text = String(modelData.longitude);
                root.state.locations = [];
            }
        }
    }
    Text {
        visible: text !== ""
        text: root.state && root.state.locationError !== undefined ? root.state.locationError : ""
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: root.ink
        font.pixelSize: Style.space(11)
        textFormat: Text.PlainText
    }
    RowLayout {
        PerchAction {
            text: "Celsius"
            ink: root.ink
            surface: root.surface
            selected: !!root.state && root.state.temperatureUnit !== "F"
            onClicked: root.state.setUnit("C")
        }
        PerchAction {
            text: "Fahrenheit"
            ink: root.ink
            surface: root.surface
            selected: !!root.state && root.state.temperatureUnit === "F"
            onClicked: root.state.setUnit("F")
        }
    }
    Controls.TextField {
        id: location
        Layout.fillWidth: true
        placeholderText: PerchStrings.t("Location label")
        maximumLength: 80
        text: root.state ? root.state.weatherConfig.name || "" : ""
        color: root.ink
        palette.base: root.surface
    }
    RowLayout {
        Controls.TextField {
            id: latitude
            Layout.fillWidth: true
            placeholderText: PerchStrings.t("Latitude")
            maximumLength: 12
            text: root.state && root.state.weatherConfig.latitude !== undefined ? String(root.state.weatherConfig.latitude) : ""
            color: root.ink
            palette.base: root.surface
        }
        Controls.TextField {
            id: longitude
            Layout.fillWidth: true
            placeholderText: PerchStrings.t("Longitude")
            maximumLength: 12
            text: root.state && root.state.weatherConfig.longitude !== undefined ? String(root.state.weatherConfig.longitude) : ""
            color: root.ink
            palette.base: root.surface
        }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: PerchStrings.t("City search sends its text to geocoding-api.open-meteo.com. Enabling sends these coordinates to api.open-meteo.com. No automatic location lookup. Updates every 15 minutes while visible.")
        color: root.ink
        font.pixelSize: Style.space(11)
    }
    RowLayout {
        PerchAction {
            text: PerchStrings.t("Save & enable")
            ink: root.ink
            surface: root.surface
            onClicked: if (root.state)
                root.state.saveWeather(location.text, latitude.text, longitude.text, true)
        }
        PerchAction {
            text: PerchStrings.t("Disable")
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
