import QtQuick
QtObject {
    property bool running: false
    property var command: []
    property QtObject stdout: null
    property QtObject stderr: null
    signal exited(int exitCode, int exitStatus)
    signal started()
    function signal(number) { running = false; }
}
