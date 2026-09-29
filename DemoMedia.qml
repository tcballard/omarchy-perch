import QtQuick

// Fictional data, available only after an explicit demo summon.
QtObject {
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
        return false;
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
        state = value === "empty" || value === "paused" ? value : "playing";
        title = state === "empty" ? "Nothing playing" : "Between Stations";
        artist = state === "empty" ? "Start music in your favourite player" : "The Early Hours";
        position = 84;
    }
}
