import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
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
    readonly property bool available: media !== null
    readonly property bool hasPlayer: available && media.state !== "empty"
    readonly property bool playing: hasPlayer && media.state === "playing"
    readonly property string caption: hasPlayer ? media.title : "Ready when you are"
    // Use the darker of the theme's foreground/background for notch chrome.
    readonly property bool lightTheme: (Color.background.r + Color.background.g + Color.background.b) > (Color.foreground.r + Color.foreground.g + Color.foreground.b)
    readonly property color surface: lightTheme ? Color.foreground : Color.background
    readonly property color ink: lightTheme ? Color.background : Color.foreground
    readonly property real expandedWidth: Style.space(344)
    readonly property real expandedHeight: Style.space(settingsOpen ? 336 : hasPlayer ? 208 : 148)
    readonly property real maximumHeight: Style.space(336)
    implicitWidth: expanded ? expandedWidth : Style.space(sideTab ? 28 : hasPlayer ? 208 : 96)
    implicitHeight: expanded ? expandedHeight : Style.space(sideTab ? 80 : 30)
    signal edgeRequested(string value)
    signal expandRequested
    signal collapseRequested
    signal settingsChanged(bool hideIdle, bool reducedMotion, bool edgeAttached)
    onExpandedChanged: if (!expanded)
        settingsOpen = false
    Keys.onEscapePressed: {
        if (settingsOpen)
            settingsOpen = false;
        else
            collapseRequested();
    }
    clip: true

    Rectangle {
        anchors.fill: parent
        color: root.surface
        radius: Style.space(root.expanded ? 20 : 13)
        border.width: 1
        border.color: Qt.alpha(root.ink, 0.13)
        // Square the attached side without changing the inward corners.
        Rectangle {
            visible: root.edgeAttached
            color: root.surface
            width: Edges.vertical(root.edge) ? parent.radius : parent.width - 2
            height: Edges.vertical(root.edge) ? parent.height - 2 : parent.radius
            x: root.edge === "right" ? parent.width - width : 1
            y: root.edge === "bottom" ? parent.height - height : 1
        }
    }
    Item {
        anchors.fill: parent
        visible: !root.expanded
        Row {
            visible: !root.sideTab
            anchors.centerIn: parent
            spacing: Style.space(10)
            PerchIcon {
                name: root.playing ? "wave" : "music"
                ink: root.ink
                width: Style.space(16)
                height: width
            }
            Text {
                width: Style.space(root.hasPlayer ? 154 : 40)
                text: root.hasPlayer ? root.caption : "Perch"
                textFormat: Text.PlainText
                color: root.ink
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                elide: Text.ElideRight
            }
        }
        Column {
            visible: root.sideTab
            anchors.centerIn: parent
            spacing: Style.space(12)
            PerchIcon {
                name: root.playing ? "wave" : "music"
                ink: root.ink
                width: Style.space(16)
                height: width
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Style.space(3)
                height: Style.space(18)
                radius: 2
                color: Qt.alpha(root.ink, 0.3)
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expandRequested()
            Accessible.role: Accessible.Button
            Accessible.name: "Open Perch"
            Accessible.onPressAction: root.expandRequested()
        }
    }
    Item {
        id: content
        width: root.expandedWidth
        height: root.expandedHeight
        x: root.edge === "right" ? root.width - width : root.edge === "left" ? 0 : (root.width - width) / 2
        y: root.edge === "bottom" ? root.height - height : 0
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0
        enabled: root.expanded
        Behavior on opacity {
            NumberAnimation {
                duration: root.reducedMotion ? 0 : 90
            }
        }
        RowLayout {
            id: header
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: Style.space(18)
                rightMargin: Style.space(10)
                topMargin: Style.space(9)
            }
            spacing: Style.space(4)
            Text {
                Layout.fillWidth: true
                text: root.settingsOpen ? "Perch settings" : root.demo ? "Perch / demo" : root.hasPlayer ? root.media.identity : "Perch"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Qt.alpha(root.ink, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.space(10)
            }
            NotchButton {
                glyph: "settings"
                label: root.settingsOpen ? "Back to player" : "Settings"
                ink: root.ink
                surface: root.surface
                onClicked: root.settingsOpen = !root.settingsOpen
            }
            NotchButton {
                glyph: "close"
                label: "Collapse Perch"
                ink: root.ink
                surface: root.surface
                onClicked: root.collapseRequested()
            }
        }
        ColumnLayout {
            visible: !root.settingsOpen
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Style.space(18)
                topMargin: Style.space(48)
            }
            spacing: Style.space(14)
            RowLayout {
                spacing: Style.space(14)
                Rectangle {
                    Layout.preferredWidth: Style.space(root.hasPlayer ? 52 : 40)
                    Layout.preferredHeight: width
                    radius: Style.space(10)
                    color: Qt.alpha(root.ink, 0.07)
                    clip: true
                    PerchIcon {
                        anchors.centerIn: parent
                        name: "music"
                        ink: Qt.alpha(root.ink, 0.65)
                        width: Style.space(24)
                        height: width
                    }
                    Image {
                        anchors.fill: parent
                        source: root.hasPlayer ? root.media.art : ""
                        sourceSize.width: 128
                        sourceSize.height: 128
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
                        color: root.ink
                        font.family: Style.font.family
                        font.pixelSize: Style.space(14)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.hasPlayer ? root.media.artist : "Play music or a video.\nYour controls will appear here."
                        textFormat: Text.PlainText
                        color: Qt.alpha(root.ink, 0.55)
                        font.family: Style.font.family
                        font.pixelSize: Style.space(11)
                        wrapMode: root.hasPlayer ? Text.NoWrap : Text.WordWrap
                        elide: Text.ElideRight
                    }
                }
            }
            RowLayout {
                objectName: "transport"
                visible: root.hasPlayer
                Layout.fillWidth: true
                spacing: Style.space(10)
                Text {
                    Layout.fillWidth: true
                    text: root.playing ? "Playing" : "Paused"
                    color: Qt.alpha(root.ink, 0.45)
                    font.pixelSize: Style.space(10)
                }
                NotchButton {
                    glyph: "previous"
                    label: "Previous track"
                    ink: root.ink
                    surface: root.surface
                    enabled: root.hasPlayer && root.media.canPrevious
                    onClicked: root.media.act("previous")
                }
                NotchButton {
                    objectName: "playback"
                    glyph: root.playing ? "pause" : "play"
                    label: root.playing ? "Pause" : "Play"
                    prominent: true
                    ink: root.ink
                    surface: root.surface
                    enabled: root.hasPlayer && root.media.canToggle
                    onClicked: root.media.act("toggle")
                }
                NotchButton {
                    glyph: "next"
                    label: "Next track"
                    ink: root.ink
                    surface: root.surface
                    enabled: root.hasPlayer && root.media.canNext
                    onClicked: root.media.act("next")
                }
                Item {
                    Layout.fillWidth: true
                }
                NotchButton {
                    visible: root.hasPlayer && root.media.players.length > 1
                    glyph: "players"
                    label: "Switch player"
                    ink: root.ink
                    surface: root.surface
                    onClicked: {
                        var list = root.media.players;
                        var i = list.findIndex(function (p) {
                            return Policy.key(p) === root.media.playerKey;
                        });
                        root.media.choose(Policy.key(list[(i + 1) % list.length]));
                    }
                }
            }
            RowLayout {
                visible: root.hasPlayer && root.media.timeline
                Layout.fillWidth: true
                spacing: Style.space(10)
                Text {
                    text: root.hasPlayer ? Policy.time(root.media.position) : ""
                    color: Qt.alpha(root.ink, 0.45)
                    font.pixelSize: Style.space(9)
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Style.space(2)
                    radius: 1
                    color: Qt.alpha(root.ink, 0.14)
                    Rectangle {
                        height: parent.height
                        radius: 1
                        color: Qt.alpha(root.ink, 0.75)
                        width: parent.width * (root.hasPlayer && root.media.timeline ? Policy.progress(root.media.position, root.media.duration) : 0)
                    }
                }
                Text {
                    text: root.hasPlayer ? Policy.time(root.media.duration) : ""
                    color: Qt.alpha(root.ink, 0.45)
                    font.pixelSize: Style.space(9)
                }
            }
            Text {
                visible: text !== ""
                Layout.fillWidth: true
                text: root.available ? root.media.actionError : ""
                textFormat: Text.PlainText
                color: root.ink
                font.pixelSize: Style.space(10)
                elide: Text.ElideRight
            }
        }
        ColumnLayout {
            visible: root.settingsOpen
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Style.space(18)
                topMargin: Style.space(54)
            }
            spacing: Style.space(14)
            Text {
                text: "Screen edge"
                color: root.ink
                font.family: Style.font.family
                font.pixelSize: Style.space(12)
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(4)
                Repeater {
                    model: ["top", "bottom", "left", "right"]
                    delegate: Controls.Button {
                        required property string modelData
                        objectName: "edge-" + modelData
                        Layout.fillWidth: true
                        implicitHeight: Style.space(34)
                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        Accessible.name: "Use " + modelData + " screen edge"
                        background: Rectangle {
                            radius: Style.space(7)
                            color: root.edge === modelData ? root.ink : Qt.alpha(root.ink, parent.hovered ? 0.14 : 0.06)
                            border.width: parent.visualFocus ? 1 : 0
                            border.color: root.ink
                        }
                        contentItem: Text {
                            text: parent.text
                            color: root.edge === modelData ? root.surface : root.ink
                            font.pixelSize: Style.space(11)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: root.edgeRequested(modelData)
                    }
                }
            }
            Repeater {
                model: ["Hide when no player is open", "Reduce motion", "Attach flush to screen edge"]
                delegate: Controls.CheckBox {
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true
                    implicitHeight: Style.space(30)
                    text: modelData
                    checked: index === 0 ? root.hideIdle : index === 1 ? root.reducedMotion : root.edgeAttached
                    indicator: Rectangle {
                        x: parent.width - width
                        y: (parent.height - height) / 2
                        width: Style.space(28)
                        height: Style.space(16)
                        radius: height / 2
                        color: parent.checked ? root.ink : Qt.alpha(root.ink, 0.18)
                        border.width: parent.visualFocus ? 1 : 0
                        border.color: root.ink
                        Rectangle {
                            x: parent.parent.checked ? parent.width - width - 3 : 3
                            y: 3
                            width: parent.height - 6
                            height: width
                            radius: width / 2
                            color: parent.parent.checked ? root.surface : root.ink
                        }
                    }
                    contentItem: Text {
                        text: parent.text
                        color: root.ink
                        font.family: Style.font.family
                        font.pixelSize: Style.space(11)
                        verticalAlignment: Text.AlignVCenter
                        rightPadding: Style.space(36)
                    }
                    onToggled: root.settingsChanged(index === 0 ? checked : root.hideIdle, index === 1 ? checked : root.reducedMotion, index === 2 ? checked : root.edgeAttached)
                }
            }
            Text {
                text: "Preferences reset when the shell restarts."
                color: Qt.alpha(root.ink, 0.4)
                font.pixelSize: Style.space(10)
            }
        }
    }
}
