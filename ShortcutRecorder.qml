import QtQuick

PerchAction {
    id: root
    property string sequence: ""
    property bool recording: false
    signal recorded(string chord)
    text: recording ? PerchStrings.t("Press Ctrl+Alt+key…") : sequence || PerchStrings.t("Record")
    Accessible.name: recording ? "Press Control Alt and a letter or digit; Escape cancels" : "Record shortcut " + sequence
    selected: recording
    onClicked: {
        recording = true;
        forceActiveFocus();
    }
    onActiveFocusChanged: if (!activeFocus)
        recording = false
    onVisibleChanged: if (!visible)
        recording = false
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: event => {
        if (!recording)
            return;
        event.accepted = true;
        if (event.key === Qt.Key_Escape) {
            recording = false;
            return;
        }
        if (event.isAutoRepeat)
            return;
        if (event.modifiers === (Qt.ControlModifier | Qt.AltModifier) && (event.key >= Qt.Key_A && event.key <= Qt.Key_Z || event.key >= Qt.Key_0 && event.key <= Qt.Key_9)) {
            recorded("Ctrl+Alt+" + String.fromCharCode(event.key));
            recording = false;
        }
    }
}
