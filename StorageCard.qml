import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
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
        spacing: Style.space(8)
        Text {
            text: "Find large files and folders. Nothing is deleted."
            color: root.ink
            font.pixelSize: Style.space(12)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        PerchAction {
            text: root.state && root.state.busy ? "Scanning…" : "Choose folder to scan"
            enabled: !!root.state && !root.state.busy
            ink: root.ink
            surface: root.surface
            onClicked: picker.open()
        }
        Text {
            text: "Allocated disk space; hard links may count twice. Scans stop after 20,000 entries or four seconds. Incomplete results show ≥."
            color: Qt.alpha(root.ink, 0.65)
            font.pixelSize: Style.space(10)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Repeater {
            model: root.state ? root.state.storage : []
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Text {
                    text: (modelData.partial ? "≥ " : "") + (modelData.bytes / 1048576).toFixed(1) + " MiB"
                    color: root.ink
                    font.pixelSize: Style.space(11)
                    Layout.preferredWidth: Style.space(90)
                }
                PerchAction {
                    Layout.fillWidth: true
                    text: modelData.name
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.state.openPath(modelData.path)
                }
            }
        }
        Text {
            text: root.state ? root.state.error || (root.state.storagePartial ? "Partial scan: some folders were not counted." : "") : "Storage scan unavailable"
            color: Qt.alpha(root.ink, 0.65)
            font.pixelSize: Style.space(11)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            textFormat: Text.PlainText
        }
    }
    FolderDialog {
        id: picker
        onAccepted: root.state.scan(decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, "")))
    }
}
