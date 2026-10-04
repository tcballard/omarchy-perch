import QtQuick
import QtQml.Models

Item {
    id: root
    property var preferences: null
    property var activeIds: []
    readonly property var ids: preferences ? Object.keys(preferences.record.weatherInstances || {}).filter(id => /^weather:[a-z0-9-]{1,32}$/.test(id)).slice(0, 4) : []
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
        delegate: ModuleState {
            required property string modelData
            instanceId: modelData
            preferences: root.preferences
            weatherVisible: root.activeIds.indexOf(modelData) >= 0
        }
        onObjectAdded: root.revision++
        onObjectRemoved: root.revision++
    }
}
