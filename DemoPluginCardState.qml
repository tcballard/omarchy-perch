import QtQuick

QtObject {
    property string selectedId: ""
    property var card: null
    property string error: ""
    property string message: ""
    property bool busy: false
    property string lastAction: ""
    function select(id) { selectedId = id; refresh(); }
    function clear() { selectedId = ""; card = null; error = ""; message = ""; }
    function refresh() {
        if (!selectedId) return;
        error = ""; message = "";
        card = {version: 1, revision: "demo", title: "RSS Feed", status: "ready", summary: "2 unread · fictional headlines",
            actions: [{id: "refresh", label: "Refresh feeds"}], rows: [
                {id: "first", title: "A calmer home for your plugins", detail: "Example feed · today", action: {id: "open:0", label: "Read article"}},
                {id: "second", title: "The next release is ready to try", detail: "Example feed · today", action: {id: "open:1", label: "Read article"}}
            ]};
    }
    function act(id) { lastAction = id; message = "Demo only · no external action performed"; }
}
