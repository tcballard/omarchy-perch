import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import qs.Commons
import "ModulePolicy.js" as Modules

Controls.ScrollView {
    id: root
    property var state: null
    property var registry: null
    property var pluginState: null
    property color ink: Color.foreground
    property color surface: Color.background
    property string tab: "layout"
    property string query: ""
    property bool confirmRestore: false
    implicitHeight: Style.space(330)
    contentWidth: availableWidth
    clip: true
    readonly property var order: state ? Modules.clean(state.record.modules) : Modules.defaults
    function label(id) {
        var item = state ? state.items.find(p => p.id === id) : null;
        return item ? item.name : (Modules.get(id) || {}).title || id;
    }
    ColumnLayout {
        width: root.availableWidth
        spacing: Style.space(10)
        Text {
            text: root.state ? root.state.activeName : "Make Perch yours"
            color: root.ink
            font.pixelSize: Style.space(23)
            font.bold: true
            Layout.fillWidth: true
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
        Text {
            text: "Your apps, tools and everyday information, together."
            color: Qt.alpha(root.ink, 0.65)
            font.pixelSize: Style.space(11)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: childrenRect.height
            spacing: Style.space(4)
            Repeater {
                model: ["layout", "library", "profiles", "backup"]
                delegate: PerchAction {
                    required property string modelData
                    text: modelData[0].toUpperCase() + modelData.slice(1)
                    selected: root.tab === modelData
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.tab = modelData
                }
            }
        }
        ColumnLayout {
            visible: root.tab === "layout"
            Layout.fillWidth: true
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Style.space(84)
                radius: Style.space(12)
                color: Qt.alpha(root.ink, 0.05)
                border.color: Qt.alpha(root.ink, 0.13)
                ModuleStrip {
                    anchors.fill: parent
                    anchors.margins: Style.space(5)
                    items: root.order
                    registry: root.registry
                    pluginState: root.pluginState
                    customItems: root.state ? root.state.items : []
                    tileSizes: root.state ? root.state.record.tileSizes || {} : {}
                    ink: root.ink
                    surface: root.surface
                    hoverOpen: false
                    onReordered: order => {
                        if (root.state)
                            root.state.save({
                                modules: order
                            });
                    }
                }
            }
            Text {
                text: "Drag the preview to reorder. Choose Wide for more detail."
                color: Qt.alpha(root.ink, 0.6)
                font.pixelSize: Style.space(10)
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Repeater {
                model: root.order
                delegate: RowLayout {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Text {
                        text: root.label(modelData)
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: root.ink
                        Layout.fillWidth: true
                        font.pixelSize: Style.space(12)
                    }
                    PerchAction {
                        text: "↑"
                        enabled: index > 0
                        ink: root.ink
                        surface: root.surface
                        onClicked: root.state.save({
                            modules: Modules.move(root.order, modelData, index - 1)
                        })
                    }
                    PerchAction {
                        text: root.state && (root.state.record.tileSizes || {})[modelData] === "wide" ? "Compact" : "Wide"
                        ink: root.ink
                        surface: root.surface
                        onClicked: root.state.resize(modelData, (root.state.record.tileSizes || {})[modelData] !== "wide")
                    }
                    PerchAction {
                        text: "Remove"
                        ink: root.ink
                        surface: root.surface
                        onClicked: root.state.removeItem(modelData)
                    }
                }
            }
            RowLayout {
                PerchAction {
                    text: "Notch"
                    selected: root.state && root.state.record.layoutMode !== "strip"
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.state.save({
                        layoutMode: "notch"
                    })
                }
                PerchAction {
                    text: "Dock"
                    selected: root.state && root.state.record.layoutMode === "strip"
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.state.save({
                        layoutMode: "strip"
                    })
                }
                PerchAction {
                    text: "+ Spacer"
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.state.add("spacer", "Spacer", "")
                }
            }
            PerchToggle {
                text: "Show running windows"
                description: "Keep a live window switcher within reach."
                checked: root.state && root.state.record.showRunningApps === true
                ink: root.ink
                surface: root.surface
                onToggled: root.state.save({
                    showRunningApps: checked
                })
            }
            PerchToggle {
                Layout.fillWidth: true
                text: "Automatically hide"
                description: "Leave a small handle; hover or click it to open Perch."
                checked: !!root.state && root.state.record.dockAutoHide === true
                ink: root.ink
                surface: root.surface
                onToggled: root.state.save({
                    dockAutoHide: checked
                })
            }
            Text {
                text: "Dock size"
                color: root.ink
                font.pixelSize: Style.space(12)
            }
            Controls.Slider {
                Layout.fillWidth: true
                from: 0.8
                to: 1.5
                stepSize: 0.1
                value: root.state ? root.state.record.dockScale || 1 : 1
                onMoved: root.state.save({
                    dockScale: value
                })
            }
        }
        ColumnLayout {
            visible: root.tab === "library"
            Layout.fillWidth: true
            Controls.TextField {
                Layout.fillWidth: true
                placeholderText: "Search tools"
                color: root.ink
                palette.base: root.surface
                onTextChanged: root.query = text
                maximumLength: 120
            }
            Repeater {
                model: Modules.catalog.filter(m => m.id !== "dock" && (m.title + " " + m.id).toLowerCase().indexOf(root.query.toLowerCase()) >= 0)
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Style.space(65)
                    radius: Style.space(8)
                    color: Qt.alpha(root.ink, 0.05)
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Style.space(9)
                        Text {
                            text: modelData.glyph
                            color: root.ink
                            font.pixelSize: Style.space(24)
                            Layout.preferredWidth: Style.space(32)
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Text {
                                text: modelData.title
                                color: root.ink
                                font.bold: true
                                font.pixelSize: Style.space(12)
                            }
                            Text {
                                text: root.registry && root.registry.get(modelData.id) ? root.registry.get(modelData.id).compactText : "Open to configure"
                                color: Qt.alpha(root.ink, 0.6)
                                font.pixelSize: Style.space(10)
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                        }
                        PerchAction {
                            text: root.order.indexOf(modelData.id) >= 0 ? "Added" : "Add"
                            enabled: !!root.state && root.order.indexOf(modelData.id) < 0 && root.order.length < 24
                            ink: root.ink
                            surface: root.surface
                            onClicked: root.state.save({
                                modules: root.order.concat([modelData.id])
                            })
                        }
                    }
                }
            }
            PerchAction {
                text: "+ Another weather location"
                ink: root.ink
                surface: root.surface
                onClicked: root.state.addWeather()
            }
            RowLayout {
                PerchAction {
                    text: "Choose app"
                    enabled: !!root.state && !root.state.busy
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.state.loadApps()
                }
                PerchAction {
                    text: "Choose file"
                    ink: root.ink
                    surface: root.surface
                    onClicked: fileDialog.open()
                }
                PerchAction {
                    text: "Choose folder"
                    ink: root.ink
                    surface: root.surface
                    onClicked: folderDialog.open()
                }
            }
            Repeater {
                model: root.state ? root.state.apps.filter(a => !root.query || a.name.toLowerCase().indexOf(root.query.toLowerCase()) >= 0).slice(0, 30) : []
                delegate: PerchAction {
                    required property var modelData
                    Layout.fillWidth: true
                    text: "+ " + modelData.name
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.state.add("app", modelData.name, modelData.id)
                }
            }
            Controls.TextField {
                id: linkName
                Layout.fillWidth: true
                placeholderText: "Link name"
                maximumLength: 60
                color: root.ink
                palette.base: root.surface
            }
            Controls.TextField {
                id: linkUrl
                Layout.fillWidth: true
                placeholderText: "https://…"
                maximumLength: 2048
                color: root.ink
                palette.base: root.surface
            }
            PerchAction {
                text: "Add link"
                ink: root.ink
                surface: root.surface
                onClicked: if (root.state.add("link", linkName.text, linkUrl.text)) {
                    linkName.clear();
                    linkUrl.clear();
                }
            }
            ModuleSettings {
                Layout.fillWidth: true
                showModules: false
                pluginState: root.pluginState
                items: root.order
                ink: root.ink
                surface: root.surface
                onChanged: order => root.state.save({
                        modules: order
                    })
            }
        }
        ColumnLayout {
            visible: root.tab === "profiles"
            Layout.fillWidth: true
            Text {
                text: "Switch your tools without closing apps or moving windows."
                color: Qt.alpha(root.ink, 0.7)
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                font.pixelSize: Style.space(11)
            }
            Repeater {
                model: root.state ? root.state.profiles : []
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    RowLayout {
                        Layout.fillWidth: true
                        Controls.TextField {
                            id: profileName
                            text: modelData.name
                            maximumLength: 60
                            Layout.fillWidth: true
                            color: root.ink
                            palette.base: root.surface
                            onEditingFinished: root.state.rename(modelData.id, text)
                        }
                        PerchAction {
                            text: root.state.activeId === modelData.id ? "Active" : "Use"
                            selected: root.state.activeId === modelData.id
                            ink: root.ink
                            surface: root.surface
                            onClicked: root.state.activate(modelData.id)
                        }
                        PerchAction {
                            text: "Remove"
                            ink: root.ink
                            surface: root.surface
                            onClicked: root.state.removeProfile(modelData.id)
                        }
                    }
                    RowLayout {
                        Controls.TextField {
                            id: startTime
                            Layout.preferredWidth: Style.space(70)
                            placeholderText: "09:00"
                            text: modelData.schedule && modelData.schedule.enabled ? Math.floor(modelData.schedule.start / 60).toString().padStart(2, "0") + ":" + (modelData.schedule.start % 60).toString().padStart(2, "0") : "09:00"
                            maximumLength: 5
                            color: root.ink
                            palette.base: root.surface
                        }
                        Controls.TextField {
                            id: endTime
                            Layout.preferredWidth: Style.space(70)
                            placeholderText: "17:00"
                            text: modelData.schedule && modelData.schedule.enabled ? Math.floor(modelData.schedule.end / 60).toString().padStart(2, "0") + ":" + (modelData.schedule.end % 60).toString().padStart(2, "0") : "17:00"
                            maximumLength: 5
                            color: root.ink
                            palette.base: root.surface
                        }
                        PerchAction {
                            text: modelData.schedule && modelData.schedule.enabled ? "Stop schedule" : "Weekdays"
                            ink: root.ink
                            surface: root.surface
                            onClicked: root.state.schedule(modelData.id, !(modelData.schedule && modelData.schedule.enabled), startTime.text, endTime.text)
                        }
                    }
                }
            }
            Controls.TextField {
                id: newName
                Layout.fillWidth: true
                placeholderText: "Name this layout"
                maximumLength: 60
                color: root.ink
                palette.base: root.surface
            }
            PerchAction {
                text: "Save as new profile"
                ink: root.ink
                surface: root.surface
                onClicked: if (root.state.create(newName.text, ""))
                    newName.clear()
            }
            Text {
                text: "Start with a useful collection"
                color: root.ink
                font.pixelSize: Style.space(13)
                font.bold: true
            }
            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                spacing: Style.space(5)
                Repeater {
                    model: ["everyday", "building", "presenting", "wellbeing"]
                    delegate: PerchAction {
                        required property string modelData
                        text: modelData[0].toUpperCase() + modelData.slice(1)
                        ink: root.ink
                        surface: root.surface
                        onClicked: root.state.create(text, modelData)
                    }
                }
            }
            Text {
                text: "Ctrl+PageUp / PageDown switches profiles while Perch has focus. Saved profiles include dock items, widths and shortcuts."
                color: Qt.alpha(root.ink, 0.6)
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                font.pixelSize: Style.space(10)
            }
        }
        ColumnLayout {
            visible: root.tab === "backup"
            Layout.fillWidth: true
            Text {
                text: "Copy your layouts to a file to back up or move to another machine. App and file targets must exist there. Credentials, notifications and agent settings are excluded."
                color: Qt.alpha(root.ink, 0.7)
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                font.pixelSize: Style.space(11)
            }
            PerchAction {
                text: "Prepare backup"
                ink: root.ink
                surface: root.surface
                onClicked: {
                    root.state.exportBackup();
                    backup.text = root.state.backupText;
                }
            }
            RowLayout {
                PerchAction {
                    text: "Save backup file…"
                    ink: root.ink
                    surface: root.surface
                    onClicked: saveBackup.open()
                }
                PerchAction {
                    text: "Read backup file…"
                    ink: root.ink
                    surface: root.surface
                    onClicked: readBackup.open()
                }
            }
            Controls.TextArea {
                id: backup
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(140)
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                color: root.ink
                palette.base: root.surface
                placeholderText: "Copy or paste a Perch dock backup"
                onTextChanged: root.confirmRestore = false
            }
            PerchAction {
                text: root.confirmRestore ? "Confirm replace layouts" : "Restore layouts…"
                ink: root.ink
                surface: root.surface
                onClicked: {
                    if (!root.confirmRestore)
                        root.confirmRestore = true;
                    else {
                        root.state.importBackup(backup.text);
                        root.confirmRestore = false;
                    }
                }
            }
        }
        Text {
            text: root.state ? root.state.error || root.state.message : "Settings are unavailable in this preview"
            color: root.state && root.state.error ? "#e47b76" : Qt.alpha(root.ink, 0.65)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            font.pixelSize: Style.space(11)
            textFormat: Text.PlainText
        }
    }
    Connections {
        target: root.state
        function onBackupTextChanged() {
            backup.text = root.state.backupText;
        }
    }
    FileDialog {
        id: saveBackup
        fileMode: FileDialog.SaveFile
        defaultSuffix: "perch.json"
        nameFilters: ["Perch layouts (*.perch.json)"]
        onAccepted: root.state.saveBackup(decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, "")))
    }
    FileDialog {
        id: readBackup
        nameFilters: ["Perch layouts (*.perch.json)"]
        onAccepted: root.state.loadBackup(decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, "")))
    }
    FileDialog {
        id: fileDialog
        onAccepted: {
            var path = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""));
            root.state.add("file", path.split('/').pop(), path);
        }
    }
    FolderDialog {
        id: folderDialog
        onAccepted: {
            var path = decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, ""));
            root.state.add("file", path.split('/').pop(), path);
        }
    }
}
