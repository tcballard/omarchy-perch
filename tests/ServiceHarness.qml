import QtQuick
import Quickshell.Services.Mpris
import ".."
Item {
    property alias service: live
    property alias first: one
    property alias second: two
    Service { id: live }
    FakePlayer { id: one }
    FakePlayer { id: two; dbusName: "player.b"; isPlaying: true }
    function setPlayers(which) { Mpris.players.values = which === 0 ? [] : which === 1 ? [one] : [one, two] }
    Component.onCompleted: setPlayers(2)
}
