import QtQuick
QtObject {
    property string dbusName: "player.a"
    property string identity: "Test player"
    property string trackTitle: "Test track"
    property string trackArtist: "Test artist"
    property string trackArtUrl: "https://example.invalid/art"
    property bool isPlaying: false
    property bool canSeek: true
    property int uniqueId: 1
    property bool canRaise: true
    property int raiseCalls: 0
    function raise() { raiseCalls++ }
    property bool canControl: true
    property bool canPause: true
    property bool canPlay: true
    property bool canGoNext: true
    property bool canGoPrevious: false
    property bool positionSupported: true
    property bool lengthSupported: true
    property real position: 20
    property real length: 100
    property int nextCalls: 0
    property int previousCalls: 0
    function play() { isPlaying = true }
    function pause() { isPlaying = false }
    function next() { nextCalls++ }
    function previous() { previousCalls++ }
}
