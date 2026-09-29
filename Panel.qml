import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "MediaPolicy.js" as Policy
import "EdgePolicy.js" as Edges

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
    property bool edgeRemapping: false
    readonly property real edgeInset: Edges.inset(edge, edgeAttached, shell && shell.bar ? shell.bar.position : "top", shell && shell.bar ? shell.bar.barHidden : false, shell && shell.bar ? shell.bar.barSize : Style.bar.sizeHorizontal, Style.space(8))
    property bool showClock: true
    property bool hoverOpen: true
    property bool eventBanners: true
    function applyPreferences() {
        if (!service || !service.preferences.ready)
            return;
        var p = service.preferences.values;
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
    readonly property bool shown: effectiveScreen !== null && !fullscreen && (expanded || !hideIdle || (media && (media.state !== "empty" || media.live.hasActivity || eventBanners && media.system.banner !== "")))
    // Compact surface is present on startup; expanded state is host-managed.
    function open(encoded) {
        var p = Policy.payload(encoded || "{}");
        var focused = Hyprland.focusedMonitor;
        for (var i = 0; p.pointer !== true && focused && i < screens.length; i++) {
            if (screens[i].name === focused.name) {
                targetScreen = screens[i];
                break;
            }
        }
        if (fullscreen) {
            collapse();
            return;
        }
        demo = p.demo === true;
        fixture.setState(p.state);
        keyboardMode = p.pointer !== true;
        opened = true;
        expanded = true;
        if (["music", "timer", "system", "activity", "players"].indexOf(p.page) >= 0)
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
        if (persist !== false && service && !service.preferences.update({
            edge: next
        }))
            return;
        if (next === edge)
            return;
        hoverTimer.stop();
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
        hoverTimer.stop();
        focusPrimeTimer.stop();
        focusPrimed = false;
    }
    function collapse() {
        close();
        if (shell)
            shell.hide("io.github.tcballard.perch");
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
    onFullscreenChanged: if (fullscreen)
        collapse()
    onEffectiveScreenChanged: if (expanded)
        collapse()
    HyprlandFocusGrab {
        active: root.shown && root.expanded && root.keyboardMode && root.focusPrimed
        windows: [notchWindow]
        onCleared: if (!root.edgeRemapping && !remapGuard.remapping)
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
        id: hoverTimer
        interval: 90
        onTriggered: if (root.hoverOpen && !root.expanded && hover.hovered)
            root.reveal(true)
    }
    Timer {
        id: leaveTimer
        interval: 220
        onTriggered: if (!root.edgeRemapping && !root.keyboardMode && !hover.hovered)
            root.collapse()
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
        implicitHeight: view.maximumHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "io-github-tcballard-perch"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: root.shown && root.expanded ? (root.keyboardMode && !root.focusPrimed ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand) : WlrKeyboardFocus.None
        mask: Region {
            item: view
        }
        NotchView {
            id: view
            width: Math.min(implicitWidth, notchWindow.width)
            height: implicitHeight
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
                        if (root.hoverOpen && !root.expanded)
                            hoverTimer.restart();
                    } else {
                        hoverTimer.stop();
                        if (!root.keyboardMode && !root.edgeRemapping)
                            leaveTimer.restart();
                    }
                }
            }
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
