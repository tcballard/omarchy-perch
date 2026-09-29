import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var live: null
    signal reviewRequested(string id)
    property color ink: Color.foreground
    property color surface: Color.background
    spacing: Style.space(12)
    function age(updatedAt) {
        var seconds = Math.max(0, Math.floor(((root.live ? root.live.now : Date.now()) - updatedAt) / 1000));
        if (seconds < 10)
            return "now";
        if (seconds < 60)
            return seconds + "s";
        var minutes = Math.floor(seconds / 60);
        return minutes < 60 ? minutes + "m" : Math.floor(minutes / 60) + "h";
    }

    RowLayout {
        Layout.fillWidth: true
        visible: !!root.live && root.live.attentionItems.length > 0
        spacing: Style.space(8)
        Rectangle {
            implicitWidth: Style.space(8)
            implicitHeight: implicitWidth
            radius: implicitWidth / 2
            color: "#f2b84b"
        }
        Text {
            Layout.fillWidth: true
            text: root.live && root.live.attentionItems.length === 1 ? "1 needs your attention" : (root.live ? root.live.attentionItems.length : 0) + " need your attention"
            color: root.ink
            font.pixelSize: Style.space(12)
            font.weight: Font.DemiBold
        }
    }

    Text {
        Layout.fillWidth: true
        visible: !root.live || !root.live.items.length
        text: "Builds, downloads, backups.\nLet your scripts report their progress here."
        color: Qt.alpha(root.ink, 0.6)
        font.pixelSize: Style.space(12)
        wrapMode: Text.WordWrap
    }
    Text {
        Layout.fillWidth: true
        visible: !root.live || !root.live.items.length
        text: "Connect a script using Perch’s activity command. See the README for examples."
        color: Qt.alpha(root.ink, 0.45)
        font.pixelSize: Style.space(11)
        wrapMode: Text.WordWrap
    }
    Controls.ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(Style.space(280), activityRows.implicitHeight)
        visible: !!root.live && root.live.items.length > 0
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            id: activityRows
            width: parent.width
            spacing: Style.space(8)
            Repeater {
                model: root.live ? root.live.displayItems : []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: info.implicitHeight + Style.space(22)
                    color: Qt.alpha(root.ink, 0.05)
                    radius: Style.space(10)
                    ColumnLayout {
                        id: info
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: Style.space(11)
                        }
                        spacing: Style.space(7)
                        PerchAction {
                            visible: !!modelData.requestId
                            text: "Review request"
                            ink: root.ink
                            surface: root.surface
                            onClicked: root.reviewRequested(modelData.id)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: root.ink
                                font.pixelSize: Style.space(12)
                                font.weight: Font.DemiBold
                            }
                            Text {
                                visible: modelData.kind === "agent" && modelData.agent !== ""
                                text: modelData.agent.toUpperCase()
                                textFormat: Text.PlainText
                                color: Qt.alpha(root.ink, 0.48)
                                font.pixelSize: Style.space(9)
                                font.letterSpacing: 0.8
                            }
                            NotchButton {
                                glyph: "close"
                                label: "Dismiss " + modelData.title
                                ink: root.ink
                                surface: root.surface
                                onClicked: root.live.dismiss(modelData.id)
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: modelData.detail
                            textFormat: Text.PlainText
                            color: Qt.alpha(root.ink, 0.65)
                            font.pixelSize: Style.space(11)
                            wrapMode: Text.Wrap
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: modelData.project !== ""
                            text: modelData.project
                            textFormat: Text.PlainText
                            elide: Text.ElideMiddle
                            color: Qt.alpha(root.ink, 0.48)
                            font.pixelSize: Style.space(10)
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            visible: modelData.progress >= 0
                            implicitHeight: Style.space(3)
                            color: Qt.alpha(root.ink, 0.1)
                            radius: 2
                            Rectangle {
                                width: parent.width * Math.max(0, modelData.progress)
                                height: parent.height
                                radius: 2
                                color: root.ink
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: (modelData.state === "idle" ? "Last seen" : modelData.state === "waiting" ? "Needs attention" : modelData.state === "error" ? "Failed" : modelData.state === "done" ? "Complete" : "In progress") + " · " + root.age(modelData.updatedAt)
                                color: Qt.alpha(root.ink, 0.5)
                                font.pixelSize: Style.space(10)
                            }
                            PerchAction {
                                objectName: "jump-session-" + modelData.id
                                visible: modelData.kind === "agent" && modelData.target !== ""
                                text: root.live && root.live.jumpBusy ? "Opening…" : "Go to session"
                                enabled: !!root.live && !root.live.jumpBusy
                                ink: root.ink
                                surface: root.surface
                                onClicked: root.live.jumpTo(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: !!root.live && (root.live.error !== "" || root.live.actionMessage !== "")
        text: root.live ? (root.live.error || root.live.actionMessage) : ""
        textFormat: Text.PlainText
        color: root.live && root.live.error ? "#e47b76" : Qt.alpha(root.ink, 0.6)
        font.pixelSize: Style.space(10)
        wrapMode: Text.WordWrap
    }
}
