import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import "MediaPolicy.js" as Media

ColumnLayout {
    id: root
    property var live: null
    property color ink: Color.foreground
    property color surface: Color.background
    spacing: Style.space(14)
    Text {
        text: root.live && root.live.timerActive ? root.live.timerState.label : "Make time for one thing"
        color: root.ink
        font.pixelSize: Style.space(14)
        font.weight: Font.DemiBold
        textFormat: Text.PlainText
    }
    Text {
        Layout.fillWidth: true
        text: !root.live || !root.live.timerActive ? "25:00" : root.live.timerStatus === "done" ? "Time’s up" : Media.time(root.live.remaining)
        color: root.ink
        font.pixelSize: Style.space(40)
        horizontalAlignment: Text.AlignHCenter
        font.family: Style.font.family
    }
    Text {
        Layout.fillWidth: true
        text: root.live && root.live.timerActive ? root.live.timerStatus === "paused" ? "Paused — resume when you’re ready" : root.live.timerStatus === "done" ? "Take a breath. Your timer has finished." : "Keep working. Perch will keep the time." : "Start a timer. It keeps going when Perch closes."
        color: Qt.alpha(root.ink, 0.55)
        font.pixelSize: Style.space(11)
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }
    RowLayout {
        visible: !root.live || !root.live.timerActive
        Layout.fillWidth: true
        Repeater {
            model: [5, 15, 25]
            delegate: PerchAction {
                required property int modelData
                Layout.fillWidth: true
                text: modelData + " min"
                ink: root.ink
                surface: root.surface
                enabled: !!root.live
                onClicked: root.live.start(modelData * 60, "Focus")
            }
        }
    }
    RowLayout {
        visible: !root.live || !root.live.timerActive
        Layout.fillWidth: true
        Controls.SpinBox {
            id: minutes
            from: 1
            to: 1440
            value: 45
            editable: false
            Layout.fillWidth: true
            palette.text: root.ink
            palette.buttonText: root.ink
            palette.base: root.surface
            palette.button: root.surface
            Accessible.name: "Custom timer in minutes"
        }
        PerchAction {
            text: "Start minutes"
            ink: root.ink
            surface: root.surface
            enabled: !!root.live
            onClicked: root.live.start(minutes.value * 60, "Timer")
        }
    }
    RowLayout {
        visible: !!root.live && root.live.timerActive
        Layout.fillWidth: true
        PerchAction {
            Layout.fillWidth: true
            text: root.live && root.live.timerStatus === "done" ? "Done" : root.live && root.live.timerStatus === "paused" ? "Resume" : "Pause"
            selected: true
            ink: root.ink
            surface: root.surface
            onClicked: {
                if (root.live.timerStatus === "done")
                    root.live.cancel();
                else if (root.live.timerStatus === "paused")
                    root.live.resume();
                else
                    root.live.pause();
            }
        }
        PerchAction {
            visible: !!root.live && root.live.timerStatus !== "done"
            Layout.fillWidth: true
            text: "Cancel"
            ink: root.ink
            surface: root.surface
            onClicked: root.live.cancel()
        }
    }
    Text {
        Layout.fillWidth: true
        text: root.live ? root.live.error : "Timer service is loading"
        visible: text !== ""
        color: root.ink
        wrapMode: Text.WordWrap
        font.pixelSize: Style.space(10)
    }
}
