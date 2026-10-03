import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import "ModulePolicy.js" as Modules

ColumnLayout {
    id: root
    property var host: null
    property color ink: Color.foreground
    property color surface: Color.background
    readonly property var results: Modules.search(root.host && root.host.pluginState ? root.host.pluginState.plugins : [], search.text)
    property int selectedIndex: -1
    onResultsChanged: selectedIndex = -1
    function moveSelection(direction) {
        if (!results.length) return;
        var index = selectedIndex < 0 ? (direction > 0 ? -1 : 0) : selectedIndex;
        for (var count = 0; count < results.length; count++) {
            index = (index + direction + results.length) % results.length;
            if (results[index].enabled) {
                selectedIndex = index;
                var row = resultRows.itemAt(index);
                if (row && scroll.contentItem) {
                    var top = row.y;
                    var bottom = top + row.height;
                    var viewport = scroll.availableHeight;
                    var current = scroll.contentItem.contentY;
                    if (top < current) scroll.contentItem.contentY = top;
                    else if (bottom > current + viewport)
                        scroll.contentItem.contentY = bottom - viewport;
                }
                return;
            }
        }
    }
    spacing: Style.space(10)
    Controls.TextField {
        id: search
        objectName: "tools-search"
        Layout.fillWidth: true
        placeholderText: PerchStrings.t("Find a tool or plugin…")
        color: root.ink
        placeholderTextColor: Qt.alpha(root.ink, 0.5)
        selectionColor: Qt.alpha(root.ink, 0.25)
        font.pixelSize: Style.space(12)
        Accessible.name: "Find a tool or plugin"
        background: Rectangle {
            radius: Style.space(8)
            color: Qt.alpha(root.ink, 0.05)
            border.width: search.activeFocus ? 1 : 0
            border.color: Qt.alpha(root.ink, 0.5)
        }
        Keys.onDownPressed: root.moveSelection(1)
        Keys.onUpPressed: root.moveSelection(-1)
        onAccepted: {
            var index = root.selectedIndex >= 0 ? root.selectedIndex : root.results.length === 1 ? 0 : -1;
            if (index >= 0 && root.results[index].enabled)
                root.open(root.results[index].id);
        }
    }
    function focusSearch() {
        search.forceActiveFocus();
        search.selectAll();
    }
    function open(id) {
        if (id === "setup")
            root.host.page = "setup";
        else
            root.host.activateModule(id, false);
    }
    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: root.results.length + (root.results.length === 1 ? PerchStrings.t(" result") : PerchStrings.t(" results"))
            color: Qt.alpha(root.ink, 0.55)
            font.pixelSize: Style.space(10)
        }
        PerchAction {
            objectName: "tools-refresh"
            text: root.host && root.host.pluginState && root.host.pluginState.busy ? PerchStrings.t("Loading…") : PerchStrings.t("Refresh plugins")
            enabled: !!root.host && !!root.host.pluginState && !root.host.pluginState.busy
            ink: root.ink
            surface: root.surface
            onClicked: root.host.pluginState.refresh()
        }
    }
    Text {
        visible: root.results.length === 0
        Layout.fillWidth: true
        text: PerchStrings.t("No tools or plugins match. Try another name.")
        color: Qt.alpha(root.ink, 0.6)
        wrapMode: Text.Wrap
        font.pixelSize: Style.space(12)
    }
    Controls.ScrollView {
        id: scroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: Math.min(Style.space(248), rows.implicitHeight)
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            id: rows
            width: parent.width
            spacing: Style.space(6)
            Repeater {
                id: resultRows
                model: root.results
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: Style.space(56)
                    radius: Style.space(8)
                    color: Qt.alpha(root.ink, root.selectedIndex === index ? 0.12 : 0.04)
                    border.width: root.selectedIndex === index ? 1 : 0
                    border.color: Qt.alpha(root.ink, 0.4)
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Style.space(8)
                        spacing: Style.space(5)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(3)
                            Text {
                                Layout.fillWidth: true
                                text: modelData.plugin ? modelData.title : PerchStrings.t(modelData.title)
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: root.ink
                                font.pixelSize: Style.space(12)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.plugin ? (modelData.enabled ? PerchStrings.t("Plugin") : PerchStrings.t("Plugin · disabled")) : PerchStrings.t("Built-in tool")
                                color: Qt.alpha(root.ink, 0.5)
                                font.pixelSize: Style.space(10)
                            }
                        }
                        PerchAction {
                            objectName: "tool-open-" + modelData.id
                            text: PerchStrings.t("Open")
                            enabled: modelData.enabled
                            Accessible.name: "Open " + modelData.title
                            ink: root.ink
                            surface: root.surface
                            onClicked: root.open(modelData.id)
                        }
                        PerchAction {
                            objectName: "tool-pin-" + modelData.id
                            visible: modelData.id !== "setup"
                            readonly property bool pinned: !!root.host && root.host.moduleItems.indexOf(modelData.id) >= 0
                            text: pinned ? PerchStrings.t("Unpin") : PerchStrings.t("Pin")
                            enabled: !!root.host && (pinned ? root.host.moduleItems.length > 1 : root.host.moduleItems.length < 8)
                            Accessible.name: (pinned ? "Unpin " : "Pin ") + modelData.title
                            ink: root.ink
                            surface: root.surface
                            onClicked: root.host.preferenceChanged("modules", Modules.toggle(root.host.moduleItems, modelData.id))
                        }
                    }
                }
            }
        }
    }
    Text {
        visible: !!root.host && !!root.host.pluginState && root.host.pluginState.error !== ""
        Layout.fillWidth: true
        text: visible ? root.host.pluginState.error : ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Qt.alpha(root.ink, 0.6)
        font.pixelSize: Style.space(11)
    }
}
