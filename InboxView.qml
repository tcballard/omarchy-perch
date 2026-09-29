import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons

ColumnLayout {
    id: root
    property var inbox: null
    property color ink: Color.foreground
    property color surface: Color.background
    property string appFilter: ""
    // Snapshots rebuild the rows; keep what the user typed, keyed by notification.
    property var drafts: ({})
    function draft(key, text) {
        var next = Object.assign({}, drafts);
        if (text)
            next[key] = text;
        else
            delete next[key];
        drafts = next;
    }
    onAppsChanged: if (appFilter && apps.indexOf(appFilter) < 0)
        appFilter = ""
    signal popupToggled(bool open)
    readonly property var apps: inbox ? Array.from(new Set(inbox.items.map(function (r) {
        return r.app;
    }))).sort() : []
    readonly property var filtered: inbox ? inbox.items.filter(function (r) {
        return !root.appFilter || r.app === root.appFilter;
    }) : []
    spacing: Style.space(8)
    RowLayout {
        Layout.fillWidth: true
        Item {
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
    RowLayout {
        Layout.fillWidth: true
        PerchCombo {
            ink: root.ink
            surface: root.surface
            onPopupToggled: open => root.popupToggled(open)
            Layout.fillWidth: true
            model: ["All applications"].concat(root.apps)
            currentIndex: root.apps.indexOf(root.appFilter) + 1
            onActivated: index => root.appFilter = index === 0 ? "" : root.apps[index - 1]
            Accessible.name: "Filter notifications by app"
        }
        PerchAction {
            text: root.inbox && root.inbox.blocked && root.inbox.blocked.indexOf(root.appFilter) >= 0 ? "Unmute app" : "Mute app"
            visible: root.appFilter !== ""
            enabled: !!root.inbox && root.inbox.connected && !root.inbox.busy
            ink: root.ink
            surface: root.surface
            onClicked: root.inbox.block(root.appFilter, root.inbox.blocked.indexOf(root.appFilter) < 0)
        }
        PerchAction {
            text: "Read"
            Accessible.name: "Mark all notifications read"
            enabled: !!root.inbox && root.inbox.connected && !root.inbox.busy
            ink: root.ink
            surface: root.surface
            onClicked: root.inbox.markRead()
        }
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
                model: root.filtered
                delegate: Rectangle {
                    id: notificationCard
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
                            Image {
                                Layout.preferredWidth: Style.space(16)
                                Layout.preferredHeight: Style.space(16)
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                                sourceSize.width: 32
                                sourceSize.height: 32
                                visible: source.toString() !== ""
                            }
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
                            text: (modelData.unread ? "• " : "") + modelData.title
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: root.ink
                            font.pixelSize: Style.space(12)
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: modelData.body
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: Qt.alpha(root.ink, 0.65)
                            font.pixelSize: Style.space(11)
                        }
                        RowLayout {
                            visible: notificationCard.modelData.reply === true
                            Layout.fillWidth: true
                            Controls.TextField {
                                id: reply
                                Layout.fillWidth: true
                                maximumLength: 1000
                                placeholderText: "Reply to this notification"
                                text: root.drafts[notificationCard.modelData.key] || ""
                                onTextEdited: root.draft(notificationCard.modelData.key, text)
                                color: root.ink
                                palette.base: root.surface
                                Accessible.name: "Notification reply"
                            }
                            PerchAction {
                                text: "Send"
                                ink: root.ink
                                surface: root.surface
                                enabled: reply.text.trim() !== "" && !!root.inbox && !root.inbox.busy
                                onClicked: {
                                    root.inbox.replyTo(notificationCard.modelData.key, reply.text);
                                    root.draft(notificationCard.modelData.key, "");
                                }
                            }
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
