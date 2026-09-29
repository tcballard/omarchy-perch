pragma Singleton
import QtQuick
QtObject { property QtObject defaultAudioSink: QtObject {
    property string name: "test-sink"
    property string description: "Test speakers"
    property QtObject audio: QtObject { property real volume: 0.4; property bool muted: false }
} }
