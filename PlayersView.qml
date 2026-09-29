import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import "MediaPolicy.js" as Policy

ColumnLayout {
    id: root
    property var media: null
    property color ink: Color.foreground
    property color surface: Color.background
    signal selected
    spacing: Style.space(12)
    Text {
        text: "Choose a player"
        color: root.ink
        font.pixelSize: Style.space(14)
        font.weight: Font.DemiBold
    }
    PerchAction {
        Layout.fillWidth: true
        text: "Automatic · follow playback"
        ink: root.ink
        surface: root.surface
        selected: !!root.media && !root.media.preferred
        onClicked: {
            root.media.choose("");
            root.selected();
        }
    }
    Controls.ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(210)
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width
            Repeater {
                model: root.media ? root.media.players : []
                delegate: PerchAction {
                    required property var modelData
                    Layout.fillWidth: true
                    text: Policy.bounded(modelData.identity, "Player") + (modelData.isPlaying ? " · playing" : "")
                    selected: !!root.media && root.media.playerKey === Policy.key(modelData)
                    ink: root.ink
                    surface: root.surface
                    onClicked: {
                        root.media.choose(Policy.key(modelData));
                        root.selected();
                    }
                }
            }
        }
    }
}
