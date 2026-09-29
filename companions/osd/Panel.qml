import QtQuick
import Quickshell.Io

Item {
    id: root
    property var shell: null
    property var manifest: null
    property string omarchyPath: ""
    property bool opened: false
    property string pending: ""
    function open(payload) {
        if (payload.length > 4096)
            return;
        try {
            var p = JSON.parse(payload);
            pending = JSON.stringify({
                message: String(p.message || p.icon || "System").slice(0, 120),
                value: p.value,
                max: p.max
            });
            opened = true;
            coalesce.restart();
        } catch (_) {}
    }
    function close() {
        opened = false;
        pending = "";
    }
    Timer {
        id: coalesce
        interval: 60
        onTriggered: if (!job.busy && root.pending) {
            job.run(["omarchy-shell", "io.github.tcballard.perch", "feedback", root.pending]);
            root.pending = "";
        }
    }
    CommandJob {
        id: job
        onFinished: if (root.pending)
            coalesce.restart()
    }
    IpcHandler {
        target: "osd"
        function show(payloadJson: string): string {
            root.open(payloadJson);
            return "ok";
        }
        function close(): string {
            root.close();
            return "ok";
        }
        function state(): string {
            return root.opened ? "open" : "closed";
        }
        function ping(): string {
            return "ok";
        }
    }
    Timer {
        interval: 2000
        running: root.opened
        onTriggered: root.opened = false
    }
}
