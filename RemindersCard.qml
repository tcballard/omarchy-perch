import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

Controls.ScrollView {
    id: root
    property var state: null
    property color ink: Color.foreground
    property color surface: Color.background
    property string selectedList: "All lists"
    property bool showDone: false
    implicitHeight: Style.space(300)
    contentWidth: availableWidth
    clip: true
    ColumnLayout {
        width: root.availableWidth
        spacing: Style.space(8)
        RowLayout {
            Layout.fillWidth: true
            Controls.TextField {
                id: title
                Layout.fillWidth: true
                placeholderText: "Add a reminder"
                maximumLength: 200
                color: root.ink
                palette.base: root.surface
                onAccepted: if (root.state && root.state.addReminder(text, list.text, 0))
                    clear()
            }
            PerchAction {
                text: "Add"
                enabled: !!root.state && !root.state.busy
                ink: root.ink
                surface: root.surface
                onClicked: if (root.state.addReminder(title.text, list.text, 0))
                    title.clear()
            }
        }
        Controls.TextField {
            id: list
            Layout.fillWidth: true
            placeholderText: "List name · Personal"
            maximumLength: 60
            color: root.ink
            palette.base: root.surface
        }
        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: childrenRect.height
            spacing: Style.space(4)
            Repeater {
                model: root.state ? ["All lists"].concat(root.state.reminders.map(r => r.list).filter((v, i, a) => a.indexOf(v) === i)) : []
                delegate: PerchAction {
                    required property string modelData
                    text: modelData
                    selected: root.selectedList === modelData
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.selectedList = modelData
                }
            }
        }
        PerchToggle {
            text: "Show completed"
            checked: root.showDone
            ink: root.ink
            surface: root.surface
            onToggled: root.showDone = checked
        }
        Repeater {
            model: root.state ? root.state.reminders.filter(r => (root.showDone || !r.done) && (root.selectedList === "All lists" || r.list === root.selectedList)) : []
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                PerchAction {
                    text: modelData.done ? "✓" : "○"
                    Accessible.name: (modelData.done ? "Reopen " : "Complete ") + modelData.title
                    ink: root.ink
                    surface: root.surface
                    enabled: !root.state.busy
                    onClicked: root.state.complete(modelData)
                }
                Text {
                    text: modelData.title
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    color: root.ink
                    font.pixelSize: Style.space(12)
                    font.strikeout: modelData.done
                }
                PerchAction {
                    text: "Remove"
                    visible: modelData.done
                    enabled: !root.state.busy
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.state.request("dock-reminders-remove", {
                        id: modelData.id
                    })
                }
            }
        }
        Text {
            visible: !!root.state && !root.state.remainingCount
            text: "All clear. Add something you want to remember."
            color: Qt.alpha(root.ink, 0.6)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            font.pixelSize: Style.space(12)
        }
        PerchAction {
            text: "Undo completion"
            visible: !!root.state && !!root.state.undoReminder
            ink: root.ink
            surface: root.surface
            onClicked: root.state.undoComplete()
        }
        Text {
            text: root.state ? root.state.error : "Reminders unavailable"
            color: "#e47b76"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            font.pixelSize: Style.space(11)
            textFormat: Text.PlainText
        }
    }
}
