import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var state: null
    property color ink: Color.foreground
    property color surface: Color.background
    Text {
        text: PerchStrings.t("Refresh interval")
        color: root.ink
        font.pixelSize: Style.space(13)
    }
    RowLayout {
        Repeater {
            model: [2, 5, 10]
            delegate: PerchAction {
                required property int modelData
                text: modelData + PerchStrings.t(" seconds")
                selected: !!root.state && root.state.statsInterval === modelData
                ink: root.ink
                surface: root.surface
                onClicked: if (root.state && root.state.preferences)
                    root.state.preferences.update({
                        moduleStatsInterval: modelData
                    })
            }
        }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: PerchStrings.t("Sampling stops when neither the stats tile nor its card is visible.")
        color: root.ink
        font.pixelSize: Style.space(11)
    }
    Item {
        Layout.fillHeight: true
    }
}
