import QtQuick

// Fictional data, available only after an explicit demo summon.
Item {
    id: root
    property alias notifications: demoInbox
    property alias desktop: demoDesktop
    QtObject {
        id: demoInbox
        property bool connected: true
        property bool busy: false
        property bool dnd: false
        property string preview: ""
        property string error: ""
        property var items: []
        function sync() {
            return true;
        }
        function toggleDnd() {
            dnd = !dnd;
            return true;
        }
        function dismiss(key) {
            items = items.filter(function (r) {
                return r.key !== key;
            });
        }
        function clear() {
            items = [];
            preview = "";
        }
        function invoke(key, action) {
            dismiss(key);
            return true;
        }
    }
    QtObject {
        id: demoDesktop
        property bool busy: false
        property string error: ""
        property var entries: [
            {
                id: "apps",
                label: "Applications",
                detail: "Find an app"
            },
            {
                id: "root",
                label: "Omarchy menu",
                detail: "Desktop commands"
            },
            {
                id: "clipboard",
                label: "Clipboard",
                detail: "Recent items"
            },
            {
                id: "emoji",
                label: "Emoji",
                detail: "Find a character"
            },
            {
                id: "style",
                label: "Appearance",
                detail: "Themes"
            },
            {
                id: "setup",
                label: "Settings",
                detail: "Desktop settings"
            }
        ]
        function launch(id) {
            error = "Demo only — no desktop menu was opened.";
            return false;
        }
    }
    property alias live: activityState
    property alias system: systemState
    property string preferred: ""
    property bool canSeek: state !== "empty"
    property bool canRaise: false
    property string trackKey: title
    function seekTo(value, expectedPlayer, expectedTrack) {
        if (!canSeek || expectedPlayer !== playerKey || expectedTrack !== trackKey || !isFinite(value))
            return false;
        position = Math.max(0, Math.min(duration, value));
        return true;
    }
    LiveState {
        id: activityState
    }
    QtObject {
        id: systemState
        property bool audioAvailable: true
        property real volume: 0.42
        property bool muted: false
        property string outputName: "Demo speakers"
        property bool batteryAvailable: true
        property int batteryPercent: 78
        property bool charging: true
        property bool onBattery: false
        property string error: ""
        property string banner: ""
        function setVolume(value) {
            volume = Math.max(0, Math.min(1, value));
            return true;
        }
        function toggleMute() {
            muted = !muted;
            return true;
        }
    }
    property string state: "playing"
    property string title: "Between Stations"
    property string artist: "The Early Hours"
    property string identity: "Fictional demo player"
    property string art: ""
    property string actionError: ""
    property string playerKey: "demo"
    property var players: []
    property bool timeline: state !== "empty"
    property real position: 84
    property real duration: 237
    property bool canPrevious: state !== "empty"
    property bool canNext: state !== "empty"
    property bool canToggle: state !== "empty"
    function choose(key) {
        preferred = key;
        return key === "" || key === "demo";
    }
    function act(action) {
        if (state === "empty")
            return false;
        if (action === "toggle")
            state = state === "playing" ? "paused" : "playing";
        else {
            title = title === "Between Stations" ? "First Light" : "Between Stations";
            position = 0;
        }
        return true;
    }
    function setState(value) {
        demoInbox.items = [];
        demoInbox.preview = "";
        demoInbox.dnd = false;
        if (value === "inbox") {
            demoInbox.items = [
                {
                    key: "demo.1",
                    app: "Calendar · demo",
                    title: "Design review in 10 minutes",
                    body: "A fictional reminder, with an action you can try safely.",
                    actions: [
                        {
                            id: "open",
                            label: "Open event"
                        }
                    ]
                },
                {
                    key: "demo.2",
                    app: "Files · demo",
                    title: "Transfer complete",
                    body: "Your files are ready.",
                    actions: []
                }
            ];
            demoInbox.preview = "Design review in 10 minutes";
        }
        activityState.cancel();
        activityState.items = [];
        if (value === "timer")
            activityState.start(1500, "Demo focus");
        if (value === "activity")
            activityState.activity(JSON.stringify({
                id: "demo-build",
                title: "Building Perch",
                detail: "Fictional progress",
                state: "running",
                progress: 0.65
            }));
        state = value === "empty" || value === "paused" ? value : "playing";
        title = state === "empty" ? "Nothing playing" : "Between Stations";
        artist = state === "empty" ? "Start music in your favourite player" : "The Early Hours";
        position = 84;
    }
}
