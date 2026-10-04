import QtQuick

Item {
    id: root
    property var preferences: null
    property bool active: false
    readonly property var config: preferences ? preferences.record.business || {} : ({})
    property var report: null
    property string error: ""
    readonly property bool busy: job.busy
    property string requestKey: ""
    readonly property string configKey: JSON.stringify(config)
    function configure(path, days, currency, enabled) {
        if (!preferences)
            return false;
        return preferences.update({
            business: {
                path: path,
                days: days,
                currency: currency,
                enabled: enabled
            }
        });
    }
    function refresh() {
        if (!active || !config.enabled || busy)
            return;
        requestKey = configKey;
        job.run("business-metrics", {
            path: config.path,
            days: config.days || 7,
            currency: config.currency || "USD"
        });
    }
    onActiveChanged: if (active && (!report || Date.now() / 1000 - report.updatedAt > 300))
        refresh()
    onConfigKeyChanged: {
        report = null;
        error = "";
        refresh();
    }
    ToolJob {
        id: job
        timeout: 45000
        onCompleted: (op, r) => {
            if (root.requestKey !== root.configKey) {
                Qt.callLater(root.refresh);
                return;
            }
            root.error = r.ok ? "" : r.error;
            if (r.ok)
                root.report = r;
        }
    }
    Timer {
        interval: 300000
        repeat: true
        running: root.active && root.config.enabled === true
        onTriggered: root.refresh()
    }
}
