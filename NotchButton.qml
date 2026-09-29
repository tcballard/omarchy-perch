import QtQuick
import QtQuick.Controls
import qs.Commons

Button {
    id: root
    property string label: ""
    property bool prominent: false
    implicitWidth: Style.space(prominent ? 48 : 36)
    implicitHeight: Style.space(prominent ? 48 : 36)
    Accessible.name: label
    hoverEnabled: true
    ToolTip.visible: hovered
    ToolTip.text: label
    ToolTip.delay: 600
    background: Rectangle {
        radius: width / 2
        color: root.prominent ? Color.accent : root.hovered || root.activeFocus ? Qt.alpha(Color.foreground, 0.12) : "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: Color.foreground
        opacity: root.enabled ? 1 : 0.3
    }
    contentItem: Text {
        text: root.text
        textFormat: Text.PlainText
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: root.prominent ? Color.background : Color.foreground
        opacity: root.enabled ? 1 : 0.3
    }
}
