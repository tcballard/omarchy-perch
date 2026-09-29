import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var desktop: null
    property color ink: Color.foreground
    property color surface: Color.background
    signal launched
    spacing: Style.space(8)
    Text {
        text: "Your desktop"
        color: root.ink
        font.pixelSize: Style.space(14)
        font.weight: Font.DemiBold
    }
    Text {
        text: "Quick access to Omarchy"
        color: Qt.alpha(root.ink, 0.55)
        font.pixelSize: Style.space(11)
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: Style.space(8)
        columnSpacing: Style.space(8)
        Repeater {
            model: root.desktop ? root.desktop.entries : []
            delegate: PerchAction {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: Style.space(44)
                text: modelData.label
                Accessible.description: modelData.detail
                ink: root.ink
                surface: root.surface
                enabled: !!root.desktop && !root.desktop.busy
                onClicked: if (root.desktop.launch(modelData.id))
                    root.launched()
            }
        }
    }
    Text {
        Layout.fillWidth: true
        text: root.desktop ? root.desktop.error : "Desktop shortcuts are unavailable in demo mode."
        wrapMode: Text.WordWrap
        color: Qt.alpha(root.ink, 0.6)
        font.pixelSize: Style.space(11)
    }
}
