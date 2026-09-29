import QtQuick
import "ActivityPolicy.js" as Activities
import "MediaPolicy.js" as Media

Item {
    id: root
    property var preferences: null
    property var items: []
    property real now: Date.now()
    property var timerState: Activities.timer(null, now)
    property bool restored: false
    property string error: ""
    readonly property string timerStatus: timerState.status
    readonly property int remaining: timerStatus === "running" ? Math.max(0, Math.ceil((timerState.deadline - now) / 1000)) : timerStatus === "paused" ? timerState.remaining : 0
    readonly property bool timerActive: timerStatus !== "idle"
    readonly property real timerProgress: timerState.total > 0 ? remaining / timerState.total : 0
    readonly property var focused: Activities.focus(items)
    readonly property bool hasActivity: timerActive || items.length > 0
    readonly property string clock: Qt.formatTime(new Date(now), "HH:mm")
    readonly property string summary: timerStatus === "done" ? timerState.label + " finished" : focused && (focused.state === "error" || focused.state === "waiting") ? focused.title : timerActive ? Media.time(remaining) + " · " + timerState.label : focused ? focused.title : ""
    function restore() {
        if (restored || !preferences || !preferences.ready)
            return;
        restored = true;
        now = Date.now();
        timerState = Activities.timer(preferences.record.timer, now);
    }
    onPreferencesChanged: restore()
    Connections {
        target: root.preferences
        function onLoaded() {
            root.restore();
        }
    }
    function commitTimer(next) {
        if (preferences && !preferences.update({
            timer: next
        })) {
            error = preferences.error;
            return false;
        }
        timerState = next;
        error = "";
        return true;
    }
    function start(seconds, label) {
        seconds = Number(seconds);
        if (!isFinite(seconds) || seconds < 1 || seconds > 86400)
            return false;
        if (timerStatus === "running" || timerStatus === "paused") {
            error = "Cancel the current timer before starting another.";
            return false;
        }
        now = Date.now();
        return commitTimer({
            status: "running",
            deadline: now + Math.round(seconds) * 1000,
            remaining: Math.round(seconds),
            total: Math.round(seconds),
            label: Activities.text(label, "Timer", 80)
        });
    }
    function pause() {
        if (timerStatus !== "running")
            return false;
        tick(Date.now());
        if (timerStatus !== "running")
            return false;
        return commitTimer({
            status: "paused",
            deadline: 0,
            remaining: remaining,
            total: timerState.total,
            label: timerState.label
        });
    }
    function resume() {
        if (timerStatus !== "paused")
            return false;
        now = Date.now();
        return commitTimer({
            status: "running",
            deadline: now + remaining * 1000,
            remaining: remaining,
            total: timerState.total,
            label: timerState.label
        });
    }
    function cancel() {
        return commitTimer(Activities.timer(null, now));
    }
    function tick(value) {
        now = value;
        if (timerStatus === "running" && remaining === 0) {
            var done = Object.assign({}, timerState, {
                status: "done",
                remaining: 0
            });
            // Expiry remains visible even if persistence becomes unavailable.
            if (!commitTimer(done))
                timerState = done;
        }
        var next = items.filter(function (p) {
            return p.expiresAt > now;
        });
        if (next.length !== items.length)
            items = next;
    }
    function activity(encoded) {
        now = Date.now();
        var item = Activities.normalize(encoded, now);
        if (!item)
            return "error: invalid activity";
        var next = Activities.upsert(items, item, now);
        if (!next)
            return "error: eight activities already active";
        items = next;
        return "ok";
    }
    function dismiss(id) {
        items = items.filter(function (p) {
            return p.id !== id;
        });
    }
    Timer {
        interval: root.timerStatus === "running" || root.items.length ? 1000 : 30000
        repeat: true
        running: root.timerStatus === "running" || root.items.length > 0 || !root.preferences || root.preferences.values.showClock
        onTriggered: root.tick(Date.now())
    }
}
