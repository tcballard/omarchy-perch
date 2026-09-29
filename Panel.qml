import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "MediaPolicy.js" as Policy
import "EdgePolicy.js" as Edges
import "PreferencesPolicy.js" as Prefs
import "ModulePolicy.js" as Modules

Item {
    id: root
    property string omarchyPath: ""
    property var shell: null
    property var manifest: null
    property var service: null
    property bool opened: false
    property bool expanded: false
    property bool keyboardMode: false
    property bool focusPrimed: false
    property bool hideIdle: false
    property bool reducedMotion: false
    property bool edgeAttached: false
    property string edge: "top"
    property string monitorName: ""
    property real panelWidth: 344
    property real edgeOffset: 0
    property string fullscreenPolicy: "hide"
    property bool perDisplay: false
    property bool edgeRemapping: false
    readonly property real edgeInset: Edges.inset(edge, edgeAttached, shell && shell.bar ? shell.bar.position : "top", shell && shell.bar ? shell.bar.barHidden : false, shell && shell.bar ? shell.bar.barSize : Style.bar.sizeHorizontal, Style.space(8)) + Style.space(edgeOffset)
    property bool showClock: true
    property bool hoverOpen: true
    property bool eventBanners: true
    function applyPreferences() {
        if (!service || !service.preferences.ready)
            return;
        var p = service.preferences.values;
        monitorName = p.monitor;
        if (monitorName) {
            var pinned = screens.find(function (s) {
                return s.name === root.monitorName;
            });
            if (pinned)
                targetScreen = pinned;
        }
        perDisplay = p.perDisplay;
        var profiles = service.preferences.record.displayProfiles || {};
        var own = effectiveScreen && profiles[effectiveScreen.name];
        if (perDisplay && own) {
            p = Prefs.clean(Object.assign({}, p, own));
        }
        panelWidth = p.panelWidth;
        edgeOffset = p.edgeOffset;
        fullscreenPolicy = p.fullscreenPolicy;
        view.displaySettings = Object.assign({}, service.preferences.values, p);
        if (edge !== p.edge)
            setEdge(p.edge, false);
        hideIdle = p.hideIdle;
        reducedMotion = p.reducedMotion;
        edgeAttached = p.edgeAttached;
        showClock = p.showClock;
        hoverOpen = p.hoverOpen;
        eventBanners = p.eventBanners;
    }
    function savePreference(key, value) {
        if (!service)
            return false;
        var patch = {};
        if (perDisplay && effectiveScreen && ["edge", "panelWidth", "edgeOffset", "fullscreenPolicy"].indexOf(key) >= 0) {
            var profiles = Object.assign({}, service.preferences.record.displayProfiles || {});
            var profile = Object.assign({}, profiles[effectiveScreen.name] || {});
            profile[key] = value;
            profiles[effectiveScreen.name] = profile;
            patch.displayProfiles = profiles;
        } else
            patch[key] = value;
        if (!service.preferences.update(patch))
            return false;
        applyPreferences();
        return true;
    }
    onServiceChanged: applyPreferences()
    Connections {
        target: root.service ? root.service.preferences : null
        function onLoaded() {
            root.applyPreferences();
        }
    }
    property bool demo: false
    property var targetScreen: null
    readonly property var media: demo ? fixture : service
    readonly property var screens: Quickshell.screens
    readonly property var effectiveScreen: targetScreen && screens.indexOf(targetScreen) !== -1 ? targetScreen : screens.length ? screens[0] : null
    readonly property var monitor: effectiveScreen ? Hyprland.monitorFor(effectiveScreen) : null
    readonly property bool fullscreen: !!(monitor && monitor.activeWorkspace && monitor.activeWorkspace.hasFullscreen)
    readonly property bool shown: effectiveScreen !== null && (!fullscreen || fullscreenPolicy === "show" || fullscreenPolicy === "alerts" && media && media.live.timers && media.live.timers.some(function (t) {
            return t.status === "done";
        }))
    // Compact surface is present on startup; expanded state is host-managed.
    function open(encoded) {
        var p = Policy.payload(encoded || "{}");
        var focused = Hyprland.focusedMonitor;
        for (var i = 0; p.pointer !== true && !monitorName && focused && i < screens.length; i++) {
            if (screens[i].name === focused.name) {
                targetScreen = screens[i];
                break;
            }
        }
        if (fullscreen && fullscreenPolicy !== "show") {
            collapse();
            return;
        }
        demo = p.demo === true;
        fixture.setState(p.state);
        keyboardMode = p.pointer !== true;
        opened = true;
        expanded = true;
        if (["music", "timer", "system", "activity", "players", "inbox", "desktop", "hub", "shelf", "calendar", "setup", "clipboard", "stats", "weather"].indexOf(p.page) >= 0)
            view.page = p.page;
        focusPrimed = false;
        if (keyboardMode)
            focusPrimeTimer.restart();
        if (keyboardMode)
            Qt.callLater(function () {
                view.forceActiveFocus();
            });
    }
    function setEdge(value, persist) {
        var next = Edges.edge(value);
        if (persist !== false && service) {
            savePreference("edge", next);
            return;
        }
        if (next === edge)
            return;
        leaveTimer.stop();
        focusPrimeTimer.stop();
        edgeRemapping = true;
        focusPrimed = false;
        edge = next;
        edgeRemapTimer.restart();
    }
    function close() {
        opened = false;
        expanded = false;
        keyboardMode = false;
        demo = false;
        leaveTimer.stop();
        focusPrimeTimer.stop();
        focusPrimed = false;
    }
    function collapse() {
        close();
        if (shell)
            shell.hide("io.github.tcballard.perch");
    }
    function toggle() {
        if (expanded)
            collapse();
        else
            reveal(false);
    }
    function reveal(pointer) {
        var payload = JSON.stringify({
            pointer: pointer,
            demo: demo
        });
        if (shell)
            shell.summon("io.github.tcballard.perch", payload);
        else
            open(payload);
    }
    onFullscreenChanged: if (fullscreen && fullscreenPolicy !== "show")
        collapse()
    onEffectiveScreenChanged: {
        if (expanded)
            collapse();
        if (service && service.preferences.ready)
            Qt.callLater(root.applyPreferences);
    }
    // Hyprland: bind = SUPER, P, global, perch:toggle
    GlobalShortcut {
        appid: "perch"
        name: "toggle"
        description: "Open or close Perch"
        onPressed: root.toggle()
    }
    HyprlandFocusGrab {
        active: root.shown && root.expanded && root.keyboardMode && root.focusPrimed && !view.interactionActive
        windows: [notchWindow]
        onCleared: if (!root.edgeRemapping && !remapGuard.remapping && !view.interactionActive)
            root.collapse()
    }
    Timer {
        id: focusPrimeTimer
        interval: 75
        onTriggered: if (root.expanded)
            root.focusPrimed = true
    }
    Timer {
        id: edgeRemapTimer
        interval: 75
        onTriggered: {
            root.edgeRemapping = false;
            if (root.expanded && root.keyboardMode)
                focusPrimeTimer.restart();
        }
    }
    DemoMedia {
        id: fixture
    }
    Timer {
        id: leaveTimer
        interval: 220
        onTriggered: if (!root.edgeRemapping && !root.keyboardMode && !hover.hovered && !view.interactionActive && !view.popupOpen)
            root.collapse()
    }
    // Dropdown popups sit outside the masked item; a closed popup with the
    // pointer already outside must still start the leave grace.
    Connections {
        target: view
        function onPopupOpenChanged() {
            if (!view.popupOpen && !hover.hovered && root.expanded && !root.keyboardMode)
                leaveTimer.restart();
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.shown && root.expanded && view.page === "music" && !view.settingsOpen && !root.demo && root.service && root.service.player && root.service.player.isPlaying && root.service.timeline
        onTriggered: if (root.service && root.service.player)
            root.service.player.positionChanged()
    }
    PanelWindow {
        id: notchWindow
        screen: root.effectiveScreen
        visible: root.shown && !remapGuard.remapping && !root.edgeRemapping
        ScreenMoveRemap {
            id: remapGuard
            window: notchWindow
        }
        anchors {
            top: root.edge === "top"
            bottom: root.edge === "bottom"
            left: root.edge === "left"
            right: root.edge === "right"
        }
        margins {
            top: root.edge === "top" ? root.edgeInset : 0
            bottom: root.edge === "bottom" ? root.edgeInset : 0
            left: root.edge === "left" ? root.edgeInset : 0
            right: root.edge === "right" ? root.edgeInset : 0
        }
        // Fixed compositor surface: animate only the masked item inside it.
        implicitWidth: Math.min(view.expandedWidth, root.effectiveScreen ? root.effectiveScreen.width - Style.space(24) : view.expandedWidth)
        implicitHeight: Math.min(Math.max(view.maximumHeight, view.compactHeight), root.effectiveScreen ? root.effectiveScreen.height - Style.space(24) : view.maximumHeight)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "io-github-tcballard-perch"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: root.shown && root.expanded ? (root.keyboardMode && !root.focusPrimed ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand) : WlrKeyboardFocus.None
        mask: Region {
            item: view
            Region {
                item: view.popupOpen ? view.overlayItem : null
            }
        }
        NotchView {
            id: view
            width: Math.min(implicitWidth, notchWindow.width)
            height: Math.min(implicitHeight, notchWindow.height)
            surfaceVisible: root.shown
            x: root.edge === "left" ? 0 : root.edge === "right" ? notchWindow.width - width : (notchWindow.width - width) / 2
            y: root.edge === "bottom" ? notchWindow.height - height : Edges.vertical(root.edge) ? (notchWindow.height - height) / 2 : 0
            Behavior on width {
                NumberAnimation {
                    duration: root.reducedMotion ? 0 : 140
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: root.reducedMotion ? 0 : 140
                    easing.type: Easing.OutCubic
                }
            }
            HoverHandler {
                id: hover
                onHoveredChanged: {
                    if (hovered) {
                        leaveTimer.stop();
                    } else {
                        if (!root.keyboardMode && !root.edgeRemapping)
                            leaveTimer.restart();
                    }
                }
            }
            onDropReceived: urls => {
                if (!root.demo && root.service)
                    root.service.workspace.addFiles(urls);
                view.page = "shelf";
            }
            displayNames: root.screens.map(function (s) {
                return s.name;
            })
            preferredWidth: Math.min(Style.space(root.panelWidth), root.effectiveScreen ? root.effectiveScreen.width - Style.space(24) : Style.space(root.panelWidth))
            media: root.media
            expanded: root.expanded
            reducedMotion: root.reducedMotion
            showClock: root.showClock
            hoverOpen: root.hoverOpen
            eventBanners: root.eventBanners
            settingsError: root.service ? root.service.preferences.error : "Settings service loading"
            onPreferenceChanged: function (key, value) {
                root.savePreference(key, value);
            }
            hideIdle: root.hideIdle
            edgeAttached: root.edgeAttached
            edge: root.edge
            onEdgeRequested: function (value) {
                root.setEdge(value);
            }
            demo: root.demo
            onExpandRequested: root.reveal(true)
            onCollapseRequested: root.collapse()
            onSettingsChanged: function (hideIdle, reducedMotion, edgeAttached) {
                if (root.service && root.service.preferences.update({
                    hideIdle: hideIdle,
                    reducedMotion: reducedMotion,
                    edgeAttached: edgeAttached
                }))
                    root.applyPreferences();
            }
        }
    }
}
