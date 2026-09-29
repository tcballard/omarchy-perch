import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Io
import "MediaPolicy.js" as Policy

Item {
    id: root
    property string omarchyPath: ""
    property var shell: null
    property var manifest: null
    property alias preferences: prefsStore
    property alias live: activityState
    property alias notifications: inboxState
    property alias desktop: desktopState
    NotificationState {
        id: inboxState
    }
    DesktopState {
        id: desktopState
    }
    property alias system: systemState
    Preferences {
        id: prefsStore
        shell: root.shell
    }
    LiveState {
        id: activityState
        preferences: prefsStore
    }
    SystemState {
        id: systemState
    }
    readonly property bool canSeek: !!(player && player.canControl && player.canSeek && timeline)
    readonly property bool canRaise: !!(player && player.canRaise)
    function seekTo(value, expectedPlayer, expectedTrack) {
        if (!canSeek || playerKey !== expectedPlayer || String(player.uniqueId) !== String(expectedTrack) || !isFinite(value))
            return false;
        try {
            player.position = Math.max(0, Math.min(duration, value));
            actionError = "";
            return true;
        } catch (_) {
            actionError = "Player did not accept seeking";
            return false;
        }
    }
    readonly property string trackKey: player ? String(player.uniqueId) : ""
    function raisePlayer() {
        if (!canRaise)
            return false;
        try {
            player.raise();
            return true;
        } catch (_) {
            actionError = "Could not open the player";
            return false;
        }
    }
    property string preferred: ""
    property string actionError: ""
    readonly property var players: (Mpris.players ? Mpris.players.values : []).filter(function (p) {
        return Policy.key(p).indexOf("playerctld") === -1;
    })
    readonly property var player: Policy.select(players, preferred)
    readonly property string state: !player ? "empty" : player.isPlaying ? "playing" : "paused"
    readonly property string title: Policy.bounded(player ? player.trackTitle : "", player ? "Unknown track" : "Nothing playing")
    readonly property string artist: Policy.bounded(player ? player.trackArtist : "", player ? "Artist unavailable" : "Start music in your favourite player")
    readonly property string identity: Policy.bounded(player ? player.identity : "", "Media")
    readonly property string art: Policy.localArt(player ? player.trackArtUrl : "")
    readonly property bool canPrevious: Policy.allowed(player, "previous")
    readonly property bool canNext: Policy.allowed(player, "next")
    readonly property bool canToggle: Policy.allowed(player, "toggle")
    readonly property bool timeline: !!(player && player.positionSupported && player.lengthSupported && player.length > 0)
    readonly property real position: timeline ? Policy.seconds(player.position) : 0
    readonly property real duration: timeline ? Policy.seconds(player.length) : 0
    readonly property string playerKey: Policy.key(player)
    onPlayerChanged: actionError = ""
    onPlayersChanged: {
        if (preferred && !players.some(function (p) {
            return Policy.key(p) === root.preferred;
        }))
            preferred = "";
    }
    function choose(dbusName) {
        if (dbusName === "") {
            preferred = "";
            return true;
        }
        if (!players.some(function (p) {
            return Policy.key(p) === dbusName;
        }))
            return false;
        preferred = dbusName;
        actionError = "";
        return true;
    }
    function act(action) {
        if (!Policy.allowed(player, action))
            return false;
        actionError = "";
        try {
            if (action === "next")
                player.next();
            else if (action === "previous")
                player.previous();
            else if (player.isPlaying)
                player.pause();
            else
                player.play();
            return true;
        } catch (_) {
            actionError = "Player did not accept that action";
            return false;
        }
    }
    // Diagnostics contain no media metadata.
    IpcHandler {
        target: "io.github.tcballard.perch"
        function inbox(payload: string): string {
            return inboxState.accept(payload);
        }
        function activity(payload: string): string {
            return activityState.activity(payload);
        }
        function dismiss(id: string): string {
            activityState.dismiss(id);
            return "ok";
        }
        function timer(seconds: string, label: string): string {
            return activityState.start(Number(seconds), label) ? "ok" : "error: timer not started";
        }
        function cancelTimer(): string {
            return activityState.cancel() ? "ok" : "error: timer not cancelled";
        }
        function status(): string {
            return JSON.stringify({
                state: root.state,
                players: root.players.length,
                timer: activityState.timerStatus,
                activities: activityState.items.length,
                audio: systemState.audioAvailable,
                battery: systemState.batteryAvailable
            });
        }
    }
}
