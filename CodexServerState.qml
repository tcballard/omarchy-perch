import QtQuick

Item {
    id: root
    objectName: "codex-server-state"
    property var preferences: null
    property var live: null
    readonly property bool optedIn: !!preferences && preferences.ready && preferences.values.codexServerStatus
    readonly property string socketPath: preferences ? preferences.values.codexServerPath : ""
    property string loadingPath: ""
    property int generation: 0
    property int loadingGeneration: -1
    property string error: ""
    property int count: 0
    readonly property bool busy: job.busy
    function configure(path, enabled) {
        if (preferences)
            preferences.update({codexServerPath:path,codexServerStatus:enabled});
    }
    function invalidate() {
        generation++;
        count = 0;
        error = "";
        if (live)
            live.clearServerSessions();
        Qt.callLater(refresh);
    }
    onOptedInChanged: invalidate()
    onSocketPathChanged: invalidate()
    function refresh() {
        if (!optedIn || busy || !socketPath)
            return;
        loadingPath = socketPath;
        loadingGeneration = generation;
        job.run("codex-server-status", {path:socketPath});
    }
    ToolJob {
        id: job
        objectName: "codex-server-job"
        timeout: 7000
        onCompleted: (op, result) => {
            if (!root.optedIn || root.loadingPath !== root.socketPath || root.loadingGeneration !== root.generation)
                return;
            root.error = result.ok ? "" : result.error || "Codex server status unavailable";
            root.count = result.ok && Array.isArray(result.sessions) ? result.sessions.length : 0;
            if (root.live) {
                if (result.ok)
                    root.live.serverSnapshot(result.sessions);
                else
                    root.live.clearServerSessions();
            }
        }
    }
    Timer {
        interval: 5000
        repeat: true
        running: root.optedIn
        onTriggered: root.refresh()
    }
}
