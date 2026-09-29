import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "MediaPolicy.js" as Policy
import "EdgePolicy.js" as Edges

FocusScope {
    id: root
    property var media: null
    property bool expanded: false
    property bool reducedMotion: false
    property bool demo: false
    property bool settingsOpen: false
    property bool hideIdle: false
    property bool edgeAttached: false
    property string edge: "top"
    readonly property bool sideTab: !expanded && Edges.vertical(edge)
    signal edgeRequested(string value)
    signal expandRequested
    signal collapseRequested
    signal settingsChanged(bool hideIdle, bool reducedMotion, bool edgeAttached)
    readonly property bool available: media !== null
    readonly property bool hasPlayer: available && media.state !== "empty"
    readonly property bool playing: available && media.state === "playing"
    readonly property string caption: !available ? "Connecting to media…" : media.title
    implicitWidth: Style.space(expanded ? 380 : sideTab ? 36 : hasPlayer ? 224 : 140)
    implicitHeight: Style.space(expanded ? (settingsOpen ? 376 : 250) : sideTab ? 108 : 36)
    onExpandedChanged: if (!expanded)
        settingsOpen = false
    Keys.onEscapePressed: collapseRequested()

    BorderSurface {
        anchors.fill: parent
        radius: Math.max(Style.cornerRadius, Style.space(root.expanded ? 22 : 14))
        color: Color.popups.background
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
        clip: true
        RowLayout {
            visible: !root.sideTab
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Style.space(10)
            }
            height: Style.space(16)
            spacing: Style.space(8)
            Rectangle {
                width: Style.space(6)
                height: width
                radius: width / 2
                color: root.playing ? Color.accent : Qt.alpha(Color.foreground, 0.35)
            }
            Text {
                Layout.fillWidth: true
                text: root.expanded ? (root.demo ? "DEMO · NOW PLAYING" : "NOW PLAYING") : root.hasPlayer ? root.caption : "Perch"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.letterSpacing: root.expanded ? 1.2 : 0
                color: Color.foreground
                elide: Text.ElideRight
            }
            Text {
                visible: !root.expanded && root.hasPlayer
                text: root.playing ? "Ⅱ" : "♪"
                color: Color.accent
                font.pixelSize: Style.font.body
            }
            Controls.ToolButton {
                visible: root.expanded
                text: "×"
                Accessible.name: "Collapse notch"
                implicitWidth: Style.space(28)
                implicitHeight: Style.space(24)
                onClicked: root.collapseRequested()
                contentItem: Text {
                    text: "×"
                    color: Color.foreground
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Style.font.heading
                }
                background: Rectangle {
                    radius: 6
                    color: parent.hovered ? Qt.alpha(Color.foreground, 0.12) : "transparent"
                }
            }
        }
        Column {
            visible: root.sideTab
            anchors.centerIn: parent
            spacing: Style.space(12)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Style.space(6)
                height: width
                radius: width / 2
                color: root.playing ? Color.accent : Qt.alpha(Color.foreground, 0.35)
            }
            Text {
                text: "♪"
                color: Color.foreground
                font.pixelSize: Style.font.heading
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.edge === "left" ? "›" : "‹"
                color: Color.accent
                font.pixelSize: Style.font.body
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: !root.expanded
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expandRequested()
            Accessible.role: Accessible.Button
            Accessible.name: "Expand now playing"
            Accessible.onPressAction: root.expandRequested()
        }
        ColumnLayout {
            visible: root.expanded
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: Style.space(48)
                leftMargin: Style.space(22)
                rightMargin: Style.space(22)
            }
            spacing: Style.space(12)
            RowLayout {
                spacing: Style.space(16)
                Rectangle {
                    Layout.preferredWidth: Style.space(64)
                    Layout.preferredHeight: Style.space(64)
                    radius: Style.space(10)
                    color: Qt.alpha(Color.accent, 0.13)
                    clip: true
                    Text {
                        anchors.centerIn: parent
                        text: "♪"
                        color: Color.accent
                        font.pixelSize: Style.font.displayLarge
                    }
                    Image {
                        anchors.fill: parent
                        source: root.available ? root.media.art : ""
                        sourceSize.width: 160
                        sourceSize.height: 160
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(5)
                    Text {
                        Layout.fillWidth: true
                        text: root.caption
                        textFormat: Text.PlainText
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading
                        font.weight: Font.DemiBold
                        color: Color.foreground
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.available ? root.media.artist : "Waiting for the media service"
                        textFormat: Text.PlainText
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        color: Qt.alpha(Color.foreground, 0.65)
                        elide: Text.ElideRight
                    }
                    Text {
                        text: root.hasPlayer ? (root.playing ? "Playing" : "Paused / stopped") : "No MPRIS player"
                        textFormat: Text.PlainText
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        color: Color.accent
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(4)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Style.space(3)
                    radius: height / 2
                    color: Qt.alpha(Color.foreground, 0.13)
                    Rectangle {
                        height: parent.height
                        radius: height / 2
                        color: Color.accent
                        width: parent.width * (root.available && root.media.timeline ? Policy.progress(root.media.position, root.media.duration) : 0)
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: root.available && root.media.timeline ? Policy.time(root.media.position) : "—"
                        color: Qt.alpha(Color.foreground, 0.5)
                        font.pixelSize: Style.font.caption
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.available && root.media.timeline ? Policy.time(root.media.duration) : "—"
                        color: Qt.alpha(Color.foreground, 0.5)
                        font.pixelSize: Style.font.caption
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(6)
                NotchButton {
                    text: "⚙"
                    label: "Notch settings"
                    onClicked: root.settingsOpen = !root.settingsOpen
                }
                Item {
                    Layout.fillWidth: true
                }
                NotchButton {
                    text: "‹"
                    label: "Previous track"
                    enabled: root.available && root.media.canPrevious
                    onClicked: root.media.act("previous")
                }
                NotchButton {
                    text: root.playing ? "Ⅱ" : "▶"
                    label: root.playing ? "Pause" : "Play"
                    prominent: true
                    enabled: root.available && root.media.canToggle
                    onClicked: root.media.act("toggle")
                }
                NotchButton {
                    text: "›"
                    label: "Next track"
                    enabled: root.available && root.media.canNext
                    onClicked: root.media.act("next")
                }
                Item {
                    Layout.fillWidth: true
                }
                NotchButton {
                    text: "↻"
                    label: "Switch media player"
                    enabled: root.available && root.media.players.length > 1
                    onClicked: {
                        var list = root.media.players;
                        var index = list.findIndex(function (p) {
                            return Policy.key(p) === root.media.playerKey;
                        });
                        root.media.choose(Policy.key(list[(index + 1) % list.length]));
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.available ? (root.media.actionError || root.media.identity) : ""
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                color: Qt.alpha(Color.foreground, 0.5)
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
            }
            RowLayout {
                visible: root.settingsOpen
                Layout.fillWidth: true
                spacing: Style.space(4)
                Repeater {
                    model: ["top", "bottom", "left", "right"]
                    delegate: Controls.Button {
                        required property string modelData
                        Layout.fillWidth: true
                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        checkable: true
                        checked: root.edge === modelData
                        Accessible.name: "Use " + modelData + " screen edge"
                        onClicked: root.edgeRequested(modelData)
                    }
                }
            }
            Text {
                visible: root.settingsOpen
                text: "Session preferences"
                color: Qt.alpha(Color.foreground, 0.5)
                font.pixelSize: Style.font.caption
            }
            Flow {
                visible: root.settingsOpen
                Layout.fillWidth: true
                spacing: Style.space(5)
                Repeater {
                    model: ["Hide idle", "Reduce motion", "Screen edge"]
                    delegate: Controls.CheckBox {
                        required property int index
                        required property string modelData
                        text: modelData
                        checked: index === 0 ? root.hideIdle : index === 1 ? root.reducedMotion : root.edgeAttached
                        onToggled: root.settingsChanged(index === 0 ? checked : root.hideIdle, index === 1 ? checked : root.reducedMotion, index === 2 ? checked : root.edgeAttached)
                    }
                }
            }
        }
    }
}
