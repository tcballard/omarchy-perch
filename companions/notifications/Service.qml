import QtQuick
import Quickshell.Io
import Quickshell.Services.Notifications

Item {
    id: root
    property var shell: null
    property var manifest: null
    property string omarchyPath: ""
    property string session: Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 10)
    property var rows: []
    // Keep QObjects out of the model. Closed signals invalidate references.
    property var refs: ({})
    property var deadlines: ({})
    property var transientKeys: ({})
    function schedule(n, key) {
        var next = Object.assign({}, deadlines);
        var seconds = n.expireTimeout;
        if (seconds === 0 || n.urgency === NotificationUrgency.Critical)
            delete next[key];
        else
            next[key] = Date.now() + Math.max(1000, Math.min(30000, (seconds > 0 ? seconds : 8) * 1000));
        deadlines = next;
        transientKeys[key] = !!(n.hints && n.hints["transient"]);
    }
    function forgetDeadline(key) {
        var next = Object.assign({}, deadlines);
        delete next[key];
        deadlines = next;
    }
    function expireDue(now) {
        Object.keys(deadlines).forEach(function (key) {
            if (root.deadlines[key] <= now) {
                root.forgetDeadline(key);
                var n = root.refs[key];
                if (n) {
                    try {
                        n.expire();
                    } catch (_) {}
                }
            }
        });
    }
    property int serial: 0
    property bool dnd: false
    property string preview: ""
    property string previewKey: ""
    property bool dirty: false
    function clean(value, limit) {
        return String(value || "").slice(0, limit).replace(/[\x00-\x1f\x7f]/g, " ");
    }
    function publish() {
        dirty = true;
        if (!debounce.running)
            debounce.start();
    }
    function send() {
        if (!dirty || bridge.busy)
            return;
        dirty = false;
        bridge.run(["omarchy-shell", "io.github.tcballard.perch", "inbox", JSON.stringify({
                version: 1,
                session: session,
                dnd: dnd,
                preview: preview,
                items: rows
            })]);
    }
    function snapshot(n, key) {
        var actions = [];
        for (var i = 0; i < n.actions.length && actions.length < 4; i++) {
            var a = n.actions[i];
            if (a && String(a.identifier).length <= 64 && !/[\x00-\x1f\x7f]/.test(String(a.identifier)))
                actions.push({
                    id: String(a.identifier),
                    label: clean(a.text || "Open", 32)
                });
        }
        return {
            key: key,
            app: clean(n.appName, 64),
            title: clean(n.summary, 120),
            body: clean(n.body, 400),
            actions: actions
        };
    }
    function refresh(n, key) {
        if (refs[key] !== n)
            return;
        schedule(n, key);
        var next = snapshot(n, key);
        if (previewKey === key && !dnd)
            preview = clean(n.summary || n.appName, 100);
        rows = rows.map(function (r) {
            return r.key === key ? next : r;
        });
        publish();
    }
    function receive(n) {
        n.tracked = true;
        var key = session + "." + (++serial);
        refs[key] = n;
        schedule(n, key);
        rows = [snapshot(n, key)].concat(rows);
        n.closed.connect(function () {
            if (root.refs[key] !== n)
                return;
            delete root.refs[key];
            root.forgetDeadline(key);
            if (root.previewKey === key) {
                root.preview = "";
                root.previewKey = "";
            }
            if (root.transientKeys[key])
                root.rows = root.rows.filter(function (r) {
                    return r.key !== key;
                });
            delete root.transientKeys[key];
            root.rows = root.rows.map(function (r) {
                return r.key === key ? {
                    key: r.key,
                    app: r.app,
                    title: r.title,
                    body: r.body,
                    actions: []
                } : r;
            });
            root.publish();
        });
        ["summaryChanged", "bodyChanged", "appNameChanged", "actionsChanged", "expireTimeoutChanged", "urgencyChanged", "hintsChanged"].forEach(function (name) {
            if (n[name] && typeof n[name].connect === "function")
                n[name].connect(function () {
                    root.refresh(n, key);
                });
        });
        while (rows.length > 20)
            remove(rows[rows.length - 1].key);
        if (!dnd) {
            previewKey = key;
            preview = clean(n.summary || n.appName, 100);
            previewExpiry.restart();
        }
        publish();
    }
    function remove(key) {
        var n = refs[key];
        delete refs[key];
        forgetDeadline(key);
        delete transientKeys[key];
        rows = rows.filter(function (r) {
            return r.key !== key;
        });
        if (n) {
            try {
                n.dismiss();
            } catch (_) {}
        }
        preview = "";
        previewKey = "";
        publish();
    }
    function clearAll() {
        rows.slice().forEach(function (r) {
            root.remove(r.key);
        });
    }
    function setQuiet(value) {
        dnd = value;
        preview = "";
        previewKey = "";
        publish();
        return "ok";
    }
    function invokeAction(expectedSession, key, action) {
        if (expectedSession !== session || !refs[key])
            return "error: expired";
        var n = refs[key];
        try {
            for (var i = 0; i < n.actions.length; i++) {
                if (n.actions[i].identifier === action) {
                    var resident = n.resident;
                    n.actions[i].invoke();
                    if (!resident)
                        remove(key);
                    return "ok";
                }
            }
        } catch (_) {}
        return "error: expired";
    }
    IpcHandler {
        target: "io.github.tcballard.perch-notifications"
        function sync(): string {
            root.publish();
            return "ok";
        }
        function invoke(session: string, key: string, action: string): string {
            return root.invokeAction(session, key, action);
        }
        function dismiss(session: string, key: string): string {
            if (session !== root.session)
                return "error: expired";
            root.remove(key);
            return "ok";
        }
        function clear(): string {
            root.clearAll();
            return "ok";
        }
        function setDnd(value: string): string {
            if (value !== "on" && value !== "off")
                return "error: invalid state";
            return root.setQuiet(value === "on");
        }
    }
    // Preserve the documented notification shortcut target while replacing the daemon.
    IpcHandler {
        target: "notifications"
        function ping(): string {
            return "ok";
        }
        function dndState(): string {
            return root.dnd ? "on" : "off";
        }
        function isDnd(): string {
            return dndState();
        }
        function toggleDnd(): string {
            root.setQuiet(!root.dnd);
            return dndState();
        }
        function setDnd(value: string): string {
            root.setQuiet(["on", "true", "1", "yes"].indexOf(value.toLowerCase()) >= 0);
            return dndState();
        }
        function clear(): string {
            root.clearAll();
            return "ok";
        }
        function dismissAll(): string {
            root.clearAll();
            return "ok";
        }
        function dismissOne(): string {
            if (!root.rows.length)
                return "none";
            root.remove(root.rows[0].key);
            return "ok";
        }
        function invokeLast(): string {
            return root.rows.length ? root.invokeAction(root.session, root.rows[0].key, "default") : "none";
        }
        function dismiss(summary: string): string {
            if (!summary)
                return "none";
            root.rows.slice().forEach(function (r) {
                if (r.title.indexOf(summary) >= 0)
                    root.remove(r.key);
            });
            return "ok";
        }
        function showHistory(): string {
            return openHistory.run(["omarchy-shell", "shell", "summon", "io.github.tcballard.perch", '{"page":"inbox"}']) ? "ok" : "busy";
        }
    }
    NotificationServer {
        actionsSupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        imageSupported: false
        persistenceSupported: true
        keepOnReload: false
        onNotification: notification => root.receive(notification)
    }
    CommandJob {
        id: openHistory
    }
    CommandJob {
        id: bridge
        onFinished: function (ok, reply) {
            if (root.dirty)
                debounce.restart();
        }
    }
    Timer {
        id: debounce
        interval: 100
        onTriggered: root.send()
    }
    Timer {
        id: previewExpiry
        interval: 6000
        onTriggered: {
            root.preview = "";
            root.previewKey = "";
            root.publish();
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: Object.keys(root.deadlines).length > 0
        onTriggered: root.expireDue(Date.now())
    }
    Component.onCompleted: publish()
}
