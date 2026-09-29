import QtQuick
import QtQuick.Layouts
import qs.Commons
import "ModulePolicy.js" as Modules

ColumnLayout {
    id: root
    property var items: Modules.defaults
    property color ink: Color.foreground
    property color surface: Color.background
    signal changed(var order)
    Text {
        text: "Strip modules · up to eight"
        color: root.ink
        font.pixelSize: Style.space(13)
    }
    Repeater {
        model: root.items
        delegate: RowLayout {
            required property string modelData
            required property int index
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: Modules.get(modelData).title
                color: root.ink
                font.pixelSize: Style.space(11)
            }
            PerchAction {
                text: "↑"
                Accessible.name: "Move " + modelData + " earlier"
                enabled: index > 0
                ink: root.ink
                surface: root.surface
                onClicked: root.changed(Modules.move(root.items, modelData, index - 1))
            }
            PerchAction {
                text: "↓"
                Accessible.name: "Move " + modelData + " later"
                enabled: index < root.items.length - 1
                ink: root.ink
                surface: root.surface
                onClicked: root.changed(Modules.move(root.items, modelData, index + 1))
            }
            PerchAction {
                text: "×"
                Accessible.name: "Remove " + modelData
                enabled: root.items.length > 1
                ink: root.ink
                surface: root.surface
                onClicked: root.changed(Modules.toggle(root.items, modelData))
            }
        }
    }
    Flow {
        Layout.fillWidth: true
        Layout.preferredHeight: childrenRect.height
        spacing: Style.space(5)
        Repeater {
            model: Modules.catalog.filter(function (m) {
                return root.items.indexOf(m.id) < 0;
            })
            delegate: PerchAction {
                required property var modelData
                text: "+ " + modelData.title
                enabled: root.items.length < 8
                ink: root.ink
                surface: root.surface
                onClicked: root.changed(Modules.toggle(root.items, modelData.id))
            }
        }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "Drag tiles to reorder, or focus one and use Ctrl + arrow keys. Cards keep the strip visible for switching."
        color: Qt.alpha(root.ink, 0.65)
        font.pixelSize: Style.space(10)
    }
}
