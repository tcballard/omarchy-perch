import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

Controls.CheckBox {
    id: root
    property color ink: Color.foreground
    property color surface: Color.background
    property string description: ""
    implicitHeight: Math.max(Style.space(42), copy.implicitHeight + Style.space(12))
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Accessible.name: text
    Accessible.description: description
    indicator: Rectangle {
        x: root.width - width - Style.space(4)
        y: (root.height - height) / 2
        width: Style.space(30)
        height: Style.space(18)
        radius: height / 2
        color: root.checked ? root.ink : Qt.alpha(root.ink, 0.18)
        border.width: root.visualFocus ? 2 : 0
        border.color: root.ink
        Rectangle {
            x: root.checked ? parent.width - width - 3 : 3
            y: 3
            width: parent.height - 6
            height: width
            radius: width / 2
            color: root.checked ? root.surface : root.ink
        }
    }
    contentItem: Column {
        id: copy
        spacing: Style.space(3)
        Text {
            width: parent.width - Style.space(46)
            text: root.text
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: root.ink
            font.family: Style.font.family
            font.pixelSize: Style.space(12)
        }
        Text {
            width: parent.width - Style.space(46)
            visible: text !== ""
            text: root.description
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Qt.alpha(root.ink, 0.6)
            font.family: Style.font.family
            font.pixelSize: Style.space(10)
        }
    }
    background: Rectangle {
        radius: Style.space(6)
        color: Qt.alpha(root.ink, root.hovered ? 0.04 : 0)
    }
}
