import QtQuick
import "BusinessPolicy.js" as Business

Item {
    id: root
    property var preferences: null
    property var manager: null
    property string instanceId: "business"
    property bool active: false
    readonly property var config: Business.tile(preferences ? (preferences.record.businessTiles || {})[instanceId] : {})
    readonly property var account: manager ? manager.account(config.accountId) : null
    readonly property string configKey: Business.key(config, account)
    property var report: null
    property string error: ""
    property bool busy: false
    readonly property var selectedMetric: Business.metric(report, config, account)
    readonly property string selectedLabel: config.metric || ((Business.labels[account ? account.provider : ''] || [])[0]) || "Choose metric"
    readonly property var points: report ? (report.series || {})[selectedLabel] || [] : []
    readonly property string headline: selectedMetric ? (selectedMetric.currency ? selectedMetric.currency.toUpperCase() + " " : "") + Number(selectedMetric.value).toLocaleString(Qt.locale(), 'f', selectedMetric.currency ? 2 : 0) : account ? "—" : "Connect"
    function configure(patch) {
        return manager && manager.saveTile(instanceId, patch);
    }
    function refresh(force) {
        if (!active || !account || !manager)
            return;
        busy = true;
        manager.enqueue(root, force === true);
    }
    onActiveChanged: {
        if (active) {
            if (manager && !manager.loaded && !manager.busy)
                manager.reload();
            refresh(false);
        } else
            busy = false;
    }
    onConfigKeyChanged: {
        report = null;
        error = "";
        busy = false;
        refreshSoon.restart();
    }
    Timer {
        id: refreshSoon
        interval: 0
        onTriggered: root.refresh(false)
    }
    Connections {
        target: root.manager
        function onReportReady(key, r) {
            if (key !== root.configKey)
                return;
            root.busy = false;
            root.error = r.ok ? "" : r.error;
            if (r.ok)
                root.report = r;
        }
    }
    Timer {
        interval: 300000
        repeat: true
        running: root.active && !!root.account
        onTriggered: root.refresh(true)
    }
}
