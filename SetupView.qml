import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var work: null
    property var relay: null
    property color ink: Color.foreground
    property color surface: Color.background
    property bool confirmRemove: false
    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: PerchStrings.t("Make Perch yours")
            color: root.ink
            font.pixelSize: Style.space(14)
            font.bold: true
        }
        PerchAction {
            text: PerchStrings.t("Check")
            ink: root.ink
            surface: root.surface
            enabled: !!root.work && !root.work.busy
            onClicked: root.work.checkHealth()
        }
    }
    Text {
        Layout.fillWidth: true
        text: PerchStrings.t("Choose what Perch handles. Notifications and system feedback replace their built-in counterparts; disabling restores them.")
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
                        id: "requests",
                        name: PerchStrings.t("Claude approvals & questions"),
                        detail: PerchStrings.t("Explicit responses in Perch; tool inputs visible only while a request is pending")
                    },
                    {
                        id: "usage",
                        name: PerchStrings.t("Claude usage status line"),
                        detail: PerchStrings.t("Opt-in local rate-limit counters; preserves custom status lines")
                    },
                    {
                        id: "notifications",
                        name: PerchStrings.t("Notifications"),
                        detail: PerchStrings.t("Inbox, replies and persistent history")
                    },
                    {
                        id: "osd",
                        name: PerchStrings.t("System feedback"),
                        detail: PerchStrings.t("One set of volume and brightness overlays")
                    },
                    {
                        id: "claude",
                        name: "Claude Code",
                        detail: PerchStrings.t("Working, attention and completion")
                    },
                    {
                        id: "gemini",
                        name: "Gemini CLI",
                        detail: PerchStrings.t("Working, permission attention and completion; respond in Gemini")
                    },
                    {
                        id: "cursor",
                        name: "Cursor",
                        detail: PerchStrings.t("Working, completion and errors; local desktop sessions")
                    },
                    {
                        id: "qwen",
                        name: "Qwen Code",
                        detail: PerchStrings.t("Working, attention and completion")
                    },
                    {
                        id: "qoder",
                        name: "Qoder CLI",
                        detail: PerchStrings.t("Working, attention and completion")
                    },
                    {
                        id: "factory",
                        name: "Factory Droid",
                        detail: PerchStrings.t("Working, attention and completion")
                    },
                    {
                        id: "codebuddy",
                        name: "CodeBuddy Code",
                        detail: PerchStrings.t("Working, attention and completion")
                    },
                    {
                        id: "pi",
                        name: "Pi",
                        detail: PerchStrings.t("Working and completion; local extension")
                    },
                    {
                        id: "omp",
                        name: "Oh My Pi",
                        detail: PerchStrings.t("Working and completion; local extension")
                    },
                    {
                        id: "opencode",
                        name: "OpenCode (v1 plugin API)",
                        detail: PerchStrings.t("Working, permission attention and completion; local extension")
                    },
                    {
                        id: "codex",
                        name: "Codex",
                        detail: PerchStrings.t("Turn completion only")
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
                            text: outdated ? PerchStrings.t("Update now") : PerchStrings.t("Update")
                            selected: outdated
                            visible: !!root.work && root.work.health[entry.modelData.id] === "enabled"
                            enabled: !!root.work && !root.work.busy && !(root.work.health.job && root.work.health.job.status === "working")
                            ink: root.ink
                            surface: root.surface
                            onClicked: root.work.integration(entry.modelData.id, true)
                        }
                        PerchAction {
                            readonly property string state: root.work && root.work.health[entry.modelData.id] !== undefined ? root.work.health[entry.modelData.id] : "not checked"
                            text: state === "enabled" ? PerchStrings.t("Disable") : PerchStrings.t("Enable")
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
            PerchToggle {
                Layout.fillWidth: true
                text: PerchStrings.t("Receive remote agent status")
                description: PerchStrings.t("Optional SSH socket forwarding. Status only; permissions stay in the remote session.")
                checked: !!root.relay && root.relay.optedIn
                enabled: !!root.relay
                ink: root.ink
                surface: root.surface
                onToggled: root.relay.setEnabled(checked)
            }
            Text {
                Layout.fillWidth: true
                visible: !!root.relay && root.relay.optedIn
                text: root.relay ? root.relay.error || root.relay.endpoint || PerchStrings.t("Starting receiver…") : ""
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                color: Qt.alpha(root.ink, 0.6)
                font.pixelSize: Style.space(10)
            }
            PerchAction {
                Layout.fillWidth: true
                text: root.confirmRemove ? PerchStrings.t("Confirm: restore defaults and remove hooks") : PerchStrings.t("Prepare Perch for removal")
                ink: root.ink
                surface: root.surface
                enabled: !!root.work && !root.work.busy
                onClicked: {
                    if (root.confirmRemove) {
                        if (root.relay)
                            root.relay.setEnabled(false);
                        root.work.removeIntegrations();
                        root.confirmRemove = false;
                    } else
                        root.confirmRemove = true;
                }
            }
            Text {
                Layout.fillWidth: true
                text: PerchStrings.t("Run this before disabling or removing Perch. Saved files, calendars and history are retained; shelf originals are never deleted.")
                wrapMode: Text.WordWrap
                color: Qt.alpha(root.ink, 0.5)
                font.pixelSize: Style.space(10)
            }
        }
    }
}
