import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var state: null
    property color ink: Color.foreground
    property color surface: Color.background
    spacing: Style.space(6)
    Controls.TextField {
        objectName: "clipboard-search"
        Layout.fillWidth: true
        placeholderText: PerchStrings.t("Search recent clipboard previews…")
        text: root.state ? root.state.query : ""
        maximumLength: 120
        color: root.ink
        palette.base: root.surface
        palette.placeholderText: Qt.alpha(root.ink, 0.5)
        onTextEdited: if (root.state)
            root.state.query = text
        Keys.onDownPressed: results.forceActiveFocus()
        Keys.onReturnPressed: if (root.state && root.state.clips.length)
            root.state.copyClip(root.state.clips[0].id)
    }
    RowLayout {
        Repeater {
            model: ["all", "text", "link", "image", "file"]
            delegate: PerchAction {
                required property string modelData
                Layout.fillWidth: true
                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                selected: !!root.state && root.state.kind === modelData
                ink: root.ink
                surface: root.surface
                onClicked: if (root.state)
                    root.state.kind = modelData
            }
        }
    }
    ListView {
        id: results
        objectName: "clipboard-results"
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Style.space(5)
        model: root.state ? root.state.clips : []
        onCountChanged: currentIndex = Math.min(Math.max(0, currentIndex), count - 1)
        keyNavigationEnabled: true
        Keys.onReturnPressed: if (currentIndex >= 0 && root.state)
            root.state.copyClip(root.state.clips[currentIndex].id)
        delegate: Controls.ItemDelegate {
            required property var modelData
            required property int index
            width: ListView.view.width
            height: Style.space(58)
            enabled: !!root.state && !root.state.clipboardBusy
            Accessible.name: "Copy " + modelData.kind + ": " + modelData.preview.slice(0, 120)
            background: Rectangle {
                radius: Style.space(6)
                color: Qt.alpha(root.ink, parent.hovered || results.activeFocus && results.currentIndex === parent.index ? 0.15 : 0.06)
            }
            contentItem: RowLayout {
                Image {
                    visible: !!modelData.image
                    source: modelData.image || ""
                    Layout.preferredWidth: visible ? Style.space(48) : 0
                    Layout.preferredHeight: Style.space(44)
                    sourceSize.width: 96
                    sourceSize.height: 96
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                }
                Text {
                    Layout.fillWidth: true
                    text: modelData.preview
                    textFormat: Text.PlainText
                    color: root.ink
                    font.pixelSize: Style.space(11)
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
            onClicked: root.state.copyClip(modelData.id)
        }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: !root.state ? PerchStrings.t("Clipboard unavailable") : root.state.clipboardError || root.state.copyMessage || (root.state.clipboardBusy ? PerchStrings.t("Reading…") : root.state.clips.length ? PerchStrings.t("Select to copy; then paste in your app. History is owned by Omarchy.") : PerchStrings.t("No matching entries. History is owned by Omarchy."))
        color: Qt.alpha(root.ink, 0.65)
        font.pixelSize: Style.space(10)
    }
}
