import QtQuick

Item {
    id: root
    property var preferences: null
    property var workspace: null
    readonly property var pins: preferences && Array.isArray(preferences.record.pins) ? preferences.record.pins.slice(0, 8).filter(function (p) {
        return p && /^[A-Za-z0-9._-]+\.desktop$/.test(p.id) && typeof p.name === "string";
    }) : []
    function pin(app) {
        if (!preferences || !app)
            return false;
        var list = pins.filter(function (p) {
            return p.id !== app.id;
        });
        if (list.length >= 8) {
            error = "Eight applications are already pinned";
            return false;
        }
        var ok = preferences.update({
            pins: list.concat([
                {
                    id: app.id,
                    name: app.name.slice(0, 100)
                }
            ])
        });
        error = ok ? "" : preferences.error;
        return ok;
    }
    function unpin(id) {
        return preferences && preferences.update({
            pins: pins.filter(function (p) {
                return p.id !== id;
            })
        });
    }
    property string error: ""
    readonly property bool busy: job.busy
    readonly property var entries: [
        {
            id: "apps",
            label: "Applications",
            detail: "Find and launch an app"
        },
        {
            id: "root",
            label: "Omarchy menu",
            detail: "All desktop commands"
        },
        {
            id: "clipboard",
            label: "Clipboard",
            detail: "Recent copied items"
        },
        {
            id: "emoji",
            label: "Emoji",
            detail: "Find a character"
        },
        {
            id: "style",
            label: "Appearance",
            detail: "Themes and wallpaper"
        },
        {
            id: "setup",
            label: "Settings",
            detail: "Network, displays and more"
        }
    ].concat(pins.map(function (p) {
        return {
            id: "app:" + p.id,
            label: p.name,
            detail: "Pinned application"
        };
    }))
    function launch(id) {
        if (!entries.some(function (e) {
            return e.id === id;
        }))
            return false;
        error = "";
        if (id.indexOf("app:") === 0)
            return workspace && workspace.request("app-open", {
                id: id.slice(4)
            });
        var argv = id === "clipboard" ? ["omarchy-menu-clipboard"] : id === "emoji" ? ["omarchy-menu-emoji"] : ["omarchy-menu", "summon", id];
        return job.run(argv);
    }
    CommandJob {
        id: job
        onFinished: function (ok, reply) {
            if (!ok)
                root.error = "Could not open this desktop menu.";
        }
    }
}
