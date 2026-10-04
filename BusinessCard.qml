import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import qs.Commons

Controls.ScrollView {
    id: root
    property var state: null
    property color ink: Color.foreground
    property color surface: Color.background
    property bool setup: !state || !state.config.enabled
    implicitHeight: Style.space(310)
    contentWidth: availableWidth
    clip: true
    ColumnLayout {
        width: root.availableWidth
        spacing: Style.space(10)
        RowLayout {
            PerchAction {
                text: "Connect / configure"
                ink: root.ink
                surface: root.surface
                onClicked: root.setup = !root.setup
            }
            PerchAction {
                text: root.state && root.state.busy ? "Updating…" : "Refresh"
                enabled: !!root.state && !root.state.busy && root.state.config.enabled === true
                ink: root.ink
                surface: root.surface
                onClicked: root.state.refresh()
            }
        }
        ColumnLayout {
            visible: root.setup
            Layout.fillWidth: true
            Text {
                text: "Stripe · Paddle · Shopify"
                color: root.ink
                font.pixelSize: Style.space(17)
                font.bold: true
            }
            Text {
                text: "Choose your private connection file. Perch reads it only for this service; keys never enter layouts or the interface. See the Business connections guide for the JSON fields and read-only permissions."
                color: Qt.alpha(root.ink, 0.7)
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                font.pixelSize: Style.space(11)
            }
            Controls.TextField {
                id: path
                Layout.fillWidth: true
                placeholderText: "Private credential file"
                text: root.state ? root.state.config.path || "" : ""
                maximumLength: 4096
                color: root.ink
                palette.base: root.surface
            }
            PerchAction {
                text: "Choose file…"
                ink: root.ink
                surface: root.surface
                onClicked: picker.open()
            }
            Controls.ComboBox {
                id: period
                model: ["Today", "Last 7 days", "Last 30 days"]
                currentIndex: root.state ? [1, 7, 30].indexOf(root.state.config.days || 7) : 1
                Layout.fillWidth: true
            }
            Controls.TextField {
                id: currency
                Layout.fillWidth: true
                placeholderText: "Stripe currency (USD, GBP, EUR…)"
                text: root.state ? root.state.config.currency || "USD" : "USD"
                maximumLength: 3
                color: root.ink
                palette.base: root.surface
            }
            RowLayout {
                PerchAction {
                    text: "Connect"
                    ink: root.ink
                    surface: root.surface
                    onClicked: if (root.state.configure(path.text, [1, 7, 30][period.currentIndex], currency.text.toUpperCase(), true))
                        root.setup = false
                }
                PerchAction {
                    text: "Disconnect"
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.state.configure("", 7, "USD", false)
                }
            }
        }
        Repeater {
            model: root.state && root.state.report ? root.state.report.metrics : []
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Text {
                    text: modelData.label
                    color: Qt.alpha(root.ink, 0.7)
                    font.pixelSize: Style.space(12)
                    Layout.fillWidth: true
                }
                Text {
                    text: (modelData.currency ? modelData.currency.toUpperCase() + " " : "") + Number(modelData.value).toLocaleString(Qt.locale(), 'f', modelData.currency ? 2 : 0)
                    color: root.ink
                    font.pixelSize: Style.space(18)
                    font.bold: true
                }
            }
        }
        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(64)
            spacing: Style.space(2)
            readonly property var points: root.state && root.state.report ? root.state.report.chart : []
            readonly property real peak: Math.max(1, ...points.map(p => Math.abs(p.value)))
            Repeater {
                model: parent.points
                delegate: Rectangle {
                    required property var modelData
                    width: Math.max(2, (parent.width - parent.spacing * parent.points.length) / Math.max(1, parent.points.length))
                    height: Math.max(2, parent.height * Math.abs(modelData.value) / parent.peak)
                    y: parent.height - height
                    radius: 2
                    color: modelData.value < 0 ? "#e47b76" : Qt.alpha(root.ink, 0.6)
                    Controls.ToolTip.text: modelData.date + ": " + modelData.value
                    Controls.ToolTip.visible: hover.hovered
                    HoverHandler {
                        id: hover
                    }
                }
            }
        }
        Text {
            text: root.state && root.state.report ? root.state.report.note : "Choose a connection to see your metrics."
            color: Qt.alpha(root.ink, 0.65)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            font.pixelSize: Style.space(10)
            textFormat: Text.PlainText
        }
        Text {
            text: root.state ? root.state.error + (root.state.error && root.state.report ? " Showing the previous successful report." : "") : "Business metrics unavailable"
            color: "#e47b76"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            font.pixelSize: Style.space(11)
            textFormat: Text.PlainText
        }
        Text {
            visible: !!root.state && !!root.state.report
            text: visible ? "Updated " + new Date(root.state.report.updatedAt * 1000).toLocaleTimeString() : ""
            color: Qt.alpha(root.ink, 0.5)
            font.pixelSize: Style.space(10)
        }
    }
    FileDialog {
        id: picker
        onAccepted: path.text = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""))
    }
}
