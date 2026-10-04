import QtQuick
import "DockPolicy.js" as Docks
import "ModulePolicy.js" as Modules

Item {
    id: root
    property var preferences: null
    readonly property var record: preferences ? preferences.record : ({})
    readonly property var profiles: Docks.profiles(record.dockProfiles)
    readonly property string activeId: record.activeDockProfile || ""
    readonly property string activeName: (profiles.find(p => p.id === activeId) || {}).name || "My dock"
    readonly property var items: Docks.items(record.dockItems)
    property string error: ""
    property string message: ""
    property string backupText: ""
    property var apps: []
    property var folder: ({})
    readonly property bool busy: job.busy
    signal launched
    signal launchRequested
    function save(patch) {
        var ok = preferences && preferences.update(patch);
        error = ok ? "" : preferences ? preferences.error : "Settings unavailable";
        return ok;
    }
    function create(label, preset) {
        label = Docks.name(label);
        if (!label || profiles.length >= 12) {
            error = "Name your profile (up to 12 profiles).";
            return false;
        }
        var id = "profile-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 7);
        var layout = preset ? Docks.template(preset) : Docks.snapshot(record);
        var rows = profiles.map(p => p.id === activeId ? Object.assign({}, p, {
                layout: Docks.snapshot(record)
            }) : p);
        if (!save({
            dockProfiles: rows.concat([
                {
                    id: id,
                    name: label,
                    layout: layout
                }
            ])
        }))
            return false;
        return activate(id);
    }
    function activate(id) {
        var next = Docks.activate(record, id);
        if (!next) {
            error = "That profile is unavailable.";
            return false;
        }
        // Host merges fields, so explicitly reset absent layout-owned settings.
        var patch = {
            modules: Modules.defaults.slice(),
            moduleShortcuts: {},
            dockItems: [],
            tileSizes: {},
            layoutMode: "strip",
            dockScale: 1,
            showRunningApps: false,
            hoverOpen: true,
            dockAutoHide: false,
            moduleWeather: {},
            weatherInstances: {},
            moduleStatsInterval: 5
        };
        Docks.profileKeys.forEach(k => {
            if (next[k] !== undefined)
                patch[k] = next[k];
        });
        patch.dockProfiles = next.dockProfiles;
        patch.activeDockProfile = id;
        return save(patch);
    }
    property string lastSchedule: ""
    function checkSchedule() {
        if (!preferences || !preferences.ready)
            return;
        var match = Docks.scheduled(record.dockProfiles, new Date());
        var key = match ? new Date().toDateString() + ":" + match.id : "";
        if (key && key !== lastSchedule)
            activate(match.id);
        lastSchedule = key;
    }
    function schedule(id, enabled, start, end) {
        function minute(t) {
            var a = String(t).split(":");
            return a.length === 2 && /^\d{1,2}$/.test(a[0]) && /^\d{2}$/.test(a[1]) && Number(a[0]) < 24 && Number(a[1]) < 60 ? Number(a[0]) * 60 + Number(a[1]) : -1;
        }
        var a = minute(start), b = minute(end);
        if (enabled && (a < 0 || b <= a)) {
            error = "Use a start and later end time, such as 09:00–17:00.";
            return false;
        }
        lastSchedule = "";
        return save({
            dockProfiles: profiles.map(p => p.id === id ? Object.assign({}, p, {
                    schedule: {
                        enabled: enabled,
                        days: [1, 2, 3, 4, 5],
                        start: a,
                        end: b
                    }
                }) : p)
        });
    }
    Timer {
        interval: 30000
        repeat: true
        running: !!root.preferences && root.preferences.ready
        triggeredOnStart: true
        onTriggered: root.checkSchedule()
    }
    function cycle(direction) {
        if (!profiles.length)
            return;
        var i = profiles.findIndex(p => p.id === activeId);
        activate(profiles[(i + direction + profiles.length) % profiles.length].id);
    }
    function rename(id, label) {
        label = Docks.name(label);
        if (!label) {
            error = "Enter a profile name.";
            return false;
        }
        return save({
            dockProfiles: profiles.map(p => p.id === id ? Object.assign({}, p, {
                    name: label
                }) : p)
        });
    }
    function removeProfile(id) {
        return save({
            dockProfiles: profiles.filter(p => p.id !== id),
            activeDockProfile: activeId === id ? "" : activeId
        });
    }
    function add(kind, label, target) {
        var order = Modules.clean(record.modules);
        if (order.length >= 24 || items.length >= 48) {
            error = "This dock has 24 items. Remove one first.";
            return false;
        }
        var item = {
            id: "dock:" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 7),
            kind: kind,
            name: label,
            target: target
        };
        var checked = Docks.items([item]);
        if (!checked.length) {
            error = "Choose an installed app, absolute file path, or HTTP(S) link.";
            return false;
        }
        return save({
            dockItems: items.concat(checked),
            modules: order.concat([item.id])
        });
    }
    function addWeather() {
        var entries = Object.assign({}, record.weatherInstances || {}), order = Modules.clean(record.modules);
        if (Object.keys(entries).length >= 4 || order.length >= 24) {
            error = "Up to four extra weather locations fit in Perch.";
            return false;
        }
        var id = "weather:" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 7);
        entries[id] = {
            enabled: false,
            name: "New location"
        };
        return save({
            weatherInstances: entries,
            modules: order.concat([id])
        });
    }
    function removeItem(id) {
        var order = Modules.clean(record.modules).filter(x => x !== id);
        return save({
            modules: order.length ? order : ["dock"],
            dockItems: items.filter(p => p.id !== id)
        });
    }
    function resize(id, wide) {
        var sizes = Object.assign({}, record.tileSizes || {});
        sizes[id] = wide ? "wide" : "compact";
        return save({
            tileSizes: sizes
        });
    }
    function open(id) {
        var item = items.find(p => p.id === id);
        if (!item || item.kind === "spacer" || busy)
            return false;
        launchRequested();
        return job.run(item.kind === "app" ? "app-open" : item.kind === "link" ? "app-link" : "dock-file-open", item.kind === "app" ? {
            id: item.target
        } : item.kind === "link" ? {
            url: item.target
        } : {
            path: item.target
        });
    }
    function openPath(path) {
        if (busy)
            return false;
        launchRequested();
        return job.run("dock-file-open", {
            path: path
        });
    }
    function browse(path) {
        return job.run("dock-browse", {
            path: path
        });
    }
    function loadApps() {
        return job.run("app-list", {});
    }
    function saveBackup(path) {
        exportBackup();
        if (backupText.length > 50000) {
            error = "Backup is too large for file transfer. Copy the text instead.";
            return false;
        }
        return job.run("dock-backup-write", {
            path: path,
            text: backupText
        });
    }
    function loadBackup(path) {
        return job.run("dock-backup-read", {
            path: path
        });
    }
    function exportBackup() {
        backupText = Docks.backup(record);
    }
    function importBackup(text) {
        try {
            var data = Docks.restore(text);
            var patch = Object.assign({
                modules: Modules.defaults.slice(),
                moduleShortcuts: {},
                dockItems: [],
                tileSizes: {},
                layoutMode: "strip",
                dockScale: 1,
                showRunningApps: false,
                hoverOpen: true,
                dockAutoHide: false,
                moduleWeather: {},
                weatherInstances: {},
                moduleStatsInterval: 5
            }, data.current, {
                dockProfiles: data.dockProfiles,
                activeDockProfile: ""
            });
            if (save(patch)) {
                message = "Dock layouts restored.";
                return true;
            }
        } catch (e) {
            error = String(e);
        }
        return false;
    }
    ToolJob {
        id: job
        onCompleted: (op, r) => {
            root.error = r.ok ? "" : r.error;
            if (!r.ok)
                return;
            if (op === "app-list")
                root.apps = r.apps;
            else if (op === "dock-browse")
                root.folder = r;
            else if (op === "dock-backup-read")
                root.backupText = r.text;
            else if (op === "dock-backup-write")
                root.message = r.message;
            else
                root.launched();
        }
    }
}
