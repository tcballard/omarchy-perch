import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import "BusinessPolicy.js" as Business

Controls.ScrollView {
    id: root
    property var state: null
    readonly property var manager: state ? state.manager : null
    property color ink: Color.foreground
    property color surface: Color.background
    property string mode: "report"
    implicitHeight: Style.space(350)
    contentWidth: availableWidth
    clip: true
    ColumnLayout {
        width: root.availableWidth
        spacing: Style.space(10)
        RowLayout {
            PerchAction {
                text: "Report"
                ink: root.ink
                surface: root.surface
                onClicked: root.mode = "report"
            }
            PerchAction {
                text: "Tile"
                ink: root.ink
                surface: root.surface
                onClicked: root.mode = "tile"
            }
            PerchAction {
                text: "Accounts"
                ink: root.ink
                surface: root.surface
                onClicked: {
                    root.mode = "accounts";
                    if (root.manager && !root.manager.busy)
                        root.manager.reload();
                }
            }
        }
        BusinessAccounts {
            Layout.fillWidth: true
            visible: root.mode === "accounts"
            manager: root.manager
            ink: root.ink
            surface: root.surface
            onAccountChosen: id => {
                if (root.state.configure({
                    accountId: id,
                    metric: ""
                }))
                    root.mode = "tile";
            }
        }
        ColumnLayout {
            visible: root.mode === "tile"
            Layout.fillWidth: true
            spacing: Style.space(8)
            Text {
                text: "This tile"
                color: root.ink
                font.pixelSize: Style.space(18)
                font.bold: true
            }
            Controls.ComboBox {
                id: accountPicker
                objectName: "business-tile-account"
                Layout.fillWidth: true
                model: root.manager ? root.manager.accounts : []
                textRole: "name"
                valueRole: "id"
                currentIndex: root.state && root.manager ? root.manager.accounts.findIndex(a => a.id === root.state.config.accountId) : -1
            }
            Text {
                text: "Metric"
                color: Qt.alpha(root.ink, 0.65)
                font.pixelSize: Style.space(11)
            }
            Controls.ComboBox {
                id: metricPicker
                Layout.fillWidth: true
                model: root.manager && accountPicker.currentIndex >= 0 ? Business.labels[root.manager.accounts[accountPicker.currentIndex].provider] || [] : []
                currentIndex: Math.max(0, model.indexOf(root.state ? root.state.config.metric : ""))
            }
            Controls.ComboBox {
                id: periodPicker
                Layout.fillWidth: true
                model: ["Today", "Last 7 days", "Month to date", "Last 30 days"]
                currentIndex: root.state ? Business.periods.indexOf(root.state.config.period) : 1
            }
            Controls.TextField {
                id: currency
                Layout.fillWidth: true
                text: root.state ? root.state.config.currency : "USD"
                placeholderText: "Stripe currency (GBP, USD…)"
                maximumLength: 3
                color: root.ink
                palette.base: root.surface
            }
            Controls.TextField {
                id: zone
                Layout.fillWidth: true
                text: root.state ? root.state.config.timeZone : "local"
                placeholderText: "Stripe time zone: local or Europe/London"
                maximumLength: 80
                color: root.ink
                palette.base: root.surface
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Stripe uses your selected currency and time zone. Paddle uses its balance currency and UTC. Shopify uses the store's currency and time zone."
                color: Qt.alpha(root.ink, 0.6)
                font.pixelSize: Style.space(10)
            }
            Controls.CheckBox {
                id: chart
                checked: !root.state || root.state.config.chart
                text: "Show daily chart"
                palette.windowText: root.ink
            }
            PerchAction {
                text: "Save tile"
                enabled: !!root.state && accountPicker.currentIndex >= 0
                ink: root.ink
                surface: root.surface
                onClicked: {
                    if (root.state.configure({
                        accountId: accountPicker.currentValue,
                        metric: metricPicker.currentText,
                        period: Business.periods[periodPicker.currentIndex],
                        currency: currency.text.toUpperCase(),
                        timeZone: zone.text,
                        chart: chart.checked
                    }))
                        root.mode = "report";
                }
            }
        }
        ColumnLayout {
            visible: root.mode === "report"
            Layout.fillWidth: true
            spacing: Style.space(8)
            RowLayout {
                Rectangle {
                    implicitWidth: 8
                    implicitHeight: 30
                    radius: 4
                    color: root.state && root.state.account ? root.state.account.color : Qt.alpha(root.ink, 0.2)
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: root.state && root.state.account ? root.state.account.name : "Choose a business account"
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: root.ink
                        font.pixelSize: Style.space(14)
                        font.bold: true
                    }
                    Text {
                        text: root.state && root.state.account ? root.state.account.provider + " · " + (root.state.account.sandbox === true ? "Sandbox" : root.state.account.sandbox === false ? "Live" : "Store") : "Connect an account in Accounts, then configure this tile."
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Qt.alpha(root.ink, 0.6)
                        font.pixelSize: Style.space(10)
                    }
                }
                PerchAction {
                    text: root.state && root.state.busy ? "Updating…" : "Refresh"
                    enabled: !!root.state && !!root.state.account && !root.state.busy
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.state.refresh(true)
                }
            }
            Text {
                text: root.state ? root.state.selectedLabel : "Business"
                color: Qt.alpha(root.ink, 0.7)
                font.pixelSize: Style.space(12)
            }
            Text {
                text: root.state ? root.state.headline : "—"
                color: root.ink
                font.pixelSize: Style.space(29)
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Qt.alpha(root.ink, 0.7)
                font.pixelSize: Style.space(11)
                text: {
                    var m = root.state ? root.state.selectedMetric : null;
                    if (!m)
                        return "Metric unavailable until a complete report is available.";
                    if (m.previous === null || m.previous === undefined)
                        return "Previous value unavailable — no percentage change calculated.";
                    return (m.changePercent === null ? "No percentage baseline" : (m.changePercent >= 0 ? "+" : "") + m.changePercent.toFixed(1) + "%") + " · previous " + (m.currency ? m.currency.toUpperCase() + " " : "") + Number(m.previous).toLocaleString(Qt.locale(), 'f', m.currency ? 2 : 0);
                }
            }
            Item {
                id: plot
                visible: !!root.state && root.state.config.chart && root.state.points.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(88)
                readonly property var points: root.state ? root.state.points : []
                readonly property real peak: Math.max(1, ...points.map(p => p.value === null ? 0 : Math.abs(p.value)))
                Rectangle {
                    width: parent.width
                    height: 1
                    y: parent.height / 2
                    color: Qt.alpha(root.ink, 0.18)
                }
                Row {
                    anchors.fill: parent
                    spacing: Style.space(2)
                    Repeater {
                        model: plot.points
                        delegate: Item {
                            required property var modelData
                            width: Math.max(1, (plot.width - parent.spacing * Math.max(0, plot.points.length - 1)) / Math.max(1, plot.points.length))
                            height: plot.height
                            Rectangle {
                                width: parent.width
                                visible: modelData.value !== null
                                height: Math.max(1, plot.height / 2 * Math.abs(modelData.value || 0) / plot.peak)
                                y: (modelData.value || 0) < 0 ? plot.height / 2 : plot.height / 2 - height
                                radius: 2
                                color: (modelData.value || 0) < 0 ? "#e47b76" : root.state && root.state.account ? root.state.account.color : root.ink
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: modelData.value === null
                                text: "·"
                                color: Qt.alpha(root.ink, 0.4)
                            }
                            Controls.ToolTip.text: modelData.date + ": " + (modelData.value === null ? "No observation" : Number(modelData.value).toFixed(2))
                            Controls.ToolTip.visible: hover.hovered
                            HoverHandler {
                                id: hover
                            }
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: Style.space(10)
                color: Qt.alpha(root.ink, 0.6)
                text: root.state && root.state.report ? root.state.report.period.first + " → " + root.state.report.period.last + " · " + root.state.report.period.timeZone + "\n" + (root.state.selectedMetric && root.state.selectedMetric.comparisonKind ? root.state.selectedMetric.comparisonKind : root.state.report.period.comparisonLabel) + "\nPrevious: " + root.state.report.period.previousFirst + " → " + root.state.report.period.previousLast : ""
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: Style.space(10)
                color: Qt.alpha(root.ink, 0.6)
                text: root.state && root.state.report && root.state.report.historyStarted ? "Observations begin " + root.state.report.historyStarted + ". Missing days stay blank; history records only successful refreshes while a tile is visible." : ""
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.state && root.state.report ? root.state.report.note : ""
                textFormat: Text.PlainText
                color: Qt.alpha(root.ink, 0.6)
                font.pixelSize: Style.space(10)
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.state ? (root.state.error || (root.state.report ? root.state.report.historyError || "" : "")) + (root.state.error && root.state.report ? " Showing the previous successful report." : "") : ""
                textFormat: Text.PlainText
                color: "#e47b76"
                font.pixelSize: Style.space(11)
            }
            Text {
                text: root.state && root.state.report ? "Updated " + new Date(root.state.report.updatedAt * 1000).toLocaleString() : ""
                color: Qt.alpha(root.ink, 0.5)
                font.pixelSize: Style.space(10)
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }
        Text {
            visible: root.mode !== "accounts"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.manager ? root.manager.error : ""
            textFormat: Text.PlainText
            font.pixelSize: Style.space(11)
            color: "#e47b76"
        }
    }
}
