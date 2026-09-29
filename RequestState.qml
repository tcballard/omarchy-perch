import QtQuick

Item {
    id: root
    objectName: "request-state"
    property string requestId: ""
    property string loadingId: ""
    property var request: null
    property string error: ""
    property bool delivered: false
    property double now: Date.now() / 1000
    readonly property bool expired: !!request && request.expiresAt <= now
    readonly property bool busy: job.busy
    signal responded
    onRequestIdChanged: {
        request = null;
        error = "";
        delivered = false;
        if (requestId)
            load();
    }
    function load() {
        if (!requestId || job.busy)
            return;
        loadingId = requestId;
        job.run("request-get", {
            id: requestId
        });
    }
    function reply(action, answers) {
        if (!request || expired || busy || delivered)
            return;
        error = "";
        loadingId = requestId;
        job.run("request-reply", {
            id: requestId,
            action: action,
            answers: answers || {}
        });
    }
    ToolJob {
        id: job
        timeout: 4000
        onCompleted: (op, r) => {
            if (root.loadingId !== root.requestId) {
                Qt.callLater(root.load);
                return;
            }
            root.error = r.ok ? "" : r.error || "Request unavailable. Continue in your agent session.";
            if (op === "request-get")
                root.request = r.ok ? r.request : null;
            else if (r.ok) {
                root.delivered = true;
                root.responded();
            }
        }
    }
    Timer {
        interval: 500
        repeat: true
        running: !!root.request
        onTriggered: root.now = Date.now() / 1000
    }
}
