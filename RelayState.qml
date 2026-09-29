import QtQuick
import Quickshell.Io

Item {
    id: root
    property var preferences: null
    property var live: null
    readonly property bool optedIn: !!preferences && preferences.values.remoteStatus === true
    property string endpoint: ""
    property string error: ""
    readonly property bool running: endpoint !== "" && worker.running
    function setEnabled(value) {
        if (preferences)
            preferences.update({
                remoteStatus: value
            });
    }
    function reconcile() {
        endpoint = "";
        error = "";
        if (optedIn && !worker.running)
            worker.running = true;
        else if (!optedIn && worker.running)
            worker.signal(15);
    }
    onOptedInChanged: reconcile()
    Component.onCompleted: reconcile()
    Process {
        id: worker
        command: ["/usr/bin/python3", "-I", decodeURIComponent(Qt.resolvedUrl("scripts/perch-relay").toString().replace(/^file:\/\//, "")), "serve"]
        stdout: SplitParser {
            onRead: data => {
                if (!root.optedIn || data.length > 8192)
                    return;
                try {
                    var message = JSON.parse(data);
                    if (typeof message.ready === "string")
                        root.endpoint = message.ready;
                    else if (typeof message.error === "string")
                        root.error = message.error;
                    else if (message.event && root.live)
                        root.live.activity(JSON.stringify(message.event));
                } catch (_) {
                    root.error = "Invalid relay response";
                }
            }
        }
        onExited: (code, status) => {
            root.endpoint = "";
            if (root.optedIn)
                root.error = root.error || "Receiver stopped. Disable and enable it to retry.";
        }
    }
}
