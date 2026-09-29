import QtQuick
import Quickshell.Io

Item {
    id: root
    property var owner: null
    property bool ready: false
    property bool reading: true
    property string pending: ""
    property string error: ""
    onErrorChanged: if (owner)
        owner.publish(false)
    function save(value) {
        if (!ready)
            return;
        pending = JSON.stringify(value);
        debounce.restart();
    }
    function writeNext() {
        if (!ready || io.running || !pending)
            return;
        reading = false;
        io.command = ["/usr/bin/python3", "-I", decodeURIComponent(Qt.resolvedUrl("store.py").toString().replace(/^file:\/\//, "")), "write"];
        io.running = true;
        deadline.restart();
    }
    Process {
        id: io
        stdinEnabled: true
        onStarted: if (!root.reading) {
            write(root.pending + "\n");
            root.pending = "";
            stdinEnabled = false;
        }
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                deadline.stop();
                try {
                    var p = JSON.parse(text);
                    if (!p.ok)
                        throw new Error();
                    if (root.reading) {
                        root.ready = true;
                        root.owner.restoreHistory(p);
                    }
                    root.error = "";
                } catch (_) {
                    root.error = "Could not read or save notification history";
                }
            }
        }
        onExited: {
            stdinEnabled = true;
            if (root.reading && !root.ready)
                readRetry.restart();
            if (root.pending)
                debounce.restart();
        }
    }
    Timer {
        id: debounce
        interval: 400
        onTriggered: root.writeNext()
    }
    Timer {
        id: deadline
        interval: 2500
        onTriggered: {
            io.signal(9);
            root.error = "History operation timed out";
        }
    }
    property int readAttempts: 0
    function read() {
        if (ready || io.running || readAttempts >= 4)
            return;
        readAttempts++;
        reading = true;
        io.command = ["/usr/bin/python3", "-I", decodeURIComponent(Qt.resolvedUrl("store.py").toString().replace(/^file:\/\//, "")), "read"];
        io.running = true;
        deadline.restart();
    }
    Timer {
        // A cold python start at login can miss the first deadline; try again.
        id: readRetry
        interval: 2000
        onTriggered: root.read()
    }
    Component.onCompleted: read()
}
