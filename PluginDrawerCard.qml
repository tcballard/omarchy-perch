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
        text: !root.state ? PerchStrings.t("Plugin cards are unavailable") : root.state.busy ? PerchStrings.t("Loading…") : root.state.error || root.state.message || (root.state.card ? root.state.card.summary : PerchStrings.t("Open the plugin’s full panel, or retry its native card."))
        textFormat: Text.PlainText
        color: Qt.alpha(root.ink, 0.7)
        font.pixelSize: Style.space(12)
        wrapMode: Text.WordWrap
    }
    Flow {
        Layout.fillWidth: true
        spacing: Style.space(6)
        visible: !!root.state && !!root.state.card
        Repeater {
            model: root.state && root.state.card ? root.state.card.actions : []
            delegate: PerchAction {
                required property var modelData
                text: modelData.label
                enabled: !!root.state && !root.state.busy
                ink: root.ink
                surface: root.surface
                onClicked: root.state.act(modelData.id)
            }
        }
    }
    Controls.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: Math.min(Style.space(280), rows.implicitHeight)
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            id: rows
            width: parent.width
            spacing: Style.space(8)
            Repeater {
                model: root.state && root.state.card ? root.state.card.rows : []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: rowBody.implicitHeight + Style.space(20)
                    radius: Style.space(10)
                    color: Qt.alpha(root.ink, 0.05)
                    ColumnLayout {
                        id: rowBody
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: Style.space(10)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.title
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            color: root.ink
                            font.pixelSize: Style.space(12)
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: modelData.detail
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            color: Qt.alpha(root.ink, 0.6)
                            font.pixelSize: Style.space(11)
                        }
                        PerchAction {
                            objectName: "plugin-card-action-" + modelData.id
                            visible: !!modelData.action
                            text: modelData.action ? modelData.action.label : ""
                            enabled: !!root.state && !root.state.busy
                            ink: root.ink
                            surface: root.surface
                            onClicked: root.state.act(modelData.action.id)
                        }
                    }
                }
            }
        }
    }
}
