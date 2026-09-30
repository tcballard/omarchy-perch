import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

Controls.AbstractButton {
    id: root
    property var context: ({
            id: "idle",
            title: "Perch",
            glyph: "⌃"
        })
    property bool vertical: false
    property bool hoverOpen: true
    property color ink: Color.foreground
    property color surface: Color.background
    signal openRequested
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: "Open Perch · " + context.title
    Accessible.onPressAction: root.openRequested()
    onClicked: openRequested()
    onHoveredChanged: {
        if (hovered && hoverOpen)
            intent.restart();
        else
            intent.stop();
    }
    onVisibleChanged: if (!visible)
        intent.stop()
    Timer {
        id: intent
        interval: 150
        onTriggered: if (root.hovered && root.visible && root.hoverOpen)
            root.openRequested()
    }
    contentItem: Item {
        Text {
            id: icon
            x: root.vertical ? (parent.width - width) / 2 : Style.space(12)
            y: root.vertical ? Style.space(10) : (parent.height - height) / 2
            text: root.context.glyph
            textFormat: Text.PlainText
            color: root.ink
            font.pixelSize: Style.space(16)
        }
        Text {
            x: root.vertical ? Style.space(4) : icon.x + icon.width + Style.space(10)
            y: root.vertical ? icon.y + icon.height + Style.space(5) : (parent.height - height) / 2
            width: root.vertical ? parent.width - Style.space(8) : parent.width - x - Style.space(12)
            text: root.vertical ? (root.context.attention ? "!" : root.context.id === "idle" ? "Perch" : root.context.id.charAt(0).toUpperCase() + root.context.id.slice(1)) : root.context.title
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: root.ink
            font.family: Style.font.family
            font.pixelSize: Style.space(root.vertical ? 8 : 11)
            horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignLeft
        }
        Rectangle {
            visible: root.context.attention
            x: parent.width - Style.space(7)
            y: Style.space(5)
            width: Style.space(3)
            height: width
            radius: width / 2
            color: root.ink
        }
    }
    background: Rectangle {
        anchors.fill: parent
        radius: Style.space(10)
        color: Qt.alpha(root.ink, root.visualFocus ? 0.12 : root.hovered ? 0.06 : 0)
        border.width: root.visualFocus ? 1 : 0
        border.color: root.ink
    }
}
