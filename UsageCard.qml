import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var state: null
    property color ink: Color.foreground
    property color surface: Color.background
    property bool historyMode: false
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
    RowLayout {
        PerchAction {
            text: "Allowances"
            selected: !root.historyMode
            ink: root.ink
            surface: root.surface
            onClicked: root.historyMode = false
        }
        PerchAction {
            text: "Activity"
            selected: root.historyMode
            ink: root.ink
            surface: root.surface
            onClicked: root.historyMode = true
        }
    }
    ColumnLayout {
        visible: root.historyMode
        Layout.fillWidth: true
        Layout.fillHeight: true
        RowLayout {
            Controls.ComboBox {
                model: ["Codex", "Claude"]
                onActivated: if (root.state)
                    root.state.historyProvider = currentIndex === 0 ? "codex" : "claude"
            }
            Controls.ComboBox {
                model: ["Today", "Last 7 days", "Last 30 days"]
                currentIndex: 1
                onActivated: if (root.state)
                    root.state.historyDays = [1, 7, 30][currentIndex]
            }
        }
        Text {
            text: root.state && root.state.history ? (root.state.history.partial ? "≥ " : "") + root.state.history.tokens.toLocaleString() + " tokens" : "No local activity loaded"
            color: root.ink
            font.pixelSize: Style.space(23)
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(70)
            spacing: Style.space(2)
            readonly property var points: root.state && root.state.history ? root.state.history.days : []
            readonly property real peak: Math.max(1, ...points.map(p => p.tokens))
            Repeater {
                model: parent.points
                delegate: Rectangle {
                    required property var modelData
                    width: Math.max(2, (parent.width - parent.spacing * parent.points.length) / Math.max(1, parent.points.length))
                    height: Math.max(2, parent.height * modelData.tokens / parent.peak)
                    y: parent.height - height
                    radius: 2
                    color: Qt.alpha(root.ink, 0.65)
                    Controls.ToolTip.text: modelData.date + ": " + modelData.tokens
                    Controls.ToolTip.visible: hover.hovered
                    HoverHandler {
                        id: hover
                    }
                }
            }
        }
        Text {
            text: root.state ? root.state.historyError || (root.state.history ? root.state.history.note : "Enable local usage to read recorded counters.") : ""
            color: Qt.alpha(root.ink, 0.6)
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: Style.space(10)
            textFormat: Text.PlainText
        }
    }
    Controls.ScrollView {
        visible: !root.historyMode
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
