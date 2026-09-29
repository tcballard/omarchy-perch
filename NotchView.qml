import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import qs.Commons
import "MediaPolicy.js" as Policy
import "EdgePolicy.js" as Edges
import "ModulePolicy.js" as Modules
import "NotchPolicy.js" as NotchPolicy

FocusScope {
    id: root
    property var media: null
    readonly property var pluginState: media && media.pluginPins !== undefined ? media.pluginPins : null
    readonly property var cardState: media && media.pluginCards !== undefined ? media.pluginCards : null
    signal pluginLaunchRequested(string id)
    property bool surfaceVisible: true
    readonly property var moduleState: media && media.modules !== undefined ? media.modules : null
    readonly property var moduleItems: Modules.clean(displaySettings.modules)
    readonly property bool stripVertical: Edges.vertical(edge)
    readonly property real stripLength: Style.space(46 * moduleItems.length + 8)
    readonly property bool perchMode: displaySettings.layoutMode === "strip"
    readonly property var notchContext: NotchPolicy.context(media, displaySettings)
    readonly property real compactWidth: perchMode ? (stripVertical ? Style.space(52) : stripLength) : Style.space(stripVertical ? 48 : notchContext.id === "idle" ? 100 : 210)
    readonly property real compactHeight: perchMode ? (stripVertical ? stripLength : Style.space(52)) : Style.space(stripVertical ? 76 : 36)
    readonly property real bodyTop: Style.space(page === "event" ? 58 : 116)
    property string eventId: ""
    readonly property var selectedEvent: live && eventId ? live.items.find(function (item) {
        return item.id === root.eventId && item.state !== "running";
    }) || null : null
    signal eventEnded
    onSelectedEventChanged: if (page === "event" && expanded && !selectedEvent)
        eventEnded()
    function activateModule(id, pointer) {
        var descriptor = Modules.get(id);
        if (!descriptor)
            return;
        if (descriptor.pluginId) {
            if (pointer)
                return;
            if (cardState) {
                settingsOpen = false;
                page = id;
                cardState.select(descriptor.pluginId);
                if (!expanded)
                    expandRequested();
                return;
            }
            settingsView.section = "plugins";
            settingsOpen = true;
            if (!expanded)
                expandRequested();
            pluginLaunchRequested(descriptor.pluginId);
            return;
        }
        settingsOpen = false;
        page = descriptor.page;
        if (!expanded)
            expandRequested();
    }
    ModuleRegistry {
        id: moduleRegistry
        state: root.moduleState
        host: root
    }
    PerchModule {
        id: pluginCardDefinition
        moduleId: root.page
        title: root.cardState && root.cardState.card ? root.cardState.card.title : root.pluginState && root.pluginState.get(Modules.pluginId(root.page)) ? root.pluginState.get(Modules.pluginId(root.page)).name : "Plugin drawer"
        actions: [
            {
                id: "refresh",
                title: "Refresh",
                enabled: !!root.cardState && !root.cardState.busy
            },
            {
                id: "open",
                title: "Open",
                enabled: !root.cardState || !root.cardState.busy
            }
        ]
        card: Component {
            PluginDrawerCard {
                state: root.cardState
            }
        }
    }
    PerchModule {
        id: eventDefinition
        moduleId: "event"
        title: !root.selectedEvent ? "Activity" : root.selectedEvent.state === "done" ? "Complete" : root.selectedEvent.state === "error" ? "Something needs attention" : root.selectedEvent.attention === "approval" ? "Permission needed" : root.selectedEvent.attention === "question" ? "Input needed" : "Needs your attention"
        card: Component {
            Item {
                property color ink
                property color surface
                implicitHeight: eventBody.implicitHeight
                Controls.ScrollView {
                    anchors.fill: parent
                    clip: true
                    contentWidth: availableWidth
                    ActivityEventCard {
                        id: eventBody
                        width: parent.width
                        item: root.selectedEvent
                        live: root.live
                        ink: root.ink
                        surface: root.surface
                        onBrowseRequested: root.page = "activity"
                        onDismissRequested: root.collapseRequested()
                    }
                }
            }
        }
    }
    Binding {
        target: root.moduleState
        property: "statsVisible"
        when: !!root.moduleState
        value: root.surfaceVisible && ((root.perchMode || root.expanded) && !root.settingsOpen && root.moduleItems.indexOf("stats") >= 0 || root.expanded && !root.settingsOpen && root.page === "stats")
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
        value: root.surfaceVisible && ((root.perchMode || root.expanded) && !root.settingsOpen && root.moduleItems.indexOf("weather") >= 0 || root.expanded && !root.settingsOpen && root.page === "weather")
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
    readonly property string notificationPreview: inbox && !inbox.dnd && !displaySettings.quietMode && displaySettings.notificationPreviews !== false ? inbox.preview : ""
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
        if (!Modules.pluginId(page) && cardState)
            cardState.clear();
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
    property bool expanded: false
    property bool reducedMotion: false
    onReducedMotionChanged: if (reducedMotion) {
        pageEnter.stop();
        pages.opacity = 1;
        pageSlide.x = 0;
    }
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
    readonly property color surface: displaySettings.chromeMode === "theme" ? Color.background : lightTheme ? Color.foreground : Color.background
    readonly property color ink: displaySettings.chromeMode === "theme" ? Color.foreground : lightTheme ? Color.background : Color.foreground
    readonly property real maximumWidth: Math.max(preferredWidth, stripLength, Style.space(600))
    readonly property real expandedWidth: settingsOpen ? maximumWidth : Math.max(preferredWidth, stripLength)
    readonly property real expandedHeight: settingsOpen ? maximumHeight : Math.min(maximumHeight, Math.max(Style.space(220), bodyTop + Style.space(16) + displayedCard.contentHeight))
    readonly property real maximumHeight: Style.space(468)
    implicitWidth: expanded ? expandedWidth : compactWidth
    implicitHeight: expanded ? expandedHeight : compactHeight
    signal preferenceChanged(string key, var value)
    signal edgeRequested(string value)
    signal expandRequested
    signal collapseRequested
    signal settingsChanged(bool hideIdle, bool reducedMotion, bool edgeAttached)
    onSettingsOpenChanged: {
        enterPage(settingsOpen);
    }
    onExpandedChanged: {
        if (expanded && cardState && Modules.pluginId(page) && cardState.selectedId !== Modules.pluginId(page))
            cardState.select(Modules.pluginId(page));
        if (!expanded) {
            if (cardState)
                cardState.clear();
            settingsOpen = false;
            popupOpen = false;
        }
    }
    onSurfaceVisibleChanged: if (!surfaceVisible && cardState)
        cardState.clear()
    Connections {
        target: root.live
        function onSessionOpened() {
            root.collapseRequested();
        }
    }
    Keys.onEscapePressed: {
        if (settingsOpen)
            settingsOpen = false;
        else if (page === "event")
            collapseRequested();
        else if (Modules.pluginId(page))
            page = "hub";
        else if (page !== "music")
            page = "music";
        else
            collapseRequested();
    }
    function showTools(focusSearch) {
        settingsOpen = false;
        page = "hub";
        if (focusSearch)
            Qt.callLater(function () {
                displayedCard.focusSearch();
            });
    }
    Keys.onPressed: event => {
        if (expanded && event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
            showTools(true);
            event.accepted = true;
        }
    }
    function openLyrics() {
        lyricsPicker.open();
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
        enabled: root.expanded && !root.settingsOpen
        property real startX: 0
        onPressed: mouse => {
            startX = mouse.x;
            root.interactionActive = true;
        }
        onReleased: mouse => {
            root.interactionActive = false;
            if (Math.abs(mouse.x - startX) > 35) {
                var pages = root.moduleItems.filter(function (id) {
                    return !Modules.pluginId(id);
                });
                if (!pages.length)
                    return;
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
    ContextNotch {
        objectName: "context-notch"
        anchors.fill: parent
        visible: !root.perchMode && !root.expanded
        context: root.notchContext
        vertical: root.stripVertical
        hoverOpen: root.hoverOpen
        ink: root.ink
        surface: root.surface
        onOpenRequested: {
            if (root.notchContext.timerId && root.live && root.live.chooseTimer)
                root.live.chooseTimer(root.notchContext.timerId);
            root.page = root.notchContext.page;
            root.expandRequested();
        }
    }
    ModuleStrip {
        anchors.fill: parent
        visible: root.perchMode && !root.expanded
        items: root.moduleItems
        registry: moduleRegistry
        pluginState: root.pluginState
        vertical: root.stripVertical
        hoverOpen: root.hoverOpen
        ink: root.ink
        surface: root.surface
        onActivated: (id, pointer) => root.activateModule(id, pointer)
        onReordered: order => root.preferenceChanged("modules", order)
        onInteractionChanged: active => root.interactionActive = active
    }
    Item {
        id: content
        width: Math.min(root.expandedWidth, root.width)
        height: Math.min(root.expandedHeight, root.height)
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
                font.pixelSize: Style.space(root.settingsOpen ? 16 : 10)
                font.bold: root.settingsOpen
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
                label: "All tools and plugins"
                ink: root.ink
                surface: root.surface
                onClicked: {
                    root.showTools(false);
                }
            }
            NotchButton {
                glyph: "settings"
                label: root.settingsOpen ? "Back to card" : "Settings"
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
        ModuleStrip {
            visible: !root.settingsOpen && root.page !== "event"
            x: Style.space(4)
            y: Style.space(45)
            width: parent.width - Style.space(8)
            height: Style.space(60)
            slot: (width - Style.space(8)) / root.moduleItems.length
            items: root.moduleItems
            registry: moduleRegistry
            pluginState: root.pluginState
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
                id: displayedCard
                objectName: "module-card"
                visible: !root.settingsOpen
                x: Style.space(18)
                y: root.bodyTop
                width: parent.width - Style.space(36)
                height: parent.height - root.bodyTop - Style.space(16)
                definition: visible ? (root.page === "event" ? eventDefinition : Modules.pluginId(root.page) ? pluginCardDefinition : moduleRegistry.get(root.page)) : null
                ink: root.ink
                surface: root.surface
                onActionRequested: function (id) {
                    if (Modules.pluginId(root.page)) {
                        if (id === "open")
                            root.pluginLaunchRequested(Modules.pluginId(root.page));
                        else if (root.cardState)
                            root.cardState.refresh();
                    } else
                        moduleRegistry.action(root.page, id);
                }
            }
            SettingsView {
                id: settingsView
                objectName: "perch-settings"
                visible: root.settingsOpen
                x: Style.space(18)
                y: Style.space(50)
                width: parent.width - Style.space(36)
                height: parent.height - Style.space(66)
                host: root
            }
        }
    }
}
