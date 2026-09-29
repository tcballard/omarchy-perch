import QtQuick

Item {
    id: root
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
    ]
    function launch(id) {
        if (!entries.some(function (e) {
            return e.id === id;
        }))
            return false;
        error = "";
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
