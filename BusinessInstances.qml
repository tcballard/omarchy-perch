import QtQuick
import QtQml.Models
import "BusinessPolicy.js" as Business

Item {
    id: root
    property var preferences: null
    property var manager: null
    property var activeIds: []
    readonly property string idsKey: Object.keys(Business.tiles(preferences ? preferences.record.businessTiles : {})).filter(id => id !== "business").join("|")
    readonly property var ids: idsKey ? idsKey.split("|") : []
    property int revision: 0
    function get(id) {
        var dependency = revision;
        for (var i = 0; i < instances.count; i++) {
            var obj = instances.objectAt(i);
            if (obj && obj.instanceId === id)
                return obj;
        }
        return null;
    }
    Instantiator {
        id: instances
        model: root.ids
        delegate: BusinessState {
            required property string modelData
            instanceId: modelData
            preferences: root.preferences
            manager: root.manager
            active: root.activeIds.indexOf(modelData) >= 0
        }
        onObjectAdded: root.revision++
        onObjectRemoved: root.revision++
    }
}
