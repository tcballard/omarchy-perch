import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import qs.Commons
import "MediaPolicy.js" as Policy
import "EdgePolicy.js" as Edges
import "ModulePolicy.js" as Modules

FocusScope {
    id: root
    property var media: null
    readonly property var pluginState: media && media.pluginPins !== undefined ? media.pluginPins : null
    signal pluginLaunchRequested(string id)
    property bool surfaceVisible: true
    readonly property var moduleState: media && media.modules !== undefined ? media.modules : null
    readonly property var moduleItems: Modules.clean(displaySettings.modules)
    readonly property bool stripVertical: Edges.vertical(edge)
    readonly property real stripLength: Style.space(46 * moduleItems.length + 8)
    readonly property real compactWidth: stripVertical ? Style.space(52) : stripLength
    readonly property real compactHeight: stripVertical ? stripLength : Style.space(52)
    readonly property real bodyTop: Style.space(116)
    function activateModule(id, pointer) {
        var descriptor = Modules.get(id);
        if (!descriptor)
            return;
        if (descriptor.pluginId) {
            if (pointer)
                return;
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
    Binding {
        target: root.moduleState
        property: "statsVisible"
        when: !!root.moduleState
        value: root.surfaceVisible && (!root.settingsOpen && root.moduleItems.indexOf("stats") >= 0 || root.expanded && !root.settingsOpen && root.page === "stats")
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
        value: root.surfaceVisible && (!root.settingsOpen && root.moduleItems.indexOf("weather") >= 0 || root.expanded && !root.settingsOpen && root.page === "weather")
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
    readonly property real expandedWidth: Math.max(preferredWidth, stripLength)
    readonly property real expandedHeight: Style.space(468)
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
        if (!expanded) {
            settingsOpen = false;
            popupOpen = false;
        }
    }
    Keys.onEscapePressed: {
        if (settingsOpen)
            settingsOpen = false;
        else if (page !== "music")
            page = "music";
        else
            collapseRequested();
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
        enabled: root.expanded
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
    ModuleStrip {
        anchors.fill: parent
        visible: !root.expanded
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
        ModuleStrip {
            visible: !root.settingsOpen
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
                objectName: "module-card"
                visible: !root.settingsOpen
                x: Style.space(18)
                y: root.bodyTop
                width: parent.width - Style.space(36)
                height: parent.height - root.bodyTop - Style.space(16)
                definition: visible ? moduleRegistry.get(root.page) : null
                ink: root.ink
                surface: root.surface
                onActionRequested: id => moduleRegistry.action(root.page, id)
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
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.pluginState ? (root.pluginState.error || (root.pluginState.busy ? "Checking plugins…" : root.pluginState.message)) : ""
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        color: root.ink
                        font.pixelSize: Style.space(11)
                    }
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
                        model: ["Reduce motion", "Attach flush to screen edge", "Open on hover", "Volume and power banners"]
                        delegate: Controls.CheckBox {
                            required property int index
                            required property string modelData
                            Layout.fillWidth: true
                            implicitHeight: Style.space(30)
                            text: modelData
                            checked: index === 0 ? root.reducedMotion : index === 1 ? root.edgeAttached : index === 2 ? root.hoverOpen : root.eventBanners
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
                            onToggled: root.preferenceChanged(["reducedMotion", "edgeAttached", "hoverOpen", "eventBanners"][index], checked)
                        }
                    }
                    ModuleSettings {
                        pluginState: root.pluginState
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
