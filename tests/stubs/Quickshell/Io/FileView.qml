import QtQuick
Item {
    property string path: ""
    property bool watchChanges: false
    property string contents: '{"plugins":[{"id":"io.github.tcballard.perch"}]}'
    signal loaded()
    signal fileChanged()
    signal loadFailed()
    function text() { return contents }
    function reload() { loaded() }
    Component.onCompleted: loaded()
}
