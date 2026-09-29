import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var state: null
    property color ink: Color.foreground
    property color surface: Color.background
    spacing: Style.space(12)
    Repeater {
        model: [
            {
                label: "CPU",
                value: root.state ? root.state.cpu : -1
            },
            {
                label: PerchStrings.t("Memory"),
                value: root.state && root.state.sample ? root.state.sample.memory : -1
            },
            {
                label: PerchStrings.t("Root disk"),
                value: root.state && root.state.sample ? root.state.sample.disk : -1
            }
        ]
        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            RowLayout {
                Text {
                    Layout.fillWidth: true
                    text: modelData.label
                    color: root.ink
                    font.pixelSize: Style.space(13)
                }
                Text {
                    text: modelData.value >= 0 ? Math.round(modelData.value) + "%" : PerchStrings.t("Measuring…")
                    color: root.ink
                    font.pixelSize: Style.space(16)
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Style.space(5)
                radius: 2
                color: Qt.alpha(root.ink, 0.12)
                Rectangle {
                    width: parent.width * Math.max(0, modelData.value) / 100
                    height: parent.height
                    radius: 2
                    color: root.ink
                }
            }
        }
    }
    Row {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(42)
        spacing: Style.space(2)
        Repeater {
            model: root.state ? root.state.cpuHistory : []
            delegate: Rectangle {
                required property real modelData
                width: Math.max(2, (parent.width - 58) / 30)
                height: Math.max(2, parent.height * modelData / 100)
                y: parent.height - height
                color: Qt.alpha(root.ink, 0.6)
                radius: 1
            }
        }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: !root.state ? PerchStrings.t("Statistics unavailable") : root.state.statsError || PerchStrings.t("Refreshes every ") + root.state.statsInterval + PerchStrings.t(" seconds while visible. CPU history covers the last 30 samples.")
        color: Qt.alpha(root.ink, 0.65)
        font.pixelSize: Style.space(11)
    }
    Item {
        Layout.fillHeight: true
    }
}
