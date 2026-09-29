import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import qs.Commons

ColumnLayout {
    id: root
    property var work: null
    signal interactionChanged(bool active)
    property color ink: Color.foreground
    property color surface: Color.background
    spacing: Style.space(8)
    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "File shelf"
            color: root.ink
            font.pixelSize: Style.space(14)
            font.bold: true
        }
        PerchAction {
            text: "Add files"
            ink: root.ink
            surface: root.surface
            enabled: !!root.work && !root.work.busy
            onClicked: picker.open()
        }
    }
    Text {
        Layout.fillWidth: true
        text: "Drop files here. Drag a card out to another app. Originals stay where they are."
        color: Qt.alpha(root.ink, 0.55)
        font.pixelSize: Style.space(10)
        wrapMode: Text.WordWrap
    }
    FileDialog {
        id: picker
        onVisibleChanged: root.interactionChanged(visible)
        fileMode: FileDialog.OpenFiles
        onAccepted: if (root.work)
            root.work.addFiles(selectedFiles.map(function (u) {
                return String(u);
            }))
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
                model: root.work ? root.work.files : []
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Style.space(94)
                    radius: Style.space(10)
                    color: Qt.alpha(root.ink, 0.06)
                    // The whole card is the drag source; buttons still click normally
                    // because the handler only takes over past the drag threshold.
                    Drag.active: dragHandler.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.mimeData: ({
                            "text/uri-list": card.modelData.url
                        })
                    DragHandler {
                        id: dragHandler
                        target: null
                        enabled: card.modelData.exists
                        onActiveChanged: root.interactionChanged(active)
                    }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Style.space(8)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(8)
                            Grid {
                                columns: 2
                                spacing: Style.space(2)
                                opacity: card.modelData.exists ? 0.45 : 0.15
                                Repeater {
                                    model: 6
                                    delegate: Rectangle {
                                        width: Style.space(2)
                                        height: width
                                        radius: width / 2
                                        color: root.ink
                                    }
                                }
                            }
                            Text {
                                id: filename
                                Layout.fillWidth: true
                                text: card.modelData.name + (card.modelData.exists ? "" : " · missing")
                                textFormat: Text.PlainText
                                color: root.ink
                                font.pixelSize: Style.space(12)
                                elide: Text.ElideMiddle
                            }
                        }
                        RowLayout {
                            Repeater {
                                model: ["preview", "open", "reveal", "share", "remove"]
                                delegate: PerchAction {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    text: ({
                                            preview: "View",
                                            open: "Open",
                                            reveal: "Folder",
                                            share: "Share",
                                            remove: "×"
                                        })[modelData]
                                    Accessible.name: modelData + " " + card.modelData.name
                                    ink: root.ink
                                    surface: root.surface
                                    enabled: !!root.work && !root.work.busy && (card.modelData.exists || modelData === "remove")
                                    onClicked: root.work.fileAction(modelData, card.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: !!root.work && root.work.files.length === 0
                text: "Your shelf is empty"
                color: Qt.alpha(root.ink, 0.6)
                font.pixelSize: Style.space(12)
            }
            Text {
                Layout.fillWidth: true
                visible: !!root.work && root.work.previewKind === "text"
                text: root.work ? root.work.preview : ""
                textFormat: Text.PlainText
                color: root.ink
                font.pixelSize: Style.space(11)
                wrapMode: Text.WrapAnywhere
            }
            Image {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? Style.space(140) : 0
                visible: !!root.work && root.work.previewKind === "image"
                source: visible ? root.work.preview : ""
                sourceSize.width: 640
                sourceSize.height: 480
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            Text {
                Layout.fillWidth: true
                visible: !!root.work && root.work.previewKind === "external"
                text: "Use Open to preview this file in its application."
                color: root.ink
                wrapMode: Text.WordWrap
                font.pixelSize: Style.space(11)
            }
        }
    }
}
