import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

Controls.Button {
    id: root
    property color ink: Color.foreground
    property color surface: Color.background
    property bool selected: false
    implicitHeight: Style.space(32)
    implicitWidth: label.implicitWidth + Style.space(20)
    hoverEnabled: true
    Accessible.name: text
    background: Rectangle {
        radius: Style.space(7)
        color: root.selected ? root.ink : Qt.alpha(root.ink, root.down ? 0.18 : root.hovered ? 0.12 : 0.06)
        border.width: root.visualFocus ? 1 : 0
        border.color: root.ink
        opacity: root.enabled ? 1 : 0.3
    }
    contentItem: Text {
        id: label
        text: root.text
        textFormat: Text.PlainText
        color: root.selected ? root.surface : root.ink
        opacity: root.enabled ? 1 : 0.35
        font.family: Style.font.family
        font.pixelSize: Style.space(11)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
