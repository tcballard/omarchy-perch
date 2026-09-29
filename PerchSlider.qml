import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

Controls.Slider {
    id: root
    property color ink: Color.foreground
    implicitHeight: Style.space(24)
    from: 0
    to: 1
    stepSize: 0.01
    padding: 0
    background: Rectangle {
        x: root.leftPadding
        y: (root.height - height) / 2
        width: root.availableWidth
        height: Style.space(3)
        radius: height / 2
        color: Qt.alpha(root.ink, 0.16)
        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: root.ink
            opacity: root.enabled ? 0.8 : 0.3
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: (root.height - height) / 2
        width: Style.space(root.pressed ? 12 : 8)
        height: width
        radius: width / 2
        color: root.ink
        visible: root.enabled
        border.width: root.visualFocus ? 2 : 0
        border.color: Color.accent
    }
}
