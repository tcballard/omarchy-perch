import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import qs.Commons
import "MediaPolicy.js" as Policy
import "EdgePolicy.js" as Edges
import "ContextPolicy.js" as Contexts
import "ModulePolicy.js" as Modules

FocusScope {
    id: root
    property var media: null
    property bool surfaceVisible: true
    readonly property var moduleState: media && media.modules !== undefined ? media.modules : null
    readonly property bool stripMode: displaySettings.layoutMode === "strip"
    readonly property var moduleItems: Modules.clean(displaySettings.modules)
    readonly property bool stripVertical: Edges.vertical(edge)
    readonly property real stripLength: Style.space(46 * moduleItems.length + 8)
    readonly property real compactWidth: stripMode ? (stripVertical ? Style.space(52) : stripLength) : Style.space(sideTab ? 28 : busy ? (context.id === "system" ? 184 : 232) : 96)
    readonly property real compactHeight: stripMode ? (stripVertical ? stripLength : Style.space(52)) : Style.space(sideTab ? 80 : 30)
    readonly property real bodyTop: stripMode ? Style.space(132) : Style.space(94)
    function activateModule(id, pointer) {
        var descriptor = Modules.get(id);
        if (!descriptor)
            return;
        settingsOpen = false;
        page = descriptor.page;
        if (!expanded)
            expandRequested();
    }
    ModuleRegistry {
        id: moduleRegistry
        state: root.moduleState
    }
    Binding {
        target: root.moduleState
        property: "statsVisible"
        when: !!root.moduleState
        value: root.surfaceVisible && (root.stripMode && !root.settingsOpen && root.moduleItems.indexOf("stats") >= 0 || root.expanded && !root.settingsOpen && root.page === "stats")
    }
    Binding {
        target: root.moduleState
        property: "clipboardVisible"
        when: !!root.moduleState
        value: root.surfaceVisible && root.expanded && !root.settingsOpen && root.page === "clipboard"
    }
    Binding {
        target: root.moduleState
        property: "weatherVisible"
        when: !!root.moduleState
        value: root.surfaceVisible && (root.stripMode && !root.settingsOpen && root.moduleItems.indexOf("weather") >= 0 || root.expanded && !root.settingsOpen && root.page === "weather")
    }
    property string page: "music"
    property bool showClock: true
    property bool hoverOpen: true
    property bool eventBanners: true
    property string settingsError: ""
    readonly property var live: media ? media.live : null
    readonly property var system: media ? media.system : null
    readonly property var work: media && media.workspace !== undefined ? media.workspace : null
    property var displayNames: []
    property var displaySettings: ({})
    property real preferredWidth: Style.space(344)
    property bool interactionActive: false
    // A dropdown popup lives in the window overlay outside this item's bounds.
    property bool popupOpen: false
    readonly property Item overlayItem: Controls.Overlay.overlay
    signal dropReceived(var urls)
    readonly property var inbox: media && media.notifications !== undefined ? media.notifications : null
    readonly property var desktop: media && media.desktop !== undefined ? media.desktop : null
    readonly property string notificationPreview: inbox ? inbox.preview : ""
    property int pageOrder: 0
    readonly property real pageOffset: pageSlide.x
    readonly property real pageOpacity: pages.opacity
    readonly property var pageSequence: ["music", "timer", "system", "activity", "players", "lyrics", "hub", "shelf", "calendar", "desktop", "inbox", "setup", "clipboard", "stats", "weather"]
    // Transitions run only for changes after construction, while expanded.
    property bool ready: false
    Component.onCompleted: ready = true
    function enterPage(forward) {
        if (!ready || !expanded)
            return;
        pageSlide.x = Style.space(forward ? 10 : -10);
        pageEnter.restart();
    }
    onPageChanged: {
        var order = pageSequence.indexOf(page);
        enterPage(order >= pageOrder);
        pageOrder = Math.max(0, order);
        if (page === "inbox" && inbox)
            inbox.sync();
        if (work) {
            if (page === "shelf")
                work.refreshFiles();
            else if (page === "calendar")
                work.refreshCalendar();
            else if (page === "desktop")
                work.request("app-list", {});
            else if (page === "setup")
                work.checkHealth();
            else if (page === "system")
                work.request("brightness-get", {});
        }
    }
    readonly property bool liveAttention: !!(live && (live.timerStatus === "done" || (live.focused && (live.focused.state === "waiting" || live.focused.state === "error"))))
    readonly property string compactBanner: eventBanners && system ? system.banner : ""
    readonly property bool busy: hasPlayer || !!(live && live.hasActivity) || compactBanner !== "" || notificationPreview !== "" || !!(work && work.meetingSummary)
    property int contextIndex: 0
    readonly property var contexts: Contexts.contexts(media, eventBanners, showClock)
    readonly property var context: contexts.length ? contexts[Math.min(contextIndex, contexts.length - 1)] : ({
            id: "idle",
            title: "Perch",
            icon: "music",
            page: "music",
            action: "open"
        })
    readonly property string compactText: context.title
    readonly property string compactIcon: context.icon
    // Animate when the kind of context changes, not on every countdown tick.
    readonly property string compactKey: context.id + ":" + (context.timerId || "") + ":" + page
    onCompactKeyChanged: if (ready && !expanded)
        compactEnter.restart()
    readonly property bool compactArt: context.id === "music" && hasPlayer && media.art !== ""
    onContextsChanged: if (contextIndex >= contexts.length)
        contextIndex = 0
    function revealPage() {
        if (context.timerId && live.chooseTimer)
            live.chooseTimer(context.timerId);
        page = context.page;
    }
    function compactAction() {
        if (context.action === "toggle")
            media.act("toggle");
        else if (context.action === "pause")
            live.pause();
        else if (context.action === "resume")
            live.resume();
        else if (context.action === "done") {
            if (context.timerId && live.chooseTimer)
                live.chooseTimer(context.timerId);
            live.cancel();
        } else {
            page = context.page;
            expandRequested();
        }
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
    readonly property real expandedWidth: Math.max(preferredWidth, stripMode ? stripLength : 0)
    readonly property real expandedHeight: Style.space(settingsOpen ? 468 : page === "music" ? (hasPlayer ? 310 : 212) : 430) + (stripMode && !settingsOpen ? Style.space(38) : 0)
    readonly property real maximumHeight: Style.space(468)
    implicitWidth: expanded ? expandedWidth : compactWidth
    implicitHeight: expanded ? expandedHeight : compactHeight
    signal preferenceChanged(string key, var value)
    signal edgeRequested(string value)
    signal expandRequested
    signal collapseRequested
    signal settingsChanged(bool hideIdle, bool reducedMotion, bool edgeAttached)
    onSettingsOpenChanged: enterPage(settingsOpen)
    onExpandedChanged: {
        if (!expanded) {
            settingsOpen = false;
            popupOpen = false;
        } else if (page === "music" && !stripMode)
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
    FileDialog {
        id: lyricsPicker
        onVisibleChanged: root.interactionActive = visible
        nameFilters: ["Lyrics (*.lrc *.txt)"]
        onAccepted: if (root.media && root.media.loadLyrics)
            root.media.loadLyrics(String(selectedFile))
    }
    clip: true

    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onEntered: function (drag) {
            if (drag.hasUrls) {
                root.page = "shelf";
                root.expandRequested();
            }
        }
        onDropped: function (drop) {
            if (drop.hasUrls) {
                root.dropReceived(drop.urls.map(function (u) {
                    return String(u);
                }));
                drop.acceptProposedAction();
            }
        }
    }
    // Swipes operate only on the header; sliders and file dragging keep their own gestures.
    MouseArea {
        z: 10
        x: Style.space(18)
        y: Style.space(4)
        width: parent.width - Style.space(160)
        height: Style.space(34)
        enabled: root.expanded
        property real startX: 0
        onPressed: mouse => {
            startX = mouse.x;
            root.interactionActive = true;
        }
        onReleased: mouse => {
            root.interactionActive = false;
            if (Math.abs(mouse.x - startX) > 35) {
                var pages = root.stripMode ? root.moduleItems : ["music", "timer", "system", "activity", "shelf", "calendar", "inbox", "desktop", "clipboard", "stats", "weather"];
                var i = pages.indexOf(root.page);
                root.page = pages[(i + (mouse.x < startX ? 1 : pages.length - 1) + pages.length) % pages.length];
            }
        }
        onCanceled: root.interactionActive = false
    }
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
        visible: !root.expanded && !root.stripMode
        ParallelAnimation {
            id: compactEnter
            NumberAnimation {
                target: compactRow
                property: "opacity"
                from: 0
                to: 1
                duration: root.reducedMotion ? 0 : 140
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: compactSlide
                property: "y"
                from: Style.space(4)
                to: 0
                duration: root.reducedMotion ? 0 : 140
                easing.type: Easing.OutCubic
            }
        }
        Row {
            id: compactRow
            visible: !root.sideTab
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.space(12)
            spacing: Style.space(10)
            transform: Translate {
                id: compactSlide
            }
            Item {
                width: Style.space(16)
                height: width
                anchors.verticalCenter: parent.verticalCenter
                PerchIcon {
                    anchors.fill: parent
                    visible: !root.compactArt
                    name: root.compactIcon
                    ink: root.ink
                }
                Rectangle {
                    anchors.fill: parent
                    visible: root.compactArt
                    radius: Style.space(4)
                    color: Qt.alpha(root.ink, 0.1)
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: root.compactArt ? root.media.art : ""
                        sourceSize.width: 64
                        sourceSize.height: 64
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(root.busy ? (root.context.id === "system" ? 100 : 138) : 40)
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
        PerchAction {
            z: 2
            visible: root.busy && !root.sideTab
            anchors.right: parent.right
            anchors.rightMargin: Style.space(5)
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Style.space(28)
            implicitHeight: Style.space(24)
            text: root.context.action === "toggle" ? (root.playing ? "Ⅱ" : "▶") : root.context.action === "pause" ? "Ⅱ" : root.context.action === "resume" ? "▶" : root.context.action === "done" ? "✓" : "›"
            Accessible.name: root.context.action + " " + root.context.title
            ink: root.ink
            surface: root.surface
            onClicked: root.compactAction()
        }
        MouseArea {
            anchors.fill: parent
            onWheel: wheel => {
                if (root.contexts.length > 1) {
                    root.contextIndex = (root.contextIndex + (wheel.angleDelta.y < 0 ? 1 : root.contexts.length - 1)) % root.contexts.length;
                    wheel.accepted = true;
                }
            }
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: function (mouse) {
                if (mouse.button === Qt.MiddleButton && root.hasPlayer)
                    root.media.act("toggle");
                else {
                    root.revealPage();
                    root.expandRequested();
                }
            }
            Accessible.role: Accessible.Button
            Accessible.name: "Open Perch"
            Accessible.onPressAction: root.expandRequested()
        }
    }
    ModuleStrip {
        anchors.fill: parent
        visible: root.stripMode && !root.expanded
        items: root.moduleItems
        registry: moduleRegistry
        vertical: root.stripVertical
        hoverOpen: root.hoverOpen
        ink: root.ink
        surface: root.surface
        onActivated: (id, pointer) => root.activateModule(id, pointer)
        onReordered: order => root.preferenceChanged("modules", order)
        onInteractionChanged: active => root.interactionActive = active
    }
    Rectangle {
        visible: !root.expanded && !root.stripMode && !!root.live && root.live.timerActive
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
                objectName: "open-inbox"
                glyph: "bell"
                label: "Notifications"
                ink: root.ink
                surface: root.surface
                onClicked: {
                    root.settingsOpen = false;
                    root.page = "inbox";
                }
            }
            NotchButton {
                objectName: "open-desktop"
                glyph: "desktop"
                label: "Files, calendar, desktop and setup"
                ink: root.ink
                surface: root.surface
                onClicked: {
                    root.settingsOpen = false;
                    root.page = "hub";
                }
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
            visible: !root.settingsOpen && !root.stripMode
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
        ModuleStrip {
            visible: root.stripMode && !root.settingsOpen
            x: Style.space(4)
            y: Style.space(45)
            width: parent.width - Style.space(8)
            height: Style.space(60)
            slot: (width - Style.space(8)) / root.moduleItems.length
            items: root.moduleItems
            registry: moduleRegistry
            selectedId: root.page
            ink: root.ink
            surface: root.surface
            hoverOpen: root.hoverOpen
            onActivated: (id, pointer) => root.activateModule(id, pointer)
            onReordered: order => root.preferenceChanged("modules", order)
            onInteractionChanged: active => root.interactionActive = active
        }
        Item {
            id: pages
            anchors.fill: parent
            transform: Translate {
                id: pageSlide
            }
            ParallelAnimation {
                id: pageEnter
                NumberAnimation {
                    target: pages
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: root.reducedMotion ? 0 : 140
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: pageSlide
                    property: "x"
                    to: 0
                    duration: root.reducedMotion ? 0 : 140
                    easing.type: Easing.OutCubic
                }
            }
            ModuleCard {
                objectName: "module-card"
                visible: !root.settingsOpen && ["clipboard", "stats", "weather"].indexOf(root.page) >= 0
                x: Style.space(18)
                y: root.bodyTop
                width: parent.width - Style.space(36)
                height: parent.height - root.bodyTop - Style.space(16)
                definition: visible ? moduleRegistry.get(root.page) : null
                ink: root.ink
                surface: root.surface
                onActionRequested: id => moduleRegistry.action(root.page, id)
            }
            GridLayout {
                visible: !root.settingsOpen && root.page === "hub"
                x: Style.space(18)
                y: root.bodyTop
                width: parent.width - Style.space(36)
                columns: 2
                rowSpacing: Style.space(10)
                columnSpacing: Style.space(10)
                Repeater {
                    model: [
                        {
                            id: "clipboard",
                            label: "Clipboard"
                        },
                        {
                            id: "stats",
                            label: "System stats"
                        },
                        {
                            id: "weather",
                            label: "Weather"
                        },
                        {
                            id: "shelf",
                            label: "File shelf"
                        },
                        {
                            id: "calendar",
                            label: "Calendar"
                        },
                        {
                            id: "desktop",
                            label: "Desktop"
                        },
                        {
                            id: "inbox",
                            label: "Notifications"
                        },
                        {
                            id: "setup",
                            label: "Setup & health"
                        },
                        {
                            id: "activity",
                            label: "Live activities"
                        }
                    ]
                    delegate: PerchAction {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: Style.space(54)
                        text: modelData.label
                        ink: root.ink
                        surface: root.surface
                        onClicked: root.page = modelData.id
                    }
                }
            }
            ShelfView {
                onInteractionChanged: active => root.interactionActive = active
                visible: !root.settingsOpen && root.page === "shelf"
                x: Style.space(18)
                y: root.bodyTop
                width: parent.width - Style.space(36)
                height: parent.height - root.bodyTop - Style.space(48)
                work: root.work
                ink: root.ink
                surface: root.surface
            }
            CalendarView {
                onInteractionChanged: active => root.interactionActive = active
                visible: !root.settingsOpen && root.page === "calendar"
                x: Style.space(18)
                y: root.bodyTop
                width: parent.width - Style.space(36)
                height: parent.height - root.bodyTop - Style.space(48)
                work: root.work
                ink: root.ink
                surface: root.surface
            }
            SetupView {
                visible: !root.settingsOpen && root.page === "setup"
                x: Style.space(18)
                y: root.bodyTop
                width: parent.width - Style.space(36)
                height: parent.height - root.bodyTop - Style.space(48)
                work: root.work
                ink: root.ink
                surface: root.surface
            }
            Text {
                x: Style.space(18)
                y: parent.height - Style.space(38)
                width: parent.width - Style.space(36)
                visible: !root.settingsOpen && ["shelf", "calendar", "setup"].indexOf(root.page) >= 0
                text: root.work ? (root.work.busy ? "Working…" : root.work.error || root.work.message) : "Demo: integration unavailable"
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Qt.alpha(root.ink, 0.6)
                font.pixelSize: Style.space(10)
            }
            InboxView {
                onPopupToggled: open => root.popupOpen = open
                visible: !root.settingsOpen && root.page === "inbox"
                x: Style.space(18)
                y: root.bodyTop
                width: parent.width - Style.space(36)
                height: parent.height - root.bodyTop - Style.space(16)
                inbox: root.inbox
                ink: root.ink
                surface: root.surface
            }
            Controls.ScrollView {
                visible: !root.settingsOpen && root.page === "lyrics"
                x: Style.space(18)
                y: root.bodyTop
                width: parent.width - Style.space(36)
                height: parent.height - root.bodyTop - Style.space(16)
                clip: true
                contentWidth: availableWidth
                Text {
                    width: parent.width
                    text: root.media && root.media.plainLyrics ? root.media.plainLyrics : root.media && root.media.lyrics ? root.media.lyrics.map(function (l) {
                        return l.text;
                    }).join("\n") : "Choose a lyrics file from the music page."
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    color: root.ink
                    font.pixelSize: Style.space(13)
                }
            }
            DesktopView {
                onPopupToggled: open => root.popupOpen = open
                height: parent.height - root.bodyTop - Style.space(16)
                visible: !root.settingsOpen && root.page === "desktop"
                x: Style.space(18)
                y: root.bodyTop
                width: parent.width - Style.space(36)
                work: root.work
                desktop: root.desktop
                ink: root.ink
                surface: root.surface
                onLaunched: root.collapseRequested()
            }
            TimerView {
                onPopupToggled: open => root.popupOpen = open
                visible: !root.settingsOpen && root.page === "timer"
                x: Style.space(18)
                y: root.bodyTop
                width: parent.width - Style.space(36)
                height: parent.height - root.bodyTop - Style.space(16)
                live: root.live
                ink: root.ink
                surface: root.surface
            }
            SystemView {
                onPopupToggled: open => root.popupOpen = open
                visible: !root.settingsOpen && root.page === "system"
                x: Style.space(18)
                y: root.bodyTop
                width: parent.width - Style.space(36)
                height: parent.height - root.bodyTop - Style.space(16)
                work: root.work
                system: root.system
                ink: root.ink
                surface: root.surface
            }
            ActivityView {
                visible: !root.settingsOpen && root.page === "activity"
                x: Style.space(18)
                y: root.bodyTop
                width: parent.width - Style.space(36)
                live: root.live
                ink: root.ink
                surface: root.surface
            }
            PlayersView {
                visible: !root.settingsOpen && root.page === "players"
                x: Style.space(18)
                y: root.bodyTop
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
                    topMargin: root.bodyTop
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
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: root.media && root.media.lyricLine !== undefined ? root.media.lyricLine : ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Qt.alpha(root.ink, 0.65)
                        font.pixelSize: Style.space(11)
                    }
                    RowLayout {
                        PerchAction {
                            text: "Load lyrics"
                            ink: root.ink
                            surface: root.surface
                            enabled: root.hasPlayer && !root.demo
                            onClicked: lyricsPicker.open()
                        }
                        PerchAction {
                            text: "Read lyrics"
                            ink: root.ink
                            surface: root.surface
                            enabled: !!root.media && !!root.media.lyrics && root.media.lyrics.length > 0
                            onClicked: root.page = "lyrics"
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.media && root.media.mediaError !== undefined ? root.media.mediaError : ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Qt.alpha(root.ink, 0.5)
                    font.pixelSize: Style.space(10)
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
            Controls.ScrollView {
                visible: root.settingsOpen
                x: Style.space(18)
                y: Style.space(54)
                width: parent.width - Style.space(36)
                height: parent.height - Style.space(70)
                clip: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: Style.space(14)
                    Text {
                        text: "Display"
                        color: root.ink
                        font.pixelSize: Style.space(12)
                    }
                    PerchCombo {
                        objectName: "monitor-choice"
                        ink: root.ink
                        surface: root.surface
                        onPopupToggled: open => root.popupOpen = open
                        Layout.fillWidth: true
                        model: ["Follow focused display"].concat(root.displayNames)
                        currentIndex: Math.max(0, root.displayNames.indexOf(root.displaySettings.monitor || "") + 1)
                        onActivated: index => root.preferenceChanged("monitor", index === 0 ? "" : root.displayNames[index - 1])
                    }
                    Controls.CheckBox {
                        Layout.fillWidth: true
                        text: "Save placement separately for each display"
                        checked: root.displaySettings.perDisplay === true
                        palette.windowText: root.ink
                        onToggled: root.preferenceChanged("perDisplay", checked)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Panel width"
                            color: root.ink
                            font.pixelSize: Style.space(11)
                        }
                        Controls.SpinBox {
                            from: 304
                            to: 544
                            stepSize: 40
                            value: root.displaySettings.panelWidth || 344
                            palette.text: root.ink
                            palette.buttonText: root.ink
                            palette.base: root.surface
                            palette.button: root.surface
                            onValueModified: root.preferenceChanged("panelWidth", value)
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Extra edge spacing"
                            color: root.ink
                            font.pixelSize: Style.space(11)
                        }
                        Controls.SpinBox {
                            from: 0
                            to: 64
                            stepSize: 4
                            value: root.displaySettings.edgeOffset || 0
                            palette.text: root.ink
                            palette.buttonText: root.ink
                            palette.base: root.surface
                            palette.button: root.surface
                            onValueModified: root.preferenceChanged("edgeOffset", value)
                        }
                    }
                    Text {
                        text: "During fullscreen"
                        color: root.ink
                        font.pixelSize: Style.space(11)
                    }
                    PerchCombo {
                        ink: root.ink
                        surface: root.surface
                        onPopupToggled: open => root.popupOpen = open
                        Layout.fillWidth: true
                        model: ["Hide Perch", "Show completed timers only", "Keep Perch visible"]
                        currentIndex: Math.max(0, ["hide", "alerts", "show"].indexOf(root.displaySettings.fullscreenPolicy || "hide"))
                        onActivated: index => root.preferenceChanged("fullscreenPolicy", ["hide", "alerts", "show"][index])
                    }
                    Controls.CheckBox {
                        Layout.fillWidth: true
                        text: "Timer completion sound"
                        checked: root.displaySettings.timerSound === true
                        palette.windowText: root.ink
                        onToggled: root.preferenceChanged("timerSound", checked)
                    }
                    Controls.CheckBox {
                        Layout.fillWidth: true
                        text: "Timer desktop notifications"
                        checked: root.displaySettings.timerNotifications === true
                        palette.windowText: root.ink
                        onToggled: root.preferenceChanged("timerNotifications", checked)
                    }
                    Controls.CheckBox {
                        Layout.fillWidth: true
                        text: "Fetch remote cover artwork"
                        checked: root.displaySettings.remoteArtwork === true
                        palette.windowText: root.ink
                        onToggled: root.preferenceChanged("remoteArtwork", checked)
                    }
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
                        text: "Compact layout"
                        color: root.ink
                        font.pixelSize: Style.space(13)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        PerchAction {
                            text: "Context pill"
                            selected: !root.stripMode
                            ink: root.ink
                            surface: root.surface
                            onClicked: root.preferenceChanged("layoutMode", "pill")
                        }
                        PerchAction {
                            text: "Module strip"
                            selected: root.stripMode
                            ink: root.ink
                            surface: root.surface
                            onClicked: root.preferenceChanged("layoutMode", "strip")
                        }
                    }
                    ModuleSettings {
                        Layout.fillWidth: true
                        items: root.moduleItems
                        ink: root.ink
                        surface: root.surface
                        onChanged: order => root.preferenceChanged("modules", order)
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
    }
}
