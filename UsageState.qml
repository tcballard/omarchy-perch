import QtQuick

Item {
    id: root
    property var preferences: null
    property bool active: false
    readonly property bool usageEnabled: !!preferences && preferences.record.usageEnabled === true
    property var sources: []
    property string error: ""
    property var history: null
    property string historyProvider: "codex"
    property int historyDays: 7
    property string historyError: ""
    property string historyKey: ""
    readonly property bool historyBusy: historyJob.busy
    function refreshHistory() {
        if (!active || !usageEnabled || historyJob.busy)
            return;
        historyKey = historyProvider + ":" + historyDays;
        historyJob.run("usage-history", {
            provider: historyProvider,
            days: historyDays
        });
    }
    onHistoryProviderChanged: {
        history = null;
        refreshHistory();
    }
    onHistoryDaysChanged: {
        history = null;
        refreshHistory();
    }
    ToolJob {
        id: historyJob
        onCompleted: (op, r) => {
            if (!root.usageEnabled || !root.active)
                return;
            if (root.historyKey !== root.historyProvider + ":" + root.historyDays) {
                Qt.callLater(root.refreshHistory);
                return;
            }
            root.historyError = r.ok ? "" : r.error;
            if (r.ok)
                root.history = r;
        }
    }
    readonly property bool busy: job.busy
    function setEnabled(value) {
        if (preferences)
            preferences.update({
                usageEnabled: value
            });
    }
    function refresh() {
        refreshHistory();
        if (active && usageEnabled && !busy)
            job.run("usage", {});
    }
    onActiveChanged: if (active)
        refresh()
    onUsageEnabledChanged: {
        sources = [];
        history = null;
        if (usageEnabled)
            refresh();
    }
    ToolJob {
        id: job
        onCompleted: (op, r) => {
            if (!root.usageEnabled || !root.active)
                return;
            root.error = r.ok ? "" : "Could not read local usage. Refresh to retry.";
            root.sources = r.ok ? r.sources : [];
        }
    }
    Timer {
        interval: 60000
        running: root.active && root.usageEnabled
        repeat: true
        onTriggered: root.refresh()
    }
}
