import QtQuick

Item {
    id: root
    property var preferences: null
    property bool active: false
    property bool windowsVisible: false
    property var reminders: []
    property var drinks: []
    property var windows: []
    property var storage: []
    property int trashCount: 0
    property bool trashPartial: false
    property bool storagePartial: false
    property string error: ""
    property string windowError: ""
    property string message: ""
    property var undoDrink: null
    property var undoReminder: null
    property real now: Date.now()
    property bool loaded: false
    property var pending: []
    readonly property bool busy: job.busy
    readonly property var config: preferences ? preferences.record.hydration || {} : ({})
    readonly property int remainingCount: reminders.filter(r => !r.done).length
    readonly property var todayDrinks: drinks.filter(r => new Date(r.at * 1000).toDateString() === new Date(now).toDateString())
    readonly property int todayVolume: todayDrinks.reduce((sum, r) => sum + r.amount, 0)
    readonly property real nextDrink: Number(config.nextAt) || 0
    readonly property bool drinkDue: config.enabled === true && nextDrink > 0 && nextDrink <= now
    signal launched
    signal launchRequested
    function request(op, p) {
        if (job.run(op, p))
            return true;
        if (pending.length >= 8) {
            error = "Please wait for the current operation.";
            return false;
        }
        pending = pending.concat([
            {
                op: op,
                p: p
            }
        ]);
        return true;
    }
    function refresh() {
        request("dock-reminders-list", {});
        request("dock-hydration-list", {});
        request("dock-trash", {});
    }
    function addReminder(title, list, due) {
        return request("dock-reminders-add", {
            title: title,
            list: list,
            due: due || 0
        });
    }
    function complete(r) {
        undoReminder = {
            id: r.id,
            done: r.done
        };
        return request("dock-reminders-toggle", {
            id: r.id,
            done: !r.done
        });
    }
    function undoComplete() {
        if (undoReminder) {
            request("dock-reminders-toggle", undoReminder);
            undoReminder = null;
        }
    }
    function configureHydration(enabled, minutes, amount, history) {
        if (!preferences)
            return false;
        return preferences.update({
            hydration: {
                enabled: enabled,
                minutes: Math.max(5, Math.min(240, minutes)),
                amount: Math.max(0, Math.min(2000, amount)),
                history: history,
                nextAt: enabled ? Date.now() + minutes * 60000 : 0
            }
        });
    }
    function drink() {
        if (config.history !== false)
            request("dock-hydration-log", {
                amount: config.amount === undefined ? 250 : config.amount
            });
        if (preferences && config.enabled)
            preferences.update({
                hydration: Object.assign({}, config, {
                    nextAt: Date.now() + (config.minutes || 30) * 60000
                })
            });
        message = "Drink recorded";
    }
    function removeDrink(r) {
        undoDrink = r;
        request("dock-hydration-remove", {
            id: r.id
        });
    }
    function undoRemove() {
        if (undoDrink) {
            request("dock-hydration-restore", {
                entry: undoDrink
            });
            undoDrink = null;
        }
    }
    function focusWindow(r) {
        launchRequested();
        return request("dock-window-focus", {
            address: r.address,
            pid: r.pid
        });
    }
    function scan(path) {
        storage = [];
        return request("dock-storage", {
            path: path
        });
    }
    function openPath(path) {
        launchRequested();
        return request("dock-file-open", {
            path: path
        });
    }
    onActiveChanged: if (active && !loaded)
        refresh()
    onWindowsVisibleChanged: if (windowsVisible)
        windowJob.run("dock-windows", {})
    ToolJob {
        id: job
        onCompleted: (op, r) => {
            root.error = r.ok ? "" : r.error;
            if (r.ok) {
                if (op.indexOf("dock-reminders-") === 0)
                    root.reminders = r.rows;
                else if (op.indexOf("dock-hydration-") === 0) {
                    root.drinks = r.rows;
                    root.loaded = true;
                } else if (op === "dock-trash") {
                    root.trashCount = r.count;
                    root.trashPartial = r.partial;
                } else if (op === "dock-trash-open")
                    root.launched();
                else if (op === "dock-storage") {
                    root.storage = r.rows;
                    root.storagePartial = r.partial;
                } else if (op === "dock-window-focus" || op === "dock-file-open")
                    root.launched();
            }
            if (root.pending.length) {
                var q = root.pending[0];
                root.pending = root.pending.slice(1);
                Qt.callLater(function () {
                    root.request(q.op, q.p);
                });
            }
        }
    }
    ToolJob {
        id: windowJob
        onCompleted: (op, r) => {
            root.windowError = r.ok ? "" : r.error;
            root.windows = r.ok ? r.rows : [];
        }
    }
    Timer {
        interval: 3000
        repeat: true
        running: root.windowsVisible
        onTriggered: windowJob.run("dock-windows", {})
    }
    Timer {
        interval: 30000
        repeat: true
        running: root.active || root.config.enabled === true
        onTriggered: root.now = Date.now()
    }
}
