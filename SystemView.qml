import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

Controls.ScrollView {
    id: root
    property var system: null
    property var work: null
    property color ink: Color.foreground
    property color surface: Color.background
    signal popupToggled(bool open)
    clip: true
    contentWidth: availableWidth
    ColumnLayout {
        width: parent.width
        spacing: Style.space(10)
        Text {
            text: "Sound output"
            color: root.ink
            font.pixelSize: Style.space(14)
            font.bold: true
        }
        PerchCombo {
            ink: root.ink
            surface: root.surface
            onPopupToggled: open => root.popupToggled(open)
            Layout.fillWidth: true
            model: root.system && root.system.outputs ? root.system.outputs.map(function (n) {
                return n.description || n.name;
            }) : []
            currentIndex: root.system && root.system.outputs ? root.system.outputs.indexOf(root.system.sink) : -1
            displayText: currentIndex >= 0 ? currentText : root.system ? root.system.outputName : "No audio output"
            onActivated: index => root.system.selectOutput(index)
            Accessible.name: "Output device"
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
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "Microphone"
                color: root.ink
                font.pixelSize: Style.space(13)
            }
            PerchAction {
                text: root.system && root.system.microphoneMuted ? "Unmute mic" : "Mute mic"
                ink: root.ink
                surface: root.surface
                enabled: !!root.system && root.system.microphoneAvailable === true
                onClicked: root.system.toggleMicrophone()
            }
        }
        PerchCombo {
            ink: root.ink
            surface: root.surface
            onPopupToggled: open => root.popupToggled(open)
            Layout.fillWidth: true
            model: root.system && root.system.inputs ? root.system.inputs.map(function (n) {
                return n.description || n.name;
            }) : []
            currentIndex: root.system && root.system.inputs ? root.system.inputs.indexOf(root.system.source) : -1
            displayText: currentIndex >= 0 ? currentText : "No microphone"
            onActivated: index => root.system.selectInput(index)
            Accessible.name: "Input device"
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Brightness"
                color: root.ink
                font.pixelSize: Style.space(12)
            }
            PerchSlider {
                id: brightness
                Layout.fillWidth: true
                ink: root.ink
                from: 1
                to: 100
                value: root.work && root.work.brightnessValue >= 0 ? root.work.brightnessValue : 50
                enabled: !!root.work && root.work.brightnessValue >= 0 && !root.work.busy
                Accessible.name: "Display brightness"
                onPressedChanged: if (!pressed && enabled)
                    root.work.brightness(value)
                onMoved: if (!pressed && enabled)
                    root.work.brightness(value)
            }
            Text {
                text: root.work && root.work.brightnessValue >= 0 ? root.work.brightnessValue + "%" : "Unavailable"
                color: Qt.alpha(root.ink, 0.6)
                font.pixelSize: Style.space(10)
            }
        }
        Text {
            text: root.system && root.system.batteryAvailable ? "Battery · " + root.system.batteryPercent + "% · " + (root.system.charging ? "Charging" : root.system.onBattery ? "On battery" : "Plugged in") : "No battery"
            color: root.ink
            font.pixelSize: Style.space(12)
        }
        Text {
            text: "Bluetooth"
            color: root.ink
            font.pixelSize: Style.space(13)
            font.bold: true
        }
        Repeater {
            model: root.system && root.system.bluetoothDevices ? root.system.bluetoothDevices : []
            delegate: RowLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: modelData.name + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.ink
                    font.pixelSize: Style.space(11)
                }
                PerchAction {
                    text: modelData.connected ? "Disconnect" : "Connect"
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.system.toggleBluetooth(index)
                }
            }
        }
        Text {
            visible: !root.system || !root.system.bluetoothDevices || root.system.bluetoothDevices.length === 0
            text: "No paired Bluetooth devices"
            color: Qt.alpha(root.ink, 0.55)
            font.pixelSize: Style.space(11)
        }
        Text {
            Layout.fillWidth: true
            text: root.system ? root.system.error : ""
            textFormat: Text.PlainText
            visible: text !== ""
            color: root.ink
            wrapMode: Text.WordWrap
            font.pixelSize: Style.space(10)
        }
        Text {
            Layout.fillWidth: true
            text: root.work ? root.work.error : ""
            textFormat: Text.PlainText
            visible: text !== ""
            color: root.ink
            wrapMode: Text.WordWrap
            font.pixelSize: Style.space(10)
        }
    }
}
