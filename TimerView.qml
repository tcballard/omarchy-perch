import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import "MediaPolicy.js" as Media

Controls.ScrollView {
    id: root
    property var live: null
    property color ink: Color.foreground
    property color surface: Color.background
    property bool adding: false
    clip: true
    contentWidth: availableWidth
    ColumnLayout {
        width: parent.width
        spacing: Style.space(10)
        RowLayout {
            Layout.fillWidth: true
            Controls.ComboBox {
                Layout.fillWidth: true
                visible: !!root.live && root.live.timers !== undefined && root.live.timers.length > 0
                model: root.live && root.live.timers ? root.live.timers.map(function (t) {
                    return t.label + (t.status === "done" ? " · finished" : "");
                }) : []
                currentIndex: root.live && root.live.timers ? root.live.timers.findIndex(function (t) {
                    return t.id === root.live.selectedTimer;
                }) : -1
                palette.button: root.surface
                palette.buttonText: root.ink
                palette.text: root.ink
                palette.base: root.surface
                onActivated: index => root.live.chooseTimer(root.live.timers[index].id)
                Accessible.name: "Selected timer"
            }
            PerchAction {
                text: root.adding ? "Back" : "New timer"
                ink: root.ink
                surface: root.surface
                onClicked: root.adding = !root.adding
            }
        }
        Text {
            Layout.fillWidth: true
            text: root.live && root.live.timerActive ? root.live.timerState.label : "Make time for one thing"
            textFormat: Text.PlainText
            color: root.ink
            font.pixelSize: Style.space(14)
            font.bold: true
        }
        Text {
            Layout.fillWidth: true
            visible: !root.adding
            text: !root.live || !root.live.timerActive ? "25:00" : root.live.timerStatus === "done" ? "Time’s up" : Media.time(root.live.remaining)
            color: root.ink
            font.pixelSize: Style.space(40)
            horizontalAlignment: Text.AlignHCenter
        }
        RowLayout {
            visible: !!root.live && root.live.timerActive && !root.adding
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
                Layout.fillWidth: true
                text: "Cancel"
                visible: !!root.live && root.live.timerStatus !== "done"
                ink: root.ink
                surface: root.surface
                onClicked: root.live.cancel()
            }
        }
        RowLayout {
            visible: !!root.live && root.live.timerStatus === "done" && !root.adding
            Layout.fillWidth: true
            PerchAction {
                Layout.fillWidth: true
                text: "Snooze 5m"
                ink: root.ink
                surface: root.surface
                onClicked: root.live.snooze(300)
            }
            PerchAction {
                Layout.fillWidth: true
                text: "Repeat"
                ink: root.ink
                surface: root.surface
                onClicked: root.live.repeatTimer()
            }
        }
        ColumnLayout {
            visible: root.adding || !root.live || !root.live.timerActive
            Layout.fillWidth: true
            Controls.TextField {
                id: label
                Layout.fillWidth: true
                placeholderText: "Name your timer"
                maximumLength: 80
                color: root.ink
                palette.base: root.surface
                Accessible.name: "Timer name"
            }
            RowLayout {
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
                        onClicked: if (root.live.add(modelData * 60, label.text || "Focus"))
                            root.adding = false
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Controls.SpinBox {
                    id: minutes
                    from: 1
                    to: 1440
                    value: 45
                    Layout.fillWidth: true
                    palette.text: root.ink
                    palette.buttonText: root.ink
                    palette.base: root.surface
                    palette.button: root.surface
                    Accessible.name: "Custom timer in minutes"
                }
                PerchAction {
                    text: "Start"
                    ink: root.ink
                    surface: root.surface
                    enabled: !!root.live
                    onClicked: if (root.live.add(minutes.value * 60, label.text || "Timer"))
                        root.adding = false
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: root.live ? root.live.error : "Timer service is loading"
            textFormat: Text.PlainText
            visible: text !== ""
            color: root.ink
            wrapMode: Text.WordWrap
            font.pixelSize: Style.space(10)
        }
        Text {
            Layout.fillWidth: true
            text: "Up to eight timers. Timers continue while Perch is closed. Completion options are in Settings."
            color: Qt.alpha(root.ink, 0.5)
            wrapMode: Text.WordWrap
            font.pixelSize: Style.space(10)
        }
    }
}
