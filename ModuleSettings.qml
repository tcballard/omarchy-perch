import QtQuick
import QtQuick.Layouts
import qs.Commons
import "ModulePolicy.js" as Modules
import "ShortcutPolicy.js" as Shortcuts

ColumnLayout {
    id: root
    property bool showModules: true
    property bool showPlugins: true
    property var pluginState: null
    property var items: Modules.defaults
    property color ink: Color.foreground
    property color surface: Color.background
    property var shortcuts: ({})
    property string shortcutError: ""
    signal shortcutChanged(var bindings)
    signal changed(var order)
    Text {
        visible: root.showModules
        text: PerchStrings.t("Strip modules · up to eight")
        color: root.ink
        font.pixelSize: Style.space(13)
    }
    Repeater {
        model: root.showModules ? root.items : []
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
                    return p ? p.name + (p.enabled ? "" : " · disabled") : id ? id + " · unavailable" : PerchStrings.t(Modules.get(modelData).title);
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
    Text {
        visible: root.showModules
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: PerchStrings.t("Shortcuts work while Perch has keyboard focus. Use Ctrl+Alt and a letter or digit. Escape cancels recording.")
        color: Qt.alpha(root.ink, 0.6)
        font.pixelSize: Style.space(10)
    }
    Repeater {
        model: root.showModules ? root.items : []
        delegate: RowLayout {
            required property string modelData
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: PerchStrings.t(Modules.get(modelData).title)
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.ink
                font.pixelSize: Style.space(11)
            }
            ShortcutRecorder {
                sequence: root.shortcuts[modelData] || ""
                ink: root.ink
                surface: root.surface
                onRecorded: chord => {
                    var next = Shortcuts.assign(root.shortcuts, root.items, modelData, chord);
                    root.shortcutError = next ? "" : PerchStrings.t("That shortcut is already assigned.");
                    if (next)
                        root.shortcutChanged(next);
                }
            }
            PerchAction {
                text: PerchStrings.t("Clear")
                enabled: !!root.shortcuts[modelData]
                ink: root.ink
                surface: root.surface
                onClicked: {
                    root.shortcutError = "";
                    root.shortcutChanged(Shortcuts.assign(root.shortcuts, root.items, modelData, ""));
                }
            }
        }
    }
    Text {
        visible: root.showModules && root.shortcutError !== ""
        Layout.fillWidth: true
        text: root.shortcutError
        wrapMode: Text.WordWrap
        color: "#e47b76"
        font.pixelSize: Style.space(10)
    }
    Flow {
        visible: root.showModules
        Layout.fillWidth: true
        Layout.preferredHeight: childrenRect.height
        spacing: Style.space(5)
        Repeater {
            model: Modules.catalog.filter(function (m) {
                return root.items.indexOf(m.id) < 0;
            })
            delegate: PerchAction {
                required property var modelData
                text: "+ " + PerchStrings.t(modelData.title)
                enabled: root.items.length < 8
                ink: root.ink
                surface: root.surface
                onClicked: root.changed(Modules.toggle(root.items, modelData.id))
            }
        }
    }
    RowLayout {
        visible: root.showPlugins
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: PerchStrings.t("Pin installed plugins")
            color: root.ink
            font.pixelSize: Style.space(13)
        }
        PerchAction {
            text: PerchStrings.t("Refresh")
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
        visible: root.showPlugins
        text: !root.pluginState ? PerchStrings.t("Plugin discovery unavailable") : root.pluginState.error || root.pluginState.message || (root.pluginState.busy ? PerchStrings.t("Checking installed plugins…") : !root.pluginState.plugins.length ? PerchStrings.t("No installed plugins with a supported panel. Install and enable plugins through Omarchy.") : PerchStrings.t("Click a pinned plugin to open its own panel. Disabled plugins must first be enabled in Omarchy."))
    }
    Repeater {
        model: root.showPlugins && root.pluginState ? root.pluginState.plugins : []
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
                text: pinned ? PerchStrings.t("Unpin") : PerchStrings.t("Pin")
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
        visible: root.showModules
        text: PerchStrings.t("Drag tiles to reorder, or focus one and use Ctrl + arrow keys. Cards keep the strip visible for switching.")
        color: Qt.alpha(root.ink, 0.65)
        font.pixelSize: Style.space(10)
    }
}
