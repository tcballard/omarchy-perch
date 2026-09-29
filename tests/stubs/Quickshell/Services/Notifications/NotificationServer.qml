import QtQuick
QtObject {
    property bool inlineReplySupported:false
    property bool actionsSupported: false
    property bool bodyMarkupSupported: false
    property bool bodyHyperlinksSupported: false
    property bool imageSupported: false
    property bool persistenceSupported: false
    property bool keepOnReload: false
    signal notification(var notification)
}
