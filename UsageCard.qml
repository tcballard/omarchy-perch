import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var state: null
    property color ink: Color.foreground
    property color surface: Color.background
    spacing: Style.space(10)
    Text {
        Layout.fillWidth: true
        text: PerchStrings.t("Read usage counters from local Codex sessions and the optional Claude status-line bridge. No account login or credential access.")
        color: Qt.alpha(root.ink, 0.65)
        font.pixelSize: Style.space(11)
        wrapMode: Text.Wrap
    }
    RowLayout {
        PerchAction {
            objectName: "usage-enable"
            text: root.state && root.state.usageEnabled ? PerchStrings.t("Disable usage") : PerchStrings.t("Enable local usage")
            enabled: !!root.state
            ink: root.ink
            surface: root.surface
            onClicked: root.state.setEnabled(!root.state.usageEnabled)
        }
        PerchAction {
            text: PerchStrings.t("Refresh")
            enabled: !!root.state && root.state.usageEnabled && !root.state.busy
            ink: root.ink
            surface: root.surface
            onClicked: root.state.refresh()
        }
    }
    Controls.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: Style.space(240)
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            width: parent.width
            spacing: Style.space(12)
            Repeater {
                model: root.state ? root.state.sources : []
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Text {
                        text: modelData.name + " · " + modelData.status
                        color: root.ink
                        font.pixelSize: Style.space(12)
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.windows.length ? PerchStrings.t("Updated ") + new Date(modelData.updatedAt * 1000).toLocaleString() : modelData.name === "Claude" ? PerchStrings.t("Enable Claude usage in Setup, then start a terminal session. Your client and account must expose rate limits.") : PerchStrings.t("Run Codex locally to populate a usage snapshot.")
                        color: Qt.alpha(root.ink, 0.55)
                        font.pixelSize: Style.space(10)
                        wrapMode: Text.Wrap
                    }
                    Repeater {
                        model: modelData.windows
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: modelData.label + " · " + Math.round(modelData.used) + PerchStrings.t("% used") + (modelData.resetsAt ? PerchStrings.t(" · resets ") + new Date(modelData.resetsAt * 1000).toLocaleString() : "")
                                color: root.ink
                                font.pixelSize: Style.space(11)
                                wrapMode: Text.Wrap
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: Style.space(5)
                                radius: height / 2
                                color: Qt.alpha(root.ink, 0.1)
                                Rectangle {
                                    width: parent.width * modelData.used / 100
                                    height: parent.height
                                    radius: height / 2
                                    color: Qt.alpha(root.ink, 0.65)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        text: root.state ? root.state.error || (root.state.busy ? PerchStrings.t("Reading counters…") : PerchStrings.t("Snapshots are not live billing data. Refresh after another agent response.")) : PerchStrings.t("Usage unavailable in this preview.")
        wrapMode: Text.Wrap
        color: Qt.alpha(root.ink, 0.6)
        font.pixelSize: Style.space(10)
    }
}
