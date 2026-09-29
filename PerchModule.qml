import QtQuick

// Native module contract. Components are supplied by trusted repository code,
// never by preferences or incoming IPC. State belongs to the shared service.
QtObject {
    property string moduleId: ""
    property string title: ""
    property string compactText: title
    property string status: "ready"
    property var state: null
    property Component card: null
    property Component settings: null
    property var actions: []
}
