import QtQuick

Item {
    id: root
    property string selectedId: ""
    property var card: null
    property string error: ""
    property string message: ""
    property int generation: 0
    property int requestGeneration: 0
    readonly property bool busy: job.busy
    function select(id) {
        generation++;
        selectedId = id;
        card = null;
        error = "";
        message = "";
        refresh();
    }
    function clear() {
        generation++;
        selectedId = "";
        card = null;
        error = "";
        message = "";
    }
    function refresh() {
        if (!selectedId || busy)
            return false;
        requestGeneration = generation;
        error = "";
        message = "";
        card = null;
        return job.run("card-read", {id: selectedId});
    }
    function act(id) {
        if (!card || busy || !selectedId)
            return false;
        requestGeneration = generation;
        error = "";
        message = "";
        return job.run("card-action", {id: selectedId, revision: card.revision, action: id});
    }
    ToolJob {
        id: job
        objectName: "plugin-card-job"
        timeout: 12000
        onCompleted: function(op, result) {
            if (root.requestGeneration !== root.generation) {
                // Navigating to another pin queues only the latest selection.
                Qt.callLater(function() { root.refresh(); });
                return;
            }
            root.card = result.ok ? result.card || null : null;
            root.error = result.ok ? "" : result.error || "Could not load this plugin card";
            root.message = result.message || "";
        }
    }
}
