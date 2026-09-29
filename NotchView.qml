import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import "MediaPolicy.js" as Policy
import "EdgePolicy.js" as Edges

FocusScope {
    id: root
    property var media: null
    property string page: "music"
    property bool showClock: true
    property bool hoverOpen: true
    property bool eventBanners: true
    property string settingsError: ""
    readonly property var live: media ? media.live : null
    readonly property var system: media ? media.system : null
    readonly property bool liveAttention: !!(live && (live.timerStatus === "done" || (live.focused && (live.focused.state === "waiting" || live.focused.state === "error"))))
    readonly property string compactBanner: eventBanners && system ? system.banner : ""
    readonly property bool busy: hasPlayer || !!(live && live.hasActivity) || compactBanner !== ""
    readonly property string compactText: liveAttention ? live.summary : compactBanner || (live && live.hasActivity ? live.summary : hasPlayer ? caption : showClock && live ? live.clock : "Perch")
    readonly property string compactIcon: liveAttention ? "activity" : compactBanner ? "system" : live && live.timerActive ? "timer" : live && live.focused ? "activity" : playing ? "wave" : hasPlayer ? "music" : showClock ? "timer" : "music"
    function revealPage() {
        if (live && live.timerStatus === "done")
            page = "timer";
        else if (liveAttention || live && live.focused && !hasPlayer)
            page = "activity";
        else if (compactBanner)
            page = "system";
        else if (live && live.timerActive && !hasPlayer)
            page = "timer";
    }
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
    readonly property real expandedHeight: Style.space(settingsOpen ? 468 : page === "music" ? (hasPlayer ? 270 : 212) : 370)
    readonly property real maximumHeight: Style.space(468)
    implicitWidth: expanded ? expandedWidth : Style.space(sideTab ? 28 : busy ? 208 : 96)
    implicitHeight: expanded ? expandedHeight : Style.space(sideTab ? 80 : 30)
    signal preferenceChanged(string key, var value)
    signal edgeRequested(string value)
    signal expandRequested
    signal collapseRequested
    signal settingsChanged(bool hideIdle, bool reducedMotion, bool edgeAttached)
    onExpandedChanged: {
        if (!expanded)
            settingsOpen = false;
        else
            revealPage();
    }
    Keys.onEscapePressed: {
        if (settingsOpen)
            settingsOpen = false;
        else if (page !== "music")
            page = "music";
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
                name: root.compactIcon
                ink: root.ink
                width: Style.space(16)
                height: width
            }
            Text {
                width: Style.space(root.busy ? 154 : 40)
                text: root.compactText
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
                name: root.compactIcon
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
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: function (mouse) {
                if (mouse.button === Qt.MiddleButton && root.hasPlayer)
                    root.media.act("toggle");
                else
                    root.expandRequested();
            }
            Accessible.role: Accessible.Button
            Accessible.name: "Open Perch"
            Accessible.onPressAction: root.expandRequested()
        }
    }
    Rectangle {
        visible: !root.expanded && !!root.live && root.live.timerActive
        x: root.sideTab ? root.width - 2 : 8
        y: root.sideTab ? 8 : root.height - 2
        width: root.sideTab ? 2 : (root.width - 16) * root.live.timerProgress
        height: root.sideTab ? (root.height - 16) * root.live.timerProgress : 2
        color: root.ink
        opacity: 0.6
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
                text: root.settingsOpen ? "Perch settings" : root.demo ? "Perch / demo" : "Perch"
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
        RowLayout {
            visible: !root.settingsOpen
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: Style.space(18)
                rightMargin: Style.space(18)
                topMargin: Style.space(45)
            }
            spacing: Style.space(4)
            Repeater {
                model: ["music", "timer", "system", "activity"]
                delegate: PerchAction {
                    required property string modelData
                    objectName: "tab-" + modelData
                    Layout.fillWidth: true
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1) + (modelData === "activity" && root.live && root.live.items.length ? " · " + root.live.items.length : "")
                    selected: root.page === modelData
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.page = modelData
                }
            }
        }
        TimerView {
            visible: !root.settingsOpen && root.page === "timer"
            x: Style.space(18)
            y: Style.space(94)
            width: parent.width - Style.space(36)
            live: root.live
            ink: root.ink
            surface: root.surface
        }
        SystemView {
            visible: !root.settingsOpen && root.page === "system"
            x: Style.space(18)
            y: Style.space(94)
            width: parent.width - Style.space(36)
            system: root.system
            ink: root.ink
            surface: root.surface
        }
        ActivityView {
            visible: !root.settingsOpen && root.page === "activity"
            x: Style.space(18)
            y: Style.space(94)
            width: parent.width - Style.space(36)
            live: root.live
            ink: root.ink
            surface: root.surface
        }
        PlayersView {
            visible: !root.settingsOpen && root.page === "players"
            x: Style.space(18)
            y: Style.space(94)
            width: parent.width - Style.space(36)
            media: root.media
            ink: root.ink
            surface: root.surface
            onSelected: root.page = "music"
        }
        ColumnLayout {
            visible: !root.settingsOpen && root.page === "music"
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Style.space(18)
                topMargin: Style.space(94)
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
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.hasPlayer && root.media.canRaise
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.media.raisePlayer()
                        Accessible.role: Accessible.Button
                        Accessible.name: "Open media player"
                        Accessible.onPressAction: if (enabled)
                            root.media.raisePlayer()
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
                    visible: root.hasPlayer
                    glyph: "players"
                    label: "Switch player"
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.page = "players"
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
                PerchSlider {
                    id: seek
                    objectName: "seek"
                    Layout.fillWidth: true
                    ink: root.ink
                    enabled: root.hasPlayer && root.media.canSeek
                    property string capturedPlayer: ""
                    property string capturedTrack: ""
                    value: root.hasPlayer && root.media.timeline ? Policy.progress(root.media.position, root.media.duration) : 0
                    Accessible.name: "Track position"
                    onPressedChanged: {
                        if (pressed) {
                            capturedPlayer = root.media.playerKey;
                            capturedTrack = root.media.trackKey;
                        } else if (root.hasPlayer)
                            root.media.seekTo(value * root.media.duration, capturedPlayer, capturedTrack);
                    }
                    onMoved: if (!pressed && root.hasPlayer)
                        root.media.seekTo(value * root.media.duration, root.media.playerKey, root.media.trackKey)
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
                model: ["Hide when idle", "Reduce motion", "Attach flush to screen edge", "Clock when idle", "Open on hover", "Volume and power banners"]
                delegate: Controls.CheckBox {
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true
                    implicitHeight: Style.space(30)
                    text: modelData
                    checked: index === 0 ? root.hideIdle : index === 1 ? root.reducedMotion : index === 2 ? root.edgeAttached : index === 3 ? root.showClock : index === 4 ? root.hoverOpen : root.eventBanners
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
                    onToggled: root.preferenceChanged(["hideIdle", "reducedMotion", "edgeAttached", "showClock", "hoverOpen", "eventBanners"][index], checked)
                }
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.settingsError || (root.demo ? "Preferences apply to Perch, including demo." : "Saved automatically in Omarchy settings.")
                color: Qt.alpha(root.ink, 0.4)
                font.pixelSize: Style.space(10)
            }
        }
    }
}
