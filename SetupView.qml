import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var work: null
    property color ink: Color.foreground
    property color surface: Color.background
    property bool confirmRemove: false
    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "Make Perch yours"
            color: root.ink
            font.pixelSize: Style.space(14)
            font.bold: true
        }
        PerchAction {
            text: "Check"
            ink: root.ink
            surface: root.surface
            enabled: !!root.work && !root.work.busy
            onClicked: root.work.checkHealth()
        }
    }
    Text {
        Layout.fillWidth: true
        text: "Choose what Perch handles. Notifications and system feedback replace their built-in counterparts; disabling restores them."
        wrapMode: Text.WordWrap
        color: Qt.alpha(root.ink, 0.6)
        font.pixelSize: Style.space(11)
    }
    Controls.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            width: parent.width
            spacing: Style.space(8)
            Repeater {
                model: [
                    {
                        id: "notifications",
                        name: "Notifications",
                        detail: "Inbox, replies and persistent history"
                    },
                    {
                        id: "osd",
                        name: "System feedback",
                        detail: "One set of volume and brightness overlays"
                    },
                    {
                        id: "claude",
                        name: "Claude Code",
                        detail: "Working, attention and completion"
                    },
                    {
                        id: "codex",
                        name: "Codex",
                        detail: "Turn completion only"
                    }
                ]
                delegate: ColumnLayout {
                    id: entry
                    required property var modelData
                    Layout.fillWidth: true
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.name
                            color: root.ink
                            font.pixelSize: Style.space(12)
                        }
                        PerchAction {
                            readonly property bool outdated: !!root.work && Array.isArray(root.work.health.updates) && root.work.health.updates.indexOf(entry.modelData.id) >= 0
                            text: outdated ? "Update now" : "Update"
                            selected: outdated
                            visible: !!root.work && root.work.health[entry.modelData.id] === "enabled"
                            enabled: !!root.work && !root.work.busy && !(root.work.health.job && root.work.health.job.status === "working")
                            ink: root.ink
                            surface: root.surface
                            onClicked: root.work.integration(entry.modelData.id, true)
                        }
                        PerchAction {
                            readonly property string state: root.work && root.work.health[entry.modelData.id] !== undefined ? root.work.health[entry.modelData.id] : "not checked"
                            text: state === "enabled" ? "Disable" : "Enable"
                            enabled: !!root.work && !root.work.busy && !(root.work.health.job && root.work.health.job.status === "working")
                            ink: root.ink
                            surface: root.surface
                            onClicked: root.work.integration(entry.modelData.id, state !== "enabled")
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: entry.modelData.detail + " · " + (root.work && root.work.health[entry.modelData.id] || "not checked") + (root.work && Array.isArray(root.work.health.updates) && root.work.health.updates.indexOf(entry.modelData.id) >= 0 ? " · installed copy is older than this Perch version" : "")
                        textFormat: Text.PlainText
                        color: Qt.alpha(root.ink, 0.55)
                        font.pixelSize: Style.space(10)
                        wrapMode: Text.WordWrap
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.work && root.work.health.job ? root.work.health.job.message || "" : ""
                textFormat: Text.PlainText
                color: root.ink
                font.pixelSize: Style.space(11)
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text: root.work ? "Brightness: " + (root.work.health.brightness || "not checked") + "\nFile sharing: " + (root.work.health.sharing || "not checked") + "\nTimer sound: " + (root.work.health.alarm || "not checked") : ""
                color: Qt.alpha(root.ink, 0.55)
                font.pixelSize: Style.space(10)
                wrapMode: Text.WordWrap
            }
            PerchAction {
                Layout.fillWidth: true
                text: root.confirmRemove ? "Confirm: restore defaults and remove hooks" : "Prepare Perch for removal"
                ink: root.ink
                surface: root.surface
                enabled: !!root.work && !root.work.busy
                onClicked: {
                    if (root.confirmRemove) {
                        root.work.removeIntegrations();
                        root.confirmRemove = false;
                    } else
                        root.confirmRemove = true;
                }
            }
            Text {
                Layout.fillWidth: true
                text: "Run this before disabling or removing Perch. Saved files, calendars and history are retained; shelf originals are never deleted."
                wrapMode: Text.WordWrap
                color: Qt.alpha(root.ink, 0.5)
                font.pixelSize: Style.space(10)
            }
        }
    }
}
