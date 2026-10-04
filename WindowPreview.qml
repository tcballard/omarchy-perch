import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

ColumnLayout {
    id: root
    property string address: ""
    property color ink: Color.foreground
    property color surface: Color.background
    readonly property var toplevel: (Hyprland.toplevels ? Hyprland.toplevels.values : []).find(t => t.address.replace(/^0x/, "") === address.replace(/^0x/, "")) || null
    readonly property var handle: toplevel ? toplevel.wayland : null
    property string message: ""
    signal focusRequested
    implicitHeight: Style.space(135)
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(92)
        radius: Style.space(6)
        color: Qt.alpha(root.ink, 0.05)
        clip: true
        ScreencopyView {
            id: capture
            anchors.centerIn: parent
            captureSource: root.visible ? root.handle : null
            live: false
            paintCursor: false
            constraintSize: Qt.size(parent.width, parent.height)
            width: implicitWidth
            height: implicitHeight
        }
        Text {
            anchors.centerIn: parent
            visible: !capture.hasContent
            text: "Preview unavailable"
            color: Qt.alpha(root.ink, 0.5)
            font.pixelSize: Style.space(11)
        }
    }
    RowLayout {
        PerchAction {
            text: "Refresh preview"
            ink: root.ink
            surface: root.surface
            enabled: !!root.handle
            onClicked: capture.captureFrame()
        }
        PerchAction {
            text: root.handle && root.handle.minimized ? "Restore" : "Minimize"
            enabled: !!root.handle
            ink: root.ink
            surface: root.surface
            onClicked: {
                root.focusRequested();
                root.handle.minimized = !root.handle.minimized;
                root.message = "Requested; your compositor controls whether minimization is supported.";
            }
        }
    }
    Text {
        visible: text !== ""
        text: root.message
        color: Qt.alpha(root.ink, 0.6)
        font.pixelSize: Style.space(10)
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
}
