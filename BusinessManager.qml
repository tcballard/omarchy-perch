import QtQuick
import "BusinessPolicy.js" as Business

Item {
    id: root
    property var preferences: null
    property var accounts: []
    property var capabilities: ({
            dialog: false,
            keyring: false
        })
    property bool loaded: false
    property string error: ""
    property string message: ""
    property string lastAccountId: ""
    readonly property bool busy: accountJob.busy
    property var cache: ({})
    property var queue: []
    property var current: null
    property string migrationPath: ""
    signal reportReady(string key, var report)
    signal dialogRequested
    function account(id) {
        return accounts.find(a => a.id === id) || null;
    }
    function command(op, p) {
        if (busy) {
            error = "Please wait for the account operation.";
            return false;
        }
        error = "";
        message = "";
        return accountJob.run(op, p || {});
    }
    function reload() {
        return command("business-account-list", {});
    }
    function connect(provider, name, color, storage, currency, zone) {
        dialogRequested();
        return command("business-account-connect", {
            provider: provider,
            name: name,
            color: color,
            storage: storage,
            currency: currency,
            timeZone: zone
        });
    }
    function importFile(path, name, color) {
        return command("business-account-import", {
            path: path,
            name: name,
            color: color
        });
    }
    function disconnect(id) {
        return command("business-account-disconnect", {
            id: id
        });
    }
    function rename(id, name, color) {
        return command("business-account-rename", {
            id: id,
            name: name,
            color: color
        });
    }
    function test(id, currency, zone) {
        return command("business-account-test", {
            id: id,
            currency: currency,
            timeZone: zone
        });
    }
    function saveTile(id, patch) {
        if (!preferences)
            return false;
        var tiles = Business.tiles(preferences.record.businessTiles), before = tiles[id] || Business.tile({});
        if (!tiles[id] && Object.keys(tiles).length >= 8) {
            error = "Up to eight business tiles are supported.";
            return false;
        }
        tiles[id] = Business.tile(Object.assign({}, before, patch));
        var ok = preferences.update({
            businessTiles: tiles
        });
        if (!ok)
            error = preferences.error;
        return ok;
    }
    function migrate() {
        var old = preferences ? preferences.record.business : null;
        if (!loaded || busy || !old || old.enabled !== true || !old.path || Business.tiles(preferences.record.businessTiles).business)
            return;
        migrationPath = old.path;
        command("business-account-import", {
            path: old.path,
            name: "Imported business",
            color: "#85b8d9"
        });
    }
    function enqueue(state, force) {
        var key = state.configKey, config = Business.request(state.config, state.account);
        if (!state.active || !state.account)
            return;
        if (!force && cache[key] && Date.now() / 1000 - cache[key].updatedAt < 300) {
            reportReady(key, cache[key]);
            return;
        }
        if (current && current.key === key)
            return;
        if (queue.some(q => q.key === key))
            return;
        if (queue.length >= 8) {
            reportReady(key, {
                ok: false,
                error: "Business request queue is full; refresh shortly."
            });
            return;
        }
        queue = queue.concat([
            {
                key: key,
                config: config,
                state: state
            }
        ]);
        pump();
    }
    function pump() {
        if (reportJob.busy || current || !queue.length)
            return;
        var next = queue.slice(), request = next.shift();
        queue = next;
        if (!request.state || !request.state.active || request.state.configKey !== request.key || !account(request.config.accountId)) {
            Qt.callLater(pump);
            return;
        }
        current = request;
        if (!reportJob.run("business-metrics", request.config)) {
            current = null;
            Qt.callLater(pump);
        }
    }
    ToolJob {
        id: accountJob
        timeout: 200000
        onCompleted: (op, r) => {
            root.error = r.ok ? "" : r.error;
            if (r.ok) {
                if (r.accounts !== undefined) {
                    root.accounts = r.accounts;
                    root.capabilities = r.capabilities;
                    root.loaded = true;
                }
                root.message = r.message || "";
                if (r.accountId)
                    root.lastAccountId = r.accountId;
                if (op !== "business-account-list") {
                    root.cache = {};
                }
                if (root.migrationPath && op === "business-account-import") {
                    var old = root.preferences.record.business;
                    if (old && old.path === root.migrationPath) {
                        if (root.saveTile("business", {
                            accountId: r.accountId,
                            period: old.days === 1 ? "today" : old.days === 30 ? "30d" : "7d",
                            currency: old.currency || "USD",
                            timeZone: "UTC"
                        }))
                            root.preferences.update({
                                business: {
                                    enabled: false
                                }
                            });
                    }
                    root.migrationPath = "";
                }
                if (op === "business-account-list")
                    Qt.callLater(root.migrate);
            } else
                root.migrationPath = "";
        }
    }
    ToolJob {
        id: reportJob
        timeout: 65000
        onCompleted: (op, r) => {
            var request = root.current;
            root.current = null;
            if (request && root.account(request.config.accountId)) {
                if (r.ok) {
                    var next = Object.assign({}, root.cache);
                    next[request.key] = r;
                    var keys = Object.keys(next);
                    if (keys.length > 16)
                        delete next[keys[0]];
                    root.cache = next;
                }
                root.reportReady(request.key, r);
            }
            Qt.callLater(root.pump);
        }
    }
    Connections {
        target: root.preferences
        function onReadyChanged() {
            if (root.preferences.ready && !root.loaded)
                root.reload();
        }
    }
    Component.onCompleted: if (preferences && preferences.ready)
        reload()
}
