import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var live: null
    property color ink: Color.foreground
    property color surface: Color.background
    spacing: Style.space(12)
    Text {
        text: "Live activities"
        color: root.ink
        font.pixelSize: Style.space(14)
        font.weight: Font.DemiBold
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
        Layout.preferredHeight: Style.space(232)
        visible: !!root.live && root.live.items.length > 0
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width
            spacing: Style.space(8)
            Repeater {
                model: root.live ? root.live.items : []
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
                            wrapMode: Text.WordWrap
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
                        Text {
                            text: modelData.state === "waiting" ? "Needs attention" : modelData.state === "error" ? "Failed" : modelData.state === "done" ? "Complete" : "In progress"
                            color: Qt.alpha(root.ink, 0.5)
                            font.pixelSize: Style.space(10)
                        }
                    }
                }
            }
        }
    }
}
