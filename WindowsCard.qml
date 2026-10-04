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
            text: "Choose a window to return to its workspace."
            color: Qt.alpha(root.ink, 0.65)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            font.pixelSize: Style.space(11)
        }
        PerchToggle {
            Layout.fillWidth: true
            text: "Window previews"
            description: "Capture window thumbnails while this card is open. Previews stay in memory."
            ink: root.ink
            surface: root.surface
            checked: !!root.state && !!root.state.preferences && root.state.preferences.record.windowPreviews === true
            onToggled: root.state.preferences.update({
                windowPreviews: checked
            })
        }
        Repeater {
            model: root.state ? root.state.windows : []
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                PerchAction {
                    Layout.fillWidth: true
                    text: modelData.class + " · " + modelData.title + "  [" + modelData.workspace + "]"
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.state.focusWindow(modelData)
                }
                Loader {
                    id: previewLoader
                    Layout.fillWidth: true
                    active: !!root.state && !!root.state.preferences && root.state.preferences.record.windowPreviews === true
                    source: active ? "WindowPreview.qml" : ""
                    onLoaded: {
                        item.address = modelData.address;
                        item.ink = root.ink;
                        item.surface = root.surface;
                    }
                    Connections {
                        target: previewLoader.item
                        function onFocusRequested() {
                            root.state.launchRequested();
                        }
                    }
                }
            }
        }
        Text {
            text: root.state ? root.state.windowError || root.state.error || (!root.state.windows.length ? "No windows to show" : "") : "Window list unavailable"
            color: Qt.alpha(root.ink, 0.7)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            font.pixelSize: Style.space(11)
            textFormat: Text.PlainText
        }
    }
}
