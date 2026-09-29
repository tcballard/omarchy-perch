import QtQuick
import Quickshell
import Quickshell.Io
import "PreferencesPolicy.js" as Prefs

Item {
    id: root
    property var shell: null
    property var record: ({})
    readonly property var values: Prefs.clean(record)
    property bool ready: false
    property string error: ""
    signal loaded
    function accept(encoded) {
        var found = Prefs.entry(encoded);
        if (found === null) {
            error = "Could not read Perch settings. No changes saved.";
            ready = false;
            return false;
        }
        record = found;
        ready = true;
        error = "";
        loaded();
        return true;
    }
    function update(patch) {
        if (!ready || !shell || typeof shell.updateEntryInline !== "function") {
            error = "Settings are not ready. Try again after the shell loads.";
            return false;
        }
        var next = Object.assign({}, record, patch);
        if (JSON.stringify(next) === JSON.stringify(record))
            return true;
        try {
            // Host performs the scoped merge and owns shell.json IO.
            if (!shell.updateEntryInline("io.github.tcballard.perch", next)) {
                error = "Settings were not saved. Try again.";
                return false;
            }
            record = next;
            error = "";
            return true;
        } catch (_) {
            error = "Settings could not be saved.";
            return false;
        }
    }
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.accept(text())
        onLoadFailed: {
            root.ready = false;
            root.error = "Could not read shell settings.";
        }
    }
}
