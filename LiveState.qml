import QtQuick
import "ActivityPolicy.js" as Activities
import "MediaPolicy.js" as Media

Item {
    id: root
    property var preferences: null
    property var items: []
    property real now: Date.now()
    property var timers: []
    property string selectedTimer: ""
    signal timerFinished(string label)
    property var timerState: Activities.timer(null, now)
    property bool restored: false
    property string error: ""
    readonly property string timerStatus: timerState.status
    readonly property int remaining: timerStatus === "running" ? Math.max(0, Math.ceil((timerState.deadline - now) / 1000)) : timerStatus === "paused" ? timerState.remaining : 0
    readonly property bool timerActive: timerStatus !== "idle"
    readonly property real timerProgress: timerState.total > 0 ? Math.min(1, remaining / timerState.total) : 0
    readonly property var focused: Activities.focus(items)
    readonly property bool hasActivity: timers.length > 0 || items.length > 0
    readonly property string clock: Qt.formatTime(new Date(now), "HH:mm")
    readonly property string summary: timerStatus === "done" ? timerState.label + " finished" : focused && (focused.state === "error" || focused.state === "waiting") ? focused.title : timerActive ? Media.time(remaining) + " · " + timerState.label : focused ? focused.title : ""
    function restore() {
        if (restored || !preferences || !preferences.ready)
            return;
        restored = true;
        now = Date.now();
        timers = Array.isArray(preferences.record.timers) ? preferences.record.timers.slice(0, 8).filter(function (t) {
            return t && typeof t === "object";
        }).map(function (t) {
            return Object.assign(Activities.timer(t, root.now), {
                id: String(t.id || "").slice(0, 80)
            });
        }).filter(function (t) {
            return t.id && t.status !== "idle";
        }) : [];
        if (!timers.length) {
            var old = Activities.timer(preferences.record.timer, now);
            if (old.status !== "idle")
                timers = [Object.assign(old, {
                        id: "legacy"
                    })];
        }
        selectedTimer = timers.length ? timers[0].id : "";
        timerState = timers.length ? timers[0] : Activities.timer(null, now);
    }
    onPreferencesChanged: restore()
    Connections {
        target: root.preferences
        function onLoaded() {
            root.restore();
        }
    }
    function chooseTimer(id) {
        var t = timers.find(function (t) {
            return t.id === id;
        });
        if (!t)
            return false;
        selectedTimer = id;
        timerState = t;
        return true;
    }
    function saveTimers(next, selected) {
        var current = next.find(function (t) {
            return t.id === selected;
        }) || next[0] || Activities.timer(null, now);
        if (preferences && !preferences.update({
            timers: next,
            timer: current
        })) {
            error = preferences.error;
            return false;
        }
        timers = next;
        selectedTimer = current.id || "";
        timerState = current;
        error = "";
        return true;
    }
    function commitTimer(next) {
        var id = selectedTimer || ("timer-" + Date.now() + "-" + Math.random().toString(36).slice(2, 6));
        var list = timers.filter(function (t) {
            return t.id !== id;
        });
        if (next.status !== "idle")
            list.push(Object.assign({}, next, {
                id: id
            }));
        return saveTimers(list, id);
    }
    function add(seconds, label) {
        if (timers.length >= 8) {
            error = "Eight timers are already present";
            return false;
        }
        seconds = Number(seconds);
        if (!isFinite(seconds) || seconds < 1 || seconds > 86400)
            return false;
        now = Date.now();
        var id = "timer-" + now + "-" + Math.random().toString(36).slice(2, 6);
        return saveTimers(timers.concat([
            {
                id: id,
                status: "running",
                deadline: now + Math.round(seconds) * 1000,
                remaining: Math.round(seconds),
                total: Math.round(seconds),
                label: Activities.text(label, "Timer", 80)
            }
        ]), id);
    }
    function snooze(seconds) {
        if (timerStatus !== "done")
            return false;
        return commitTimer(Object.assign({}, timerState, {
            status: "running",
            deadline: Date.now() + seconds * 1000,
            remaining: seconds
        }));
    }
    function repeatTimer() {
        return commitTimer(Object.assign({}, timerState, {
            status: "running",
            deadline: Date.now() + timerState.total * 1000,
            remaining: timerState.total
        }));
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
        var finished = [];
        var nextTimers = timers.map(function (t) {
            if (t.status === "running" && t.deadline <= value) {
                finished.push(t.label);
                return Object.assign({}, t, {
                    status: "done",
                    remaining: 0
                });
            }
            return t;
        });
        if (finished.length) {
            if (!saveTimers(nextTimers, selectedTimer)) {
                timers = nextTimers;
                timerState = nextTimers.find(function (t) {
                    return t.id === root.selectedTimer;
                }) || Activities.timer(null, now);
            }
            finished.forEach(function (label) {
                root.timerFinished(label);
            });
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
        interval: root.timers.some(function (t) {
            return t.status === "running";
        }) || root.items.length ? 1000 : 30000
        repeat: true
        running: root.timers.some(function (t) {
            return t.status === "running";
        }) || root.items.length > 0 || !root.preferences || root.preferences.values.showClock
        onTriggered: root.tick(Date.now())
    }
}
