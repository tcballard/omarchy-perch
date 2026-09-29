import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var system: null
    property color ink: Color.foreground
    property color surface: Color.background
    spacing: Style.space(16)
    Text {
        text: "Sound"
        color: root.ink
        font.pixelSize: Style.space(14)
        font.weight: Font.DemiBold
    }
    Text {
        Layout.fillWidth: true
        text: root.system ? root.system.outputName : "Audio service loading"
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Qt.alpha(root.ink, 0.6)
        font.pixelSize: Style.space(11)
    }
    RowLayout {
        Layout.fillWidth: true
        PerchAction {
            text: root.system && root.system.muted ? "Unmute" : "Mute"
            ink: root.ink
            surface: root.surface
            enabled: !!root.system && root.system.audioAvailable
            onClicked: root.system.toggleMute()
        }
        PerchSlider {
            Layout.fillWidth: true
            ink: root.ink
            enabled: !!root.system && root.system.audioAvailable
            value: root.system ? root.system.volume : 0
            Accessible.name: "Output volume"
            onMoved: root.system.setVolume(value)
        }
        Text {
            text: root.system && root.system.audioAvailable ? Math.round(root.system.volume * 100) + "%" : "—"
            color: root.ink
            font.pixelSize: Style.space(11)
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Qt.alpha(root.ink, 0.1)
    }
    Text {
        text: "Power"
        color: root.ink
        font.pixelSize: Style.space(14)
        font.weight: Font.DemiBold
    }
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: root.system && root.system.batteryAvailable ? root.system.batteryPercent + "%" : "No battery"
            color: root.ink
            font.pixelSize: Style.space(30)
        }
        Text {
            Layout.fillWidth: true
            text: root.system && root.system.batteryAvailable ? root.system.charging ? "Charging" : root.system.onBattery ? "On battery" : "Plugged in" : "Battery information unavailable"
            color: Qt.alpha(root.ink, 0.55)
            font.pixelSize: Style.space(11)
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignRight
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Style.space(4)
        radius: 2
        color: Qt.alpha(root.ink, 0.1)
        Rectangle {
            width: parent.width * (root.system && root.system.batteryAvailable ? root.system.batteryPercent / 100 : 0)
            height: parent.height
            radius: 2
            color: root.ink
        }
    }
    Text {
        Layout.fillWidth: true
        text: root.system ? root.system.error : ""
        visible: text !== ""
        color: root.ink
        font.pixelSize: Style.space(10)
        wrapMode: Text.WordWrap
    }
}
