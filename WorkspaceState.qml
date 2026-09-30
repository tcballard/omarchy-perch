import QtQuick

Item {
    id: root
    property var files: []
    property var apps: []
    property var events: []
    property var health: ({})
    property var calendarSources: []
    property string preview: ""
    property string previewKind: ""
    property string previewName: ""
    property string error: ""
    property string message: ""
    property var preferences: null
    property var initialJobs: ["health", "shelf-list", "calendar-list"]
    readonly property bool busy: work.busy
    property int brightnessValue: -1
    property real now: Date.now()
    // All-day entries and meetings already running for a while never occupy the compact pill.
    readonly property var nextEvent: events.find(function (e) {
        return !e.allDay && e.end > root.now && root.now - e.start <= 600000;
    }) || null
    readonly property string meetingSummary: {
        if (!nextEvent)
            return "";
        var lead = nextEvent.start - now;
        if (lead > 900000)
            return "";
        return (lead > 0 ? Math.ceil(lead / 60000) + " min · " : "Now · ") + nextEvent.title;
    }
    // One helper at a time; later requests wait in a short queue instead of failing.
    property var pending: []
    function request(op, p) {
        error = "";
        message = "";
        if (work.run(op, p))
            return true;
        var key = op + JSON.stringify(p || {});
        var next = pending.filter(function (q) {
            return q.key !== key;
        });
        if (next.length >= 8) {
            error = "Too many operations are waiting. Try again in a moment.";
            return false;
        }
        next.push({
            key: key,
            op: op,
            payload: p
        });
        pending = next;
        return true;
    }
    function drain() {
        if (!pending.length || work.busy)
            return;
        var q = pending[0];
        pending = pending.slice(1);
        if (!work.run(q.op, q.payload))
            pending = [q].concat(pending);
    }
    function addFiles(urls) {
        return request("shelf-add", {
            urls: urls
        });
    }
    function fileAction(verb, id) {
        return request("shelf-" + verb, {
            id: id
        });
    }
    function refreshFiles() {
        return request("shelf-list", {});
    }
    function refreshCalendar() {
        return request("calendar-list", {});
    }
    function calendarAdd(path) {
        return request("calendar-add", {
            path: path
        });
    }
    function calendarRemove(path) {
        return request("calendar-remove", {
            path: path
        });
    }
    function join(url) {
        return request("calendar-join", {
            url: url
        });
    }
    function checkHealth() {
        return request("health", {});
    }
    function integration(name, enabled) {
        return request("integration", {
            name: name,
            enabled: enabled
        });
    }
    function removeIntegrations() {
        if (preferences) preferences.update({autoUpdate:false});
        return request("integration-remove-all", {});
    }
    function updatePerch() {
        if (!preferences || !preferences.ready || busy || (health.job && health.job.status === "working")) return false;
        if (!preferences.update({lastUpdateAttempt:Date.now()})) return false;
        return integration("perch-update", true);
    }
    function setAutoUpdate(value) {
        return preferences && preferences.update({autoUpdate:value});
    }
    Timer {
        interval: 60000
        repeat: true
        running: !!root.preferences && root.preferences.ready && root.preferences.values.autoUpdate
        onTriggered: {
            var last = Number(root.preferences.record.lastUpdateAttempt || 0);
            if ((!isFinite(last) || Date.now() - last >= 21600000 || last > Date.now() + 86400000) && root.health.selfUpdate === "available")
                root.updatePerch();
        }
    }
    function brightness(value) {
        return request("brightness-set", {
            value: value
        });
    }
    ToolJob {
        id: work
        onCompleted: function (op, r) {
            Qt.callLater(root.drain);
            if (!r.ok) {
                root.error = r.error || "Operation failed";
                return;
            }
            if (r.brightness !== undefined)
                root.brightnessValue = r.brightness;
            if (r.items !== undefined)
                root.files = r.items;
            if (r.apps !== undefined)
                root.apps = r.apps;
            if (r.events !== undefined)
                root.events = r.events;
            if (r.sources !== undefined)
                root.calendarSources = r.sources;
            if (r.health !== undefined)
                root.health = r.health;
            if (r.preview !== undefined) {
                root.preview = r.preview;
                root.previewKind = r.kind;
                root.previewName = r.name;
            }
            root.message = r.message || "";
        }
    }
    Timer {
        // The helper process may still be exiting when its reply arrives.
        interval: 150
        repeat: true
        running: root.pending.length > 0 && !work.busy
        onTriggered: root.drain()
    }
    Timer {
        interval: 3000
        repeat: true
        running: !!(root.health.job && root.health.job.status === "working")
        onTriggered: if (!root.busy)
            root.checkHealth()
    }
    Timer {
        interval: 1500
        repeat: true
        running: root.initialJobs.length > 0
        onTriggered: if (!root.busy) {
            var jobs = root.initialJobs.slice();
            var op = jobs.shift();
            root.initialJobs = jobs;
            root.request(op, {});
        }
    }
    Timer {
        interval: 300000
        repeat: true
        running: root.calendarSources.length > 0
        onTriggered: if (!root.busy)
            root.refreshCalendar()
    }
    Timer {
        interval: 30000
        repeat: true
        running: root.events.length > 0
        onTriggered: root.now = Date.now()
    }
}
