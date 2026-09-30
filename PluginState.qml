import QtQuick

Item {
    id: root
    property var plugins: []
    property string error: ""
    property string message: ""
    property bool loaded: false
    readonly property bool busy: job.busy
    signal launchFinished(bool success)
    function refresh() {
        if (busy)
            return;
        error = "";
        job.run("plugin-list", {});
    }
    function openPlugin(id) {
        if (busy)
            return false;
        error = "";
        message = "";
        return job.run("plugin-open", {
            id: id
        });
    }
    function get(id) {
        return plugins.find(function (p) {
            return p.id === id;
        }) || null;
    }
    ToolJob {
        id: job
        timeout: 9000
        onCompleted: (operation, result) => {
            if (!result.ok)
                root.error = result.error || "Plugin operation failed";
            else if (operation === "plugin-list") {
                root.plugins = result.plugins || [];
                root.loaded = true;
            } else
                root.message = result.message || "Opened plugin";
            if (operation === "plugin-open")
                root.launchFinished(result.ok === true);
        }
    }
    Component.onCompleted: refresh()
}
