import QtQuick

Item {
    id: root
    property var preferences: null
    property bool active: false
    readonly property bool enabled: !!preferences && preferences.record.usageEnabled === true
    property var sources: []
    property string error: ""
    readonly property bool busy: job.busy
    function setEnabled(value) {
        if (preferences)
            preferences.update({
                usageEnabled: value
            });
    }
    function refresh() {
        if (active && enabled && !busy)
            job.run("usage", {});
    }
    onActiveChanged: if (active)
        refresh()
    onEnabledChanged: {
        sources = [];
        if (enabled)
            refresh();
    }
    ToolJob {
        id: job
        onCompleted: (op, r) => {
            if (!root.enabled || !root.active)
                return;
            root.error = r.ok ? "" : "Could not read local usage. Refresh to retry.";
            root.sources = r.ok ? r.sources : [];
        }
    }
    Timer {
        interval: 60000
        running: root.active && root.enabled
        repeat: true
        onTriggered: root.refresh()
    }
}
