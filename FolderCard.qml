import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

Controls.ScrollView {
    id: root
    property var state: null
    property color ink: Color.foreground
    property color surface: Color.background
    implicitHeight: Style.space(300)
    contentWidth: availableWidth
    clip: true
    ColumnLayout {
        width: root.availableWidth
        spacing: Style.space(6)
        Text {
            text: root.state ? root.state.folder.path || "Choose Browse from a file tile" : "Folder unavailable"
            color: root.ink
            wrapMode: Text.WrapAnywhere
            Layout.fillWidth: true
            font.pixelSize: Style.space(12)
            textFormat: Text.PlainText
        }
        RowLayout {
            PerchAction {
                text: "Up"
                enabled: !!root.state && !!root.state.folder.parent && !root.state.busy
                ink: root.ink
                surface: root.surface
                onClicked: root.state.browse(root.state.folder.parent)
            }
            PerchAction {
                text: "Open in Files"
                enabled: !!root.state && !!root.state.folder.path && !root.state.busy
                ink: root.ink
                surface: root.surface
                onClicked: root.state.openPath(root.state.folder.path)
            }
        }
        Repeater {
            model: root.state ? root.state.folder.rows || [] : []
            delegate: PerchAction {
                required property var modelData
                Layout.fillWidth: true
                text: (modelData.folder ? "▱ " : "▤ ") + modelData.name
                ink: root.ink
                surface: root.surface
                enabled: !root.state.busy
                onClicked: if (modelData.folder)
                    root.state.browse(modelData.path)
                else
                    root.state.openPath(modelData.path)
            }
        }
        Text {
            text: root.state ? root.state.error || (root.state.folder.partial ? "Showing a bounded, partial folder listing." : "") : ""
            color: Qt.alpha(root.ink, 0.6)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            font.pixelSize: Style.space(11)
            textFormat: Text.PlainText
        }
    }
}
