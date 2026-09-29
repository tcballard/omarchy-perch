import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "MediaPolicy.js" as Media

Item {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool audioAvailable: !!(sink && sink.audio)
    readonly property real volume: audioAvailable ? sink.audio.volume : 0
    readonly property bool muted: audioAvailable ? sink.audio.muted : false
    readonly property string outputName: audioAvailable ? Media.bounded(sink.description || sink.name, "Audio output") : "No audio output"
    readonly property var device: UPower.displayDevice
    readonly property bool batteryAvailable: !!(device && device.isPresent && isFinite(device.percentage))
    readonly property int batteryPercent: batteryAvailable ? Math.round(Math.max(0, Math.min(1, device.percentage)) * 100) : 0
    readonly property bool charging: batteryAvailable && device.state === UPowerDeviceState.Charging
    readonly property bool onBattery: UPower.onBattery
    property bool initialized: false
    property string error: ""
    property string banner: ""
    property string bannerKind: ""
    function showBanner(text, kind) {
        if (!initialized)
            return;
        banner = text;
        bannerKind = kind;
        clearBanner.restart();
    }
    function setVolume(value) {
        if (!audioAvailable || !isFinite(value))
            return false;
        try {
            sink.audio.volume = Math.max(0, Math.min(1, value));
            error = "";
            return true;
        } catch (_) {
            error = "Audio output did not accept the change";
            return false;
        }
    }
    function toggleMute() {
        if (!audioAvailable)
            return false;
        try {
            sink.audio.muted = !sink.audio.muted;
            error = "";
            return true;
        } catch (_) {
            error = "Audio output did not accept the change";
            return false;
        }
    }
    PwObjectTracker {
        objects: [root.sink]
    }
    onVolumeChanged: volumeBanner.restart()
    onMutedChanged: volumeBanner.restart()
    onOnBatteryChanged: if (batteryAvailable)
        showBanner(onBattery ? "On battery · " + batteryPercent + "%" : "Power connected · " + batteryPercent + "%", "battery")
    Timer {
        interval: 1500
        running: true
        onTriggered: root.initialized = true
    }
    Timer {
        id: volumeBanner
        interval: 120
        onTriggered: if (root.audioAvailable)
            root.showBanner(root.muted ? "Sound muted" : "Volume · " + Math.round(root.volume * 100) + "%", "volume")
    }
    Timer {
        id: clearBanner
        interval: 2000
        onTriggered: {
            root.banner = "";
            root.bannerKind = "";
        }
    }
}
