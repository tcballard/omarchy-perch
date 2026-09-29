import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Io
import "MediaPolicy.js" as Policy

Item {
    id: root
    property string omarchyPath: ""
    property var shell: null
    property var manifest: null
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
        function status(): string {
            return JSON.stringify({
                state: root.state,
                players: root.players.length
            });
        }
    }
}
