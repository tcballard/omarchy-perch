import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "MediaPolicy.js" as Media

Item {
    id: root
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var outputs: Pipewire.nodes ? Pipewire.nodes.values.filter(function (n) {
        return !n.isStream && n.isSink && n.audio;
    }) : []
    readonly property var inputs: Pipewire.nodes ? Pipewire.nodes.values.filter(function (n) {
        return !n.isStream && !n.isSink && n.audio;
    }) : []
    readonly property bool microphoneAvailable: !!(source && source.audio)
    readonly property bool microphoneMuted: microphoneAvailable ? source.audio.muted : false
    readonly property var bluetoothDevices: Bluetooth.devices ? Bluetooth.devices.values.filter(function (d) {
        return d.paired || d.connected;
    }) : []
    property string lastBluetooth: ""
    readonly property string bluetoothSnapshot: bluetoothDevices.map(function (d) {
        return d.name + ":" + d.connected;
    }).join("|")
    onBluetoothSnapshotChanged: {
        if (initialized && lastBluetooth !== bluetoothSnapshot)
            showBanner("Bluetooth devices updated", "bluetooth");
        lastBluetooth = bluetoothSnapshot;
    }
    function selectOutput(index) {
        if (index < 0 || index >= outputs.length)
            return false;
        try {
            Pipewire.preferredDefaultAudioSink = outputs[index];
            error = "";
            return true;
        } catch (_) {
            error = "Output change unavailable";
            return false;
        }
    }
    function selectInput(index) {
        if (index < 0 || index >= inputs.length)
            return false;
        try {
            Pipewire.preferredDefaultAudioSource = inputs[index];
            error = "";
            return true;
        } catch (_) {
            error = "Input change unavailable";
            return false;
        }
    }
    function toggleMicrophone() {
        if (!microphoneAvailable)
            return false;
        try {
            source.audio.muted = !source.audio.muted;
            error = "";
            return true;
        } catch (_) {
            error = "Microphone change unavailable";
            return false;
        }
    }
    function toggleBluetooth(index) {
        if (index < 0 || index >= bluetoothDevices.length)
            return false;
        try {
            var d = bluetoothDevices[index];
            d.connected = !d.connected;
            return true;
        } catch (_) {
            error = "Bluetooth request failed";
            return false;
        }
    }
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
        objects: root.outputs.concat(root.inputs).concat([root.sink, root.source]).filter(function (n) {
            return !!n;
        })
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
