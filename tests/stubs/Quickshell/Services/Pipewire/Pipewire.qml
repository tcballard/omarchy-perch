pragma Singleton
import QtQuick
QtObject {
    property var nodes: ({values:[defaultAudioSink,defaultAudioSource]})
    property var preferredDefaultAudioSink: null
    property var preferredDefaultAudioSource: null
    property QtObject defaultAudioSource: QtObject {
        property string name:"test-mic"
        property string description:"Test microphone"
        property bool isStream:false
        property bool isSink:false
        property QtObject audio:QtObject {property real volume:0.5;property bool muted:false}
    }
    property QtObject defaultAudioSink: QtObject {
    property bool isStream:false
    property bool isSink:true
    property string name: "test-sink"
    property string description: "Test speakers"
    property QtObject audio: QtObject { property real volume: 0.4; property bool muted: false }
} }
