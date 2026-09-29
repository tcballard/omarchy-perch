import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var definition: null
    property bool configuring: false
    property color ink: Color.foreground
    property color surface: Color.background
    signal actionRequested(string id)
    onDefinitionChanged: configuring = false
    spacing: Style.space(8)
    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: root.definition ? root.definition.title : "Module unavailable"
            color: root.ink
            font.pixelSize: Style.space(14)
            font.bold: true
            font.family: Style.font.family
            textFormat: Text.PlainText
            elide: Text.ElideRight
        }
        Repeater {
            model: root.definition && !root.configuring ? root.definition.actions : []
            delegate: PerchAction {
                required property var modelData
                text: modelData.title
                ink: root.ink
                surface: root.surface
                onClicked: root.actionRequested(modelData.id)
            }
        }
        PerchAction {
            visible: !!root.definition && !!root.definition.settings
            text: root.configuring ? "Done" : "Configure"
            ink: root.ink
            surface: root.surface
            onClicked: root.configuring = !root.configuring
        }
    }
    Loader {
        id: body
        Layout.fillWidth: true
        Layout.fillHeight: true
        sourceComponent: root.definition ? (root.configuring ? root.definition.settings : root.definition.card) : null
    }
    Binding {
        target: body.item
        property: "ink"
        value: root.ink
        when: !!body.item
    }
    Binding {
        target: body.item
        property: "surface"
        value: root.surface
        when: !!body.item
    }
}
