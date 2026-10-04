import QtQuick
import Quickshell
import QtQuick.Controls as Controls
import qs.Commons
import "ModulePolicy.js" as Modules

Item {
    id: root
    property var items: Modules.defaults
    property var pluginState: null
    property var registry: null
    property var customItems: []
    property var tileSizes: ({})
    property real scaleFactor: 1
    property bool detailed: true
    signal configureRequested
    signal browseRequested(string path)
    function itemWidth(index) {
        var item = customItems.find(p => p.id === items[index]);
        return item && item.kind === "spacer" ? Style.space(20) : tileSizes[items[index]] === "wide" ? Style.space(140) * scaleFactor : slot * scaleFactor;
    }
    function offset(index) {
        var n = 0;
        for (var i = 0; i < index; i++)
            n += itemWidth(i);
        return n;
    }
    function indexAt(position) {
        for (var i = 0; i < items.length; i++)
            if (position < offset(i) + itemWidth(i))
                return i;
        return items.length - 1;
    }
    readonly property real extent: offset(items.length) + Style.space(8)
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
    implicitWidth: vertical ? Style.space(52) : extent
    implicitHeight: vertical ? extent : Style.space(52)
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
    Flickable {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: root.vertical ? width : root.extent
        contentHeight: root.vertical ? root.extent : height
        flickableDirection: root.vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.draggingIndex < 0
        Controls.ScrollBar.horizontal: Controls.ScrollBar {
            policy: scroll.contentWidth > scroll.width ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff
        }
        Controls.ScrollBar.vertical: Controls.ScrollBar {
            policy: scroll.contentHeight > scroll.height ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff
        }
        Repeater {
            model: root.items
            delegate: Controls.AbstractButton {
                id: tile
                required property string modelData
                required property int index
                objectName: "module-tile-" + modelData
                readonly property var descriptor: Modules.get(modelData)
                readonly property var custom: root.customItems.find(p => p.id === modelData) || null
                readonly property bool spacer: !!custom && custom.kind === "spacer"
                readonly property bool wide: root.tileSizes[modelData] === "wide"
                readonly property var pinnedPlugin: descriptor && descriptor.pluginId && root.pluginState ? root.pluginState.get(descriptor.pluginId) : null
                readonly property var definition: root.registry ? root.registry.get(modelData) : null
                x: root.vertical ? Style.space(4) : Style.space(4) + root.offset(index)
                y: root.vertical ? Style.space(4) + root.offset(index) : Style.space(4)
                width: root.vertical ? root.width - Style.space(8) : root.itemWidth(index)
                height: root.vertical ? root.itemWidth(index) : root.height - Style.space(8)
                focusPolicy: spacer ? Qt.NoFocus : Qt.StrongFocus
                onActiveFocusChanged: if (activeFocus) {
                    if (root.vertical)
                        scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, y));
                    else
                        scroll.contentX = Math.max(0, Math.min(scroll.contentWidth - scroll.width, x));
                }
                Accessible.name: custom ? custom.name : pinnedPlugin ? pinnedPlugin.name : descriptor ? descriptor.title : modelData
                Controls.ToolTip.visible: hovered && root.draggingIndex < 0
                Controls.ToolTip.delay: 600
                Controls.ToolTip.text: Accessible.name + (Modules.pluginId(modelData) ? (!tile.pinnedPlugin ? " · unavailable" : !tile.pinnedPlugin.enabled ? " · disabled" : " · click to open") : "") + " · drag to reorder"
                background: Rectangle {
                    radius: Style.space(8)
                    color: Qt.alpha(root.ink, root.dropIndex === tile.index ? 0.23 : tile.hovered || root.selectedId === tile.modelData ? 0.13 : tile.wide ? 0.05 : 0)
                    border.width: tile.visualFocus ? 1 : 0
                    border.color: root.ink
                }
                contentItem: Column {
                    visible: !tile.spacer
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)
                    Image {
                        id: appIcon
                        visible: status === Image.Ready
                        width: Style.space(24)
                        height: visible ? Style.space(24) : 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: tile.custom && tile.custom.kind === "app" ? Quickshell.iconPath(tile.custom.target.replace(/\.desktop$/, "")) : ""
                        sourceSize.width: 48
                        sourceSize.height: 48
                    }
                    Text {
                        visible: appIcon.status !== Image.Ready
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.custom ? ({
                                app: "⊞",
                                file: "▱",
                                link: "↗",
                                spacer: ""
                            })[tile.custom.kind] : tile.descriptor ? tile.descriptor.glyph : "·"
                        color: root.ink
                        font.pixelSize: Style.space(17)
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.custom ? tile.custom.name : tile.pinnedPlugin ? tile.pinnedPlugin.name : tile.definition ? tile.definition.compactText : tile.descriptor ? tile.descriptor.title : ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Qt.alpha(root.ink, 0.75)
                        font.pixelSize: Style.space(tile.wide && root.detailed ? 16 : tile.wide ? 11 : 8)
                        font.bold: tile.wide && root.detailed
                    }
                }
                Text {
                    visible: tile.wide && root.detailed && !!tile.definition && tile.definition.compactDetail !== ""
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Style.space(6)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - Style.space(12)
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.definition ? tile.definition.compactDetail : ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Qt.alpha(root.ink, 0.55)
                    font.pixelSize: Style.space(9)
                }
                Rectangle {
                    visible: tile.wide && root.detailed && !!tile.definition && tile.definition.fraction >= 0
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Style.space(2)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - Style.space(16)
                    height: 2
                    color: Qt.alpha(root.ink, 0.12)
                    radius: 1
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, tile.definition ? tile.definition.fraction : 0))
                        height: 2
                        radius: 1
                        color: root.ink
                    }
                }
                onHoveredChanged: {
                    if (hovered && root.hoverOpen && !tile.custom && !Modules.pluginId(modelData)) {
                        root.pendingId = modelData;
                        intent.restart();
                    } else if (root.pendingId === modelData) {
                        root.pendingId = "";
                        intent.stop();
                    }
                }
                Rectangle {
                    visible: tile.spacer
                    anchors.centerIn: parent
                    width: root.vertical ? parent.width / 2 : 1
                    height: root.vertical ? 1 : parent.height / 2
                    color: Qt.alpha(root.ink, 0.2)
                }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: contextMenu.popup()
                }
                Controls.Menu {
                    id: contextMenu
                    Controls.MenuItem {
                        text: "Edit dock…"
                        onTriggered: root.configureRequested()
                    }
                    Controls.MenuItem {
                        text: "Browse folder…"
                        visible: !!tile.custom && tile.custom.kind === "file"
                        height: visible ? implicitHeight : 0
                        onTriggered: root.browseRequested(tile.custom.target)
                    }
                }
                onClicked: if (!tile.spacer && root.draggingIndex < 0)
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
                        root.dropIndex = Math.max(0, Math.min(root.items.length - 1, root.indexAt(root.offset(tile.index) + distance + root.itemWidth(tile.index) / 2)));
                    }
                }
            }
        }
    }
}
