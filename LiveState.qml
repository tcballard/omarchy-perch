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
    property var dismissedDiscoveries: []
    property bool discoveryEnabled: false
    property string error: ""
    property string actionMessage: ""
    property bool jumpBusy: false
    signal sessionOpened
    signal activityEvent(var item)
    readonly property string timerStatus: timerState.status
    readonly property int remaining: timerStatus === "running" ? Math.max(0, Math.ceil((timerState.deadline - now) / 1000)) : timerStatus === "paused" ? timerState.remaining : 0
    readonly property bool timerActive: timerStatus !== "idle"
    readonly property real timerProgress: timerState.total > 0 ? Math.min(1, remaining / timerState.total) : 0
    readonly property var focused: Activities.focus(items)
    readonly property var attentionItems: Activities.attention(items)
    readonly property var displayItems: attentionItems.concat(items.filter(function (item) {
        return item.state !== "waiting" && item.state !== "error";
    }).sort(function (a, b) {
        return b.updatedAt - a.updatedAt;
    }))
    readonly property bool hasActivity: timers.length > 0 || items.length > 0
    readonly property string clock: Qt.formatTime(new Date(now), "HH:mm")
    readonly property string summary: timerStatus === "done" ? timerState.label + " finished" : focused && (focused.state === "error" || focused.state === "waiting") ? focused.title : timerActive ? Media.time(remaining) + " · " + timerState.label : focused ? focused.title : ""
    function jumpTo(item) {
        if (!item || item.kind !== "agent" || (!item.target && !item.targetWorkspace) || jumpBusy)
            return false;
        error = "";
        actionMessage = "";
        if (!jumpJob.run("agent-jump", {
            address: item.target,
            targetPid: item.targetPid || 0,
            targetStart: item.targetStart || "",
            targetBoot: item.targetBoot || "",
            targetTmux: item.targetTmux || null,
            targetWezterm: item.targetWezterm || null,
            targetWorkspace: item.targetWorkspace || null
        }))
            return false;
        jumpBusy = true;
        return true;
    }
    ToolJob {
        id: jumpJob
        timeout: 3000
        onCompleted: function (op, result) {
            root.jumpBusy = false;
            if (!result.ok) {
                root.error = result.error || "Could not return to that session";
                return;
            }
            root.actionMessage = result.message || "Session focused";
            root.sessionOpened();
        }
    }
    function restore() {
        if (restored || !preferences || !preferences.ready)
            return;
        restored = true;
        now = Date.now();
        items = preferences.values.rememberSessions ? Activities.recover(preferences.record.recentSessions, now) : [];
        var late = [];
        timers = Array.isArray(preferences.record.timers) ? preferences.record.timers.slice(0, 8).filter(function (t) {
            return t && typeof t === "object";
        }).map(function (t) {
            var state = Object.assign(Activities.timer(t, root.now), {
                id: String(t.id || "").slice(0, 80)
            });
            // A timer that ran out while the shell was down still deserves its alert,
            // unless so much time has passed that ringing now would only confuse.
            if (t.status === "running" && state.status === "done" && root.now - state.deadline <= 900000)
                late.push(state.label);
            return state;
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
        late.forEach(function (label) {
            root.timerFinished(label);
        });
        discoveryEnabled = preferences.values.discoverSessions;
        discoverSessions();
    }
    ToolJob {
        id: livenessJob
        timeout: 2000
        onCompleted: function(op, result) {
            if (!result.ok || !Array.isArray(result.ended)) return;
            root.items = Activities.endedProcesses(root.items,result,Date.now());
        }
    }
    Timer {
        interval: 15000
        repeat: true
        running: root.items.some(function(item) { return !!item.agentProcess && (item.state === "running" || item.state === "waiting"); })
        onTriggered: {
            var records = root.items.filter(function(item) { return !!item.agentProcess && !item.requestId && (item.state === "running" || item.state === "waiting"); }).map(function(item) { return Object.assign({id:item.id},item.agentProcess); });
            if (records.length) livenessJob.run("agent-liveness",{sessions:records});
        }
    }
    function discoverSessions() {
        if (preferences && preferences.ready && preferences.values.discoverSessions)
            discoveryJob.run("agent-discover", {});
    }
    ToolJob {
        id: discoveryJob
        timeout: 4000
        onCompleted: function(op, result) {
            if (result.ok && root.preferences && root.preferences.values.discoverSessions)
                root.items = Activities.discovered(root.items, result.sessions, Date.now(), root.dismissedDiscoveries);
        }
    }
    Timer {
        interval: 60000
        repeat: true
        running: !!root.preferences && root.preferences.ready && root.preferences.values.discoverSessions
        onTriggered: root.discoverSessions()
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
        var previous = items.find(function (p) {
            return p.id === item.id && p.expiresAt > now;
        });
        var next = Activities.upsert(items, item, now);
        if (!next)
            return "error: eight activities already active";
        items = next;
        if (["done", "waiting", "error"].indexOf(item.state) >= 0 && (!previous || previous.state !== item.state || previous.attention !== item.attention || (item.eventKey && item.eventKey !== previous.eventKey)))
            activityEvent(item);
        return "ok";
    }
    onItemsChanged: sessionSave.restart()
    Timer {
        id: sessionSave
        interval: 1500
        onTriggered: {
            if (root.preferences && root.preferences.ready)
                root.preferences.update({
                    recentSessions: root.preferences.values.rememberSessions ? Activities.snapshot(root.items) : []
                });
        }
    }
    Connections {
        target: root.preferences
        function onValuesChanged() {
            if (root.discoveryEnabled !== root.preferences.values.discoverSessions) {
                root.discoveryEnabled = root.preferences.values.discoverSessions;
                if (!root.discoveryEnabled)
                    root.items = root.items.filter(function(p) { return !p.discovered; });
                else root.discoverSessions();
            }
            if (!root.preferences.values.rememberSessions) {
                root.items = root.items.filter(function (p) {
                    return p.state !== "idle" || (p.discovered && root.preferences.values.discoverSessions);
                });
                if (root.preferences.record.recentSessions && root.preferences.record.recentSessions.length)
                    sessionSave.restart();
            }
        }
    }
    function dismiss(id) {
        dismissedDiscoveries = dismissedDiscoveries.concat([id]).slice(-128);
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
