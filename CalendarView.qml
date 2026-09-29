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
    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "Your next 30 days"
            color: root.ink
            font.pixelSize: Style.space(14)
        }
        PerchAction {
            text: "Add ICS"
            ink: root.ink
            surface: root.surface
            enabled: !!root.work && !root.work.busy
            onClicked: picker.open()
        }
        PerchAction {
            text: "↻"
            Accessible.name: "Refresh calendar"
            ink: root.ink
            surface: root.surface
            enabled: !!root.work && !root.work.busy
            onClicked: root.work.refreshCalendar()
        }
    }
    Text {
        Layout.fillWidth: true
        text: "Choose a calendar export or an ICS file maintained by your sync tool."
        wrapMode: Text.WordWrap
        color: Qt.alpha(root.ink, 0.55)
        font.pixelSize: Style.space(10)
    }
    FileDialog {
        id: picker
        onVisibleChanged: root.interactionChanged(visible)
        nameFilters: ["Calendars (*.ics)"]
        onAccepted: if (root.work)
            root.work.calendarAdd(String(selectedFile))
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
                model: root.work ? root.work.events : []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: body.implicitHeight + Style.space(20)
                    radius: Style.space(10)
                    color: Qt.alpha(root.ink, 0.06)
                    ColumnLayout {
                        id: body
                        x: Style.space(10)
                        y: Style.space(10)
                        width: parent.width - Style.space(20)
                        Text {
                            Layout.fillWidth: true
                            text: Qt.formatDateTime(new Date(modelData.start), "ddd d MMM · HH:mm")
                            color: Qt.alpha(root.ink, 0.55)
                            font.pixelSize: Style.space(10)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.title
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            color: root.ink
                            font.pixelSize: Style.space(13)
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: modelData.location
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Qt.alpha(root.ink, 0.6)
                            font.pixelSize: Style.space(10)
                        }
                        PerchAction {
                            text: "Open meeting link"
                            visible: modelData.url !== ""
                            enabled: !!root.work && !root.work.busy
                            ink: root.ink
                            surface: root.surface
                            onClicked: root.work.join(modelData.url)
                        }
                    }
                }
            }
            Repeater {
                model: root.work ? root.work.calendarSources : []
                delegate: PerchAction {
                    required property string modelData
                    Layout.fillWidth: true
                    text: "Remove source · " + modelData.split('/').pop()
                    ink: root.ink
                    surface: root.surface
                    enabled: !!root.work && !root.work.busy
                    onClicked: root.work.calendarRemove(modelData)
                }
            }
        }
    }
}
