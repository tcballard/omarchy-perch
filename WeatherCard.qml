import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var state: null
    property color ink: Color.foreground
    property color surface: Color.background
    function condition(code) {
        if (code === 0)
            return "Clear sky";
        if (code <= 3)
            return "Cloudy";
        if (code <= 48)
            return "Fog";
        if (code <= 67)
            return "Rain or drizzle";
        if (code <= 77)
            return "Snow";
        if (code <= 82)
            return "Rain showers";
        if (code <= 86)
            return "Snow showers";
        return "Thunderstorms";
    }
    spacing: Style.space(10)
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: root.state && root.state.weatherEnabled ? root.state.weatherConfig.name || "Selected location" : "Choose Configure to enable weather for a location."
        color: root.ink
        font.pixelSize: Style.space(14)
    }
    Text {
        visible: !!root.state && !!root.state.weather
        text: visible ? Math.round(root.state.weather.temperature) + "°C · " + root.condition(root.state.weather.code) : ""
        color: root.ink
        font.pixelSize: Style.space(24)
    }
    Text {
        visible: !!root.state && !!root.state.weather
        text: visible ? "Wind " + root.state.weather.wind + " km/h" : ""
        color: root.ink
        font.pixelSize: Style.space(12)
    }
    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: root.state && root.state.weather ? root.state.weather.hours : []
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                Text {
                    text: modelData.time.slice(11)
                    color: Qt.alpha(root.ink, 0.6)
                    font.pixelSize: Style.space(10)
                }
                Text {
                    text: Math.round(modelData.temperature) + "°"
                    color: root.ink
                    font.pixelSize: Style.space(15)
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: !root.state ? "Weather unavailable" : root.state.weatherError + (root.state.weather && root.state.weatherError ? " Showing previous data." : "") || (root.state.weatherBusy ? "Updating…" : root.state.weatherUpdated ? "Updated " + new Date(root.state.weatherUpdated).toLocaleTimeString() : "")
        color: Qt.alpha(root.ink, 0.65)
        font.pixelSize: Style.space(11)
    }
    Item {
        Layout.fillHeight: true
    }
    Text {
        text: "Weather: Open-Meteo · CC BY 4.0"
        color: Qt.alpha(root.ink, 0.55)
        font.pixelSize: Style.space(10)
    }
}
