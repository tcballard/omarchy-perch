import QtQuick
import Quickshell.Services.Mpris
import ".."
Item {
    property int eventCount: 0
    Connections {
        target: live.live
        function onActivityEvent(item) { eventCount++; }
    }
    property alias service: live
    property alias first: one
    property alias second: two
    property alias fakeShell: fakeShell
    QtObject {
        id: fakeShell
        property var saved: ({})
        property int writes: 0
        property bool failWrites: false
        function updateEntryInline(id,settings) {
            if (failWrites || id !== "io.github.tcballard.perch") return false;
            saved = JSON.parse(JSON.stringify(settings)); writes++; return true;
        }
    }
    Service { id: live; shell: fakeShell }
    FakePlayer { id: one }
    FakePlayer { id: two; dbusName: "player.b"; isPlaying: true }
    function setPlayers(which) { Mpris.players.values = which === 0 ? [] : which === 1 ? [one] : [one, two] }
    Component.onCompleted: setPlayers(2)
}
