import QtQuick
import QtQuick.Layouts
import qs.Commons
import "ModulePolicy.js" as Modules

ColumnLayout {
    id: root
    property var pluginState: null
    property var items: Modules.defaults
    property color ink: Color.foreground
    property color surface: Color.background
    signal changed(var order)
    Text {
        text: "Strip modules · up to eight"
        color: root.ink
        font.pixelSize: Style.space(13)
    }
    Repeater {
        model: root.items
        delegate: RowLayout {
            required property string modelData
            required property int index
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: {
                    var id = Modules.pluginId(modelData);
                    var p = id && root.pluginState ? root.pluginState.get(id) : null;
                    return p ? p.name + (p.enabled ? "" : " · disabled") : id ? id + " · unavailable" : Modules.get(modelData).title;
                }
                color: root.ink
                font.pixelSize: Style.space(11)
            }
            PerchAction {
                text: "↑"
                Accessible.name: "Move " + modelData + " earlier"
                enabled: index > 0
                ink: root.ink
                surface: root.surface
                onClicked: root.changed(Modules.move(root.items, modelData, index - 1))
            }
            PerchAction {
                text: "↓"
                Accessible.name: "Move " + modelData + " later"
                enabled: index < root.items.length - 1
                ink: root.ink
                surface: root.surface
                onClicked: root.changed(Modules.move(root.items, modelData, index + 1))
            }
            PerchAction {
                text: "×"
                Accessible.name: "Remove " + modelData
                enabled: root.items.length > 1
                ink: root.ink
                surface: root.surface
                onClicked: root.changed(Modules.toggle(root.items, modelData))
            }
        }
    }
    Flow {
        Layout.fillWidth: true
        Layout.preferredHeight: childrenRect.height
        spacing: Style.space(5)
        Repeater {
            model: Modules.catalog.filter(function (m) {
                return root.items.indexOf(m.id) < 0;
            })
            delegate: PerchAction {
                required property var modelData
                text: "+ " + modelData.title
                enabled: root.items.length < 8
                ink: root.ink
                surface: root.surface
                onClicked: root.changed(Modules.toggle(root.items, modelData.id))
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "Pin installed plugins"
            color: root.ink
            font.pixelSize: Style.space(13)
        }
        PerchAction {
            text: "Refresh"
            enabled: !!root.pluginState && !root.pluginState.busy
            ink: root.ink
            surface: root.surface
            onClicked: root.pluginState.refresh()
        }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Qt.alpha(root.ink, 0.65)
        font.pixelSize: Style.space(10)
        text: !root.pluginState ? "Plugin discovery unavailable" : root.pluginState.error || root.pluginState.message || (root.pluginState.busy ? "Checking installed plugins…" : !root.pluginState.plugins.length ? "No installed plugins with a supported panel. Install and enable plugins through Omarchy." : "Click a pinned plugin to open its own panel. Disabled plugins must first be enabled in Omarchy.")
    }
    Repeater {
        model: root.pluginState ? root.pluginState.plugins : []
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: modelData.name + (modelData.enabled ? "" : " · disabled")
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.ink
                font.pixelSize: Style.space(11)
            }
            PerchAction {
                readonly property bool pinned: root.items.indexOf("plugin:" + modelData.id) >= 0
                text: pinned ? "Unpin" : "Pin"
                enabled: pinned ? root.items.length > 1 : modelData.enabled && root.items.length < 8
                ink: root.ink
                surface: root.surface
                onClicked: root.changed(Modules.toggle(root.items, "plugin:" + modelData.id))
            }
        }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "Drag tiles to reorder, or focus one and use Ctrl + arrow keys. Cards keep the strip visible for switching."
        color: Qt.alpha(root.ink, 0.65)
        font.pixelSize: Style.space(10)
    }
}
