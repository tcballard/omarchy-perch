import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var inbox: null
    property color ink: Color.foreground
    property color surface: Color.background
    spacing: Style.space(8)
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "Notifications"
            color: root.ink
            font.pixelSize: Style.space(14)
            Layout.fillWidth: true
        }
        PerchAction {
            text: "Refresh"
            ink: root.ink
            surface: root.surface
            enabled: !!root.inbox && !root.inbox.busy
            onClicked: root.inbox.sync()
        }
    }
    RowLayout {
        visible: !!root.inbox && root.inbox.connected
        PerchAction {
            text: root.inbox && root.inbox.dnd ? "DND on" : "DND off"
            selected: !!root.inbox && root.inbox.dnd
            ink: root.ink
            surface: root.surface
            enabled: !!root.inbox && !root.inbox.busy
            onClicked: root.inbox.toggleDnd()
        }
        Item {
            Layout.fillWidth: true
        }
        PerchAction {
            text: "Clear all"
            ink: root.ink
            surface: root.surface
            enabled: !!root.inbox && root.inbox.items.length > 0 && !root.inbox.busy
            onClicked: root.inbox.clear()
        }
    }
    Text {
        Layout.fillWidth: true
        visible: !root.inbox || !root.inbox.connected || root.inbox.error !== ""
        text: root.inbox && root.inbox.error ? root.inbox.error : "Enable the optional notification companion to bring previews and history into Perch. See the setup guide."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Qt.alpha(root.ink, 0.6)
        font.pixelSize: Style.space(11)
    }
    Text {
        visible: !!root.inbox && root.inbox.connected && root.inbox.items.length === 0
        text: "You're all caught up"
        color: Qt.alpha(root.ink, 0.6)
        font.pixelSize: Style.space(13)
    }
    Controls.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width
            spacing: Style.space(8)
            Repeater {
                model: root.inbox ? root.inbox.items : []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: card.implicitHeight + Style.space(20)
                    color: Qt.alpha(root.ink, 0.05)
                    radius: Style.space(10)
                    ColumnLayout {
                        id: card
                        x: Style.space(10)
                        y: Style.space(10)
                        width: parent.width - Style.space(20)
                        spacing: Style.space(6)
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: modelData.app || "Notification"
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: Qt.alpha(root.ink, 0.5)
                                font.pixelSize: Style.space(10)
                            }
                            PerchAction {
                                text: "Dismiss"
                                ink: root.ink
                                surface: root.surface
                                enabled: !!root.inbox && root.inbox.connected && !root.inbox.busy
                                onClicked: root.inbox.dismiss(modelData.key)
                            }
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
                            text: modelData.body
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            color: Qt.alpha(root.ink, 0.65)
                            font.pixelSize: Style.space(11)
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: Style.space(4)
                            Repeater {
                                model: modelData.actions
                                delegate: PerchAction {
                                    required property var modelData
                                    text: modelData.label || "Open"
                                    ink: root.ink
                                    surface: root.surface
                                    enabled: !!root.inbox && root.inbox.connected && !root.inbox.busy
                                    onClicked: root.inbox.invoke(card.parent.modelData.key, modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
