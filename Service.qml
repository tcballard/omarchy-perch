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
    property alias workspace: workspaceState
    WorkspaceState {
        id: workspaceState
        preferences: prefsStore
    }
    property alias notifications: inboxState
    property alias desktop: desktopState
    NotificationState {
        id: inboxState
    }
    DesktopState {
        id: desktopState
        preferences: prefsStore
        workspace: workspaceState
    }
    property alias system: systemState
    Preferences {
        id: prefsStore
        shell: root.shell
    }
    LiveState {
        id: activityState
        preferences: prefsStore
        onTimerFinished: label => {
            if (prefsStore.record.timerSound || prefsStore.record.timerNotifications) {
                root.alarmQueue = root.alarmQueue.concat([
                    {
                        label: label,
                        sound: prefsStore.record.timerSound === true,
                        notify: prefsStore.record.timerNotifications === true
                    }
                ]).slice(-8);
                alarmDispatch.restart();
            }
        }
    }
    property var alarmQueue: []
    Timer {
        id: alarmDispatch
        interval: 100
        onTriggered: {
            if (alarmJob.busy || !root.alarmQueue.length)
                return;
            var next = root.alarmQueue.slice();
            var payload = next.shift();
            if (alarmJob.run("alarm", payload))
                root.alarmQueue = next;
        }
    }
    ToolJob {
        id: alarmJob
        onCompleted: function (op, r) {
            if (!r.ok)
                workspaceState.error = r.error;
            else if (r.message)
                workspaceState.message = r.message;
            alarmDispatch.restart();
        }
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
    property string remoteArt: ""
    property string artworkTrack: ""
    property string pendingArtwork: ""
    property var lyrics: []
    property string lyricsTrack: ""
    readonly property string mediaKey: playerKey + "|" + trackKey
    property string lyricsRequestTrack: ""
    readonly property string plainLyrics: lyricsTrack === mediaKey ? lyrics.filter(function (l) {
        return l.time < 0;
    }).map(function (l) {
        return l.text;
    }).join("\n") : ""
    property string mediaError: ""
    readonly property string art: Policy.localArt(player ? player.trackArtUrl : "") || (prefsStore.values.remoteArtwork && artworkTrack === mediaKey ? remoteArt : "")
    readonly property string lyricLine: {
        if (lyricsTrack !== mediaKey)
            return "";
        var found = "";
        for (var i = 0; i < lyrics.length; i++)
            if (lyrics[i].time >= 0 && lyrics[i].time <= position)
                found = lyrics[i].text;
        return found;
    }
    function loadLyrics(path) {
        if (lyricsJob.busy)
            return false;
        lyricsRequestTrack = mediaKey;
        return lyricsJob.run("lyrics", {
            path: path
        });
    }
    function requestArtwork() {
        remoteArt = "";
        pendingArtwork = "";
        if (prefsStore.values.remoteArtwork && player && String(player.trackArtUrl).indexOf("https://") === 0) {
            pendingArtwork = String(player.trackArtUrl);
            artDelay.restart();
        }
    }
    function fetchArtwork() {
        if (!pendingArtwork || artJob.busy)
            return;
        artworkTrack = mediaKey;
        var url = pendingArtwork;
        pendingArtwork = "";
        artJob.run("artwork", {
            url: url
        });
    }
    onMediaKeyChanged: {
        lyrics = [];
        lyricsTrack = "";
        requestArtwork();
    }
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackArtUrlChanged() {
            root.requestArtwork();
        }
    }
    Connections {
        target: prefsStore
        function onValuesChanged() {
            root.requestArtwork();
        }
    }
    Timer {
        id: artDelay
        interval: 200
        onTriggered: root.fetchArtwork()
    }
    ToolJob {
        id: artJob
        onCompleted: function (op, r) {
            if (r.ok && root.artworkTrack === root.mediaKey)
                root.remoteArt = r.art;
            else if (!r.ok)
                root.mediaError = r.error;
            if (root.pendingArtwork)
                artDelay.restart();
        }
    }
    ToolJob {
        id: lyricsJob
        onCompleted: function (op, r) {
            if (r.ok && root.lyricsRequestTrack === root.mediaKey) {
                root.lyricsTrack = root.lyricsRequestTrack;
                root.lyrics = r.lyrics;
                root.mediaError = "";
            } else if (!r.ok)
                root.mediaError = r.error;
        }
    }
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
        function feedback(payload: string): string {
            if (payload.length > 4096)
                return "error: too large";
            try {
                var p = JSON.parse(payload);
                var t = String(p.message || "System").slice(0, 120);
                if (isFinite(Number(p.value)) && Number(p.max) > 0)
                    t += " · " + Math.round(Number(p.value) / Number(p.max) * 100) + "%";
                systemState.showBanner(t, "system");
                return "ok";
            } catch (_) {
                return "error: invalid feedback";
            }
        }
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
