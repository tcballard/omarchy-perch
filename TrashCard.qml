import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var state: null
    property color ink: Color.foreground
    property color surface: Color.background
    spacing: Style.space(12)
    Text {
        text: root.state ? (root.state.trashPartial ? "At least " : "") + root.state.trashCount + " items in local Trash" : "Trash unavailable"
        color: root.ink
        font.pixelSize: Style.space(20)
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
    Text {
        text: "Open your file manager to restore or empty Trash. This count covers the home Trash; other mounted drives may have their own."
        color: Qt.alpha(root.ink, 0.65)
        font.pixelSize: Style.space(11)
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
    RowLayout {
        PerchAction {
            text: "Open Trash"
            enabled: !!root.state && !root.state.busy
            ink: root.ink
            surface: root.surface
            onClicked: root.state.request("dock-trash-open", {})
        }
        PerchAction {
            text: "Refresh"
            enabled: !!root.state && !root.state.busy
            ink: root.ink
            surface: root.surface
            onClicked: root.state.request("dock-trash", {})
        }
    }
    Text {
        text: root.state ? root.state.error : ""
        color: "#e47b76"
        font.pixelSize: Style.space(11)
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
    }
    Item {
        Layout.fillHeight: true
    }
}
