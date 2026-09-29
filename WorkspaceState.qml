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
    readonly property var nextEvent: events.find(function (e) {
        return e.end > root.now;
    }) || null
    readonly property string meetingSummary: nextEvent && nextEvent.start - now <= 900000 ? (nextEvent.start <= now ? "Now · " : Math.ceil((nextEvent.start - now) / 60000) + " min · ") + nextEvent.title : ""
    function request(op, p) {
        error = "";
        message = "";
        if (!work.run(op, p)) {
            error = "An operation is already in progress";
            return false;
        }
        return true;
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
        return request("integration-remove-all", {});
    }
    function brightness(value) {
        return request("brightness-set", {
            value: value
        });
    }
    ToolJob {
        id: work
        onCompleted: function (op, r) {
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
