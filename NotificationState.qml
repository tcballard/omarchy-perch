import QtQuick
import "NotificationPolicy.js" as Policy

Item {
    id: root
    property var items: []
    property var blocked: []
    readonly property int unread: items.filter(function (r) {
        return r.unread;
    }).length
    function markRead() {
        return command("markRead");
    }
    function block(app, value) {
        return command("blockApp", [app, value ? "on" : "off"]);
    }
    function replyTo(key, text) {
        return command("reply", [session, key, text]);
    }
    property bool connected: false
    property bool dnd: false
    property string session: ""
    property string preview: ""
    property string error: ""
    readonly property bool busy: request.busy
    function accept(payload) {
        var p = Policy.parse(payload);
        if (!p)
            return "error: invalid inbox";
        connected = true;
        session = p.session;
        items = p.items;
        dnd = p.dnd;
        blocked = p.blocked;
        preview = p.preview;
        if (preview)
            previewExpiry.restart();
        error = p.error;
        return "ok";
    }
    function command(verb, args) {
        if (["sync", "invoke", "dismiss", "clear", "setDnd", "markRead", "blockApp", "reply"].indexOf(verb) < 0)
            return false;
        error = "";
        return request.run(["omarchy-shell", "io.github.tcballard.perch-notifications", verb].concat(args || []));
    }
    function sync() {
        return command("sync");
    }
    function invoke(key, action) {
        return command("invoke", [session, key, action]);
    }
    function dismiss(key) {
        return command("dismiss", [session, key]);
    }
    function clear() {
        return command("clear");
    }
    function toggleDnd() {
        return command("setDnd", [dnd ? "off" : "on"]);
    }
    CommandJob {
        id: request
        onFinished: function (ok, reply) {
            if (!ok || reply !== "ok") {
                error = "Notification companion unavailable or action expired. Refresh to reconnect.";
                connected = false;
                preview = "";
                // Keep history text but never offer stale live actions.
                items = items.map(function (row) {
                    return Object.assign({}, row, {
                        actions: [],
                        reply: false
                    });
                });
            }
        }
    }
    Timer {
        id: previewExpiry
        interval: 6000
        onTriggered: root.preview = ""
    }
    Timer {
        interval: 1200
        running: true
        onTriggered: root.sync()
    }
}
