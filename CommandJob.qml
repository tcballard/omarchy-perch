import QtQuick
import Quickshell.Io

// One bounded job at a time. Only callers' fixed argv allowlists reach this helper.
Item {
    id: root
    property bool busy: false
    property string reply: ""
    signal finished(bool success, string reply)
    function run(argv) {
        if (busy || process.running)
            return false;
        busy = true;
        timedOut = false;
        reply = "";
        deadline.restart();
        process.command = argv;
        process.running = true;
        return true;
    }
    property bool timedOut: false
    function complete(ok) {
        if (!busy)
            return;
        busy = false;
        deadline.stop();
        finished(ok && !timedOut, reply.trim());
    }
    Process {
        id: process
        stdout: SplitParser {
            onRead: data => root.reply = (root.reply + data).slice(0, 512)
        }
        onExited: (code, status) => root.complete(code === 0)
    }
    Timer {
        id: deadline
        interval: 3000
        // Completion follows the actual exit so the next run() is never refused
        // while the killed process is still being reaped.
        onTriggered: {
            root.timedOut = true;
            process.signal(9);
        }
    }
}
