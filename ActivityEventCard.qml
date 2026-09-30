import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var item: null
    property var live: null
    property color ink: Color.foreground
    property color surface: Color.background
    signal browseRequested
    signal dismissRequested
    signal responded
    spacing: Style.space(12)
    Text {
        Layout.fillWidth: true
        text: root.item ? root.item.title : PerchStrings.t("This activity has finished")
        textFormat: Text.PlainText
        color: root.ink
        font.pixelSize: Style.space(18)
        font.weight: Font.DemiBold
        wrapMode: Text.Wrap
    }
    Text {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.item ? [root.item.agent, root.item.project].filter(function (s) {
            return s;
        }).join(" · ") : ""
        textFormat: Text.PlainText
        color: Qt.alpha(root.ink, 0.55)
        font.pixelSize: Style.space(11)
        wrapMode: Text.Wrap
    }
    Controls.ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(Style.space(160), detail.implicitHeight)
        contentWidth: availableWidth
        clip: true
        Text {
            id: detail
            width: parent.width
            text: root.item ? root.item.detail : ""
            textFormat: Text.PlainText
            color: Qt.alpha(root.ink, 0.75)
            font.pixelSize: Style.space(13)
            wrapMode: Text.Wrap
        }
    }
    Text {
        Layout.fillWidth: true
        visible: !!root.item && root.item.state === "waiting" && !root.item.requestId
        text: root.item && root.item.attention === "approval" ? PerchStrings.t("Review this request in your agent session.") : PerchStrings.t("Continue in your session when you’re ready.")
        color: Qt.alpha(root.ink, 0.55)
        font.pixelSize: Style.space(11)
        wrapMode: Text.Wrap
    }
    RequestCard {
        Layout.fillWidth: true
        visible: !!root.item && !!root.item.requestId
        requestId: visible ? root.item.requestId : ""
        ink: root.ink
        surface: root.surface
        onResponded: root.responded()
    }
    Flow {
        Layout.fillWidth: true
        spacing: Style.space(6)
        PerchAction {
            objectName: "event-return"
            visible: !!root.item && root.item.kind === "agent" && (root.item.target !== "" || !!root.item.targetWorkspace)
            text: root.live && root.live.jumpBusy ? PerchStrings.t("Opening…") : root.item.targetWorkspace ? PerchStrings.t("Open workspace") : PerchStrings.t("Go to session")
            enabled: !!root.live && !root.live.jumpBusy
            ink: root.ink
            surface: root.surface
            onClicked: root.live.jumpTo(root.item)
        }
        PerchAction {
            objectName: "event-browse"
            text: "All activity"
            ink: root.ink
            surface: root.surface
            onClicked: root.browseRequested()
        }
        PerchAction {
            objectName: "event-dismiss"
            text: PerchStrings.t("Dismiss")
            ink: root.ink
            surface: root.surface
            onClicked: root.dismissRequested()
        }
    }
    Text {
        Layout.fillWidth: true
        visible: !!root.live && root.live.error !== ""
        text: root.live ? root.live.error : ""
        textFormat: Text.PlainText
        color: Qt.alpha(root.ink, 0.7)
        font.pixelSize: Style.space(11)
        wrapMode: Text.Wrap
    }
}
