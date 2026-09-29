import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

Controls.Button {
    id: root
    property string label: ""
    property string glyph: "play"
    property bool prominent: false
    property color ink: Color.foreground
    property color surface: Color.background
    implicitWidth: Style.space(prominent ? 44 : 30)
    implicitHeight: implicitWidth
    Accessible.name: label
    hoverEnabled: true
    Controls.ToolTip.visible: hovered
    Controls.ToolTip.text: label
    Controls.ToolTip.delay: 700
    padding: Style.space(prominent ? 12 : 6)
    background: Rectangle {
        radius: width / 2
        color: root.prominent ? root.ink : Qt.alpha(root.ink, root.down ? 0.18 : root.hovered ? 0.1 : 0)
        border.width: root.visualFocus ? 1 : 0
        border.color: root.ink
        opacity: root.enabled ? 1 : 0.25
        scale: root.down ? 0.93 : 1
    }
    contentItem: PerchIcon {
        name: root.glyph
        ink: root.prominent ? root.surface : root.ink
        opacity: root.enabled ? 1 : 0.25
    }
}
