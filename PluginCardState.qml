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
    signal handoffRequested
    property var pendingHandoff: null
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
        var actions = card.actions.concat(card.rows.map(function(row) { return row.action; }).filter(function(action) { return !!action; }));
        var action = actions.find(function(item) { return item.id === id; });
        if (!action)
            return false;
        if (action.handoff === true) {
            if (pendingHandoff)
                return false;
            pendingHandoff = {id: selectedId, revision: card.revision, action: id, generation: generation};
            handoffRequested();
            handoffDelay.start();
            return true;
        }
        requestGeneration = generation;
        error = "";
        message = "";
        return job.run("card-action", {id: selectedId, revision: card.revision, action: id});
    }
    Timer {
        id: handoffDelay
        interval: 250
        repeat: false
        onTriggered: {
            var request = root.pendingHandoff;
            root.pendingHandoff = null;
            if (!request)
                return;
            // Service state survives closing the Perch panel. The backend
            // revalidates the provider, revision and action before dispatch.
            root.requestGeneration = request.generation;
            job.run("card-action", {id: request.id, revision: request.revision, action: request.action});
        }
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
