import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import "ModulePolicy.js" as Modules

Item {
    id: root
    property var items: Modules.defaults
    property var registry: null
    property bool vertical: false
    property bool hoverOpen: true
    property bool reducedMotion: false
    property string selectedId: ""
    property color ink: Color.foreground
    property color surface: Color.background
    property string pendingId: ""
    property int draggingIndex: -1
    property int dropIndex: -1
    property real slot: Style.space(46)
    implicitWidth: vertical ? Style.space(52) : Style.space(items.length * 46 + 8)
    implicitHeight: vertical ? Style.space(items.length * 46 + 8) : Style.space(52)
    signal activated(string id, bool pointer)
    signal reordered(var order)
    signal interactionChanged(bool active)
    function finishDrag() {
        draggingIndex = -1;
    }
    function move(id, index) {
        reordered(Modules.move(items, id, index));
    }
    Timer {
        id: intent
        interval: 150
        onTriggered: if (root.pendingId && root.draggingIndex < 0)
            root.activated(root.pendingId, true)
    }
    Repeater {
        model: root.items
        delegate: Controls.AbstractButton {
            id: tile
            required property string modelData
            required property int index
            objectName: "module-tile-" + modelData
            readonly property var descriptor: Modules.get(modelData)
            readonly property var definition: root.registry ? root.registry.get(modelData) : null
            x: root.vertical ? Style.space(4) : Style.space(4) + index * root.slot
            y: root.vertical ? Style.space(4) + index * root.slot : Style.space(4)
            width: root.vertical ? root.width - Style.space(8) : root.slot
            height: root.vertical ? root.slot : root.height - Style.space(8)
            focusPolicy: Qt.StrongFocus
            Accessible.name: descriptor ? descriptor.title : modelData
            Controls.ToolTip.visible: hovered && root.draggingIndex < 0
            Controls.ToolTip.delay: 600
            Controls.ToolTip.text: Accessible.name + " · drag to reorder"
            background: Rectangle {
                radius: Style.space(8)
                color: Qt.alpha(root.ink, root.dropIndex === tile.index ? 0.23 : tile.hovered || root.selectedId === tile.modelData ? 0.13 : 0)
                border.width: tile.visualFocus ? 1 : 0
                border.color: root.ink
            }
            contentItem: Column {
                spacing: Style.space(2)
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.descriptor ? tile.descriptor.glyph : "·"
                    color: root.ink
                    font.pixelSize: Style.space(17)
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.definition ? tile.definition.compactText : tile.descriptor ? tile.descriptor.title : ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Qt.alpha(root.ink, 0.75)
                    font.pixelSize: Style.space(8)
                }
            }
            onHoveredChanged: {
                if (hovered && root.hoverOpen) {
                    root.pendingId = modelData;
                    intent.restart();
                } else if (root.pendingId === modelData) {
                    root.pendingId = "";
                    intent.stop();
                }
            }
            onClicked: if (root.draggingIndex < 0)
                root.activated(modelData, false)
            Keys.onLeftPressed: event => {
                if (event.modifiers & Qt.ControlModifier)
                    root.move(modelData, index - 1);
                else
                    event.accepted = false;
            }
            Keys.onRightPressed: event => {
                if (event.modifiers & Qt.ControlModifier)
                    root.move(modelData, index + 1);
                else
                    event.accepted = false;
            }
            Keys.onUpPressed: event => {
                if (event.modifiers & Qt.ControlModifier)
                    root.move(modelData, index - 1);
                else
                    event.accepted = false;
            }
            Keys.onDownPressed: event => {
                if (event.modifiers & Qt.ControlModifier)
                    root.move(modelData, index + 1);
                else
                    event.accepted = false;
            }
            DragHandler {
                id: drag
                target: null
                onActiveChanged: {
                    if (active) {
                        intent.stop();
                        root.pendingId = "";
                        root.draggingIndex = tile.index;
                        root.dropIndex = tile.index;
                        root.interactionChanged(true);
                    } else {
                        var destination = root.dropIndex;
                        root.dropIndex = -1;
                        root.interactionChanged(false);
                        Qt.callLater(root.finishDrag);
                        if (root.draggingIndex >= 0)
                            root.move(tile.modelData, destination);
                    }
                }
                onTranslationChanged: if (active) {
                    var distance = root.vertical ? translation.y : translation.x;
                    root.dropIndex = Math.max(0, Math.min(root.items.length - 1, tile.index + Math.round(distance / root.slot)));
                }
            }
        }
    }
}
