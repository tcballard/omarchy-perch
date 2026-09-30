import QtQuick
import Quickshell.Io

Item {
    id: root
    property bool busy: false
    property string operation: ""
    property int timeout: 12000
    signal completed(string operation, var result)
    function run(op, payload) {
        if (busy || worker.running)
            return false;
        killGrace.stop();
        operation = op;
        busy = true;
        worker.command = [decodeURIComponent(Qt.resolvedUrl("scripts/perch-tools").toString().replace(/^file:\/\//, "")), op, JSON.stringify(payload || {})];
        deadline.restart();
        worker.running = true;
        return true;
    }
    function finish(result) {
        if (!busy)
            return;
        busy = false;
        deadline.stop();
        completed(operation, result);
    }
    Process {
        id: worker
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    root.finish(JSON.parse(text));
                } catch (_) {
                    root.finish({
                        ok: false,
                        error: "Helper returned an invalid response"
                    });
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0)
                root.finish({
                    ok: false,
                    error: "Helper failed or is unavailable"
                });
        }
    }
    Timer {
        id: deadline
        interval: root.timeout
        onTriggered: {
            worker.signal(15);
            root.finish({
                ok: false,
                error: "Operation timed out"
            });
            killGrace.restart();
        }
    }
    Timer {
        id: killGrace
        interval: 1000
        onTriggered: if (worker.running)
            worker.signal(9)
    }
}
