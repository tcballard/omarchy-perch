import QtQuick
import "ModulePolicy.js" as Modules

Item {
    id: root
    property var preferences: null
    property string instanceId: ""
    property bool statsVisible: false
    property bool clipboardVisible: false
    property bool weatherVisible: false
    readonly property var config: preferences ? preferences.record : ({})
    readonly property var weatherConfig: (instanceId ? (config.weatherInstances || {})[instanceId] : config.moduleWeather) || ({})
    readonly property string weatherKey: JSON.stringify(weatherConfig)
    readonly property bool weatherEnabled: weatherConfig.enabled === true
    property var sample: null
    property var previousSample: null
    property real cpu: -1
    property var cpuHistory: []
    property var coreUsage: []
    property string statsError: ""
    readonly property bool statsBusy: statsJob.busy
    property var clips: []
    property int clipCount: 0
    property string query: ""
    property string kind: "all"
    property string clipboardError: ""
    property string copyMessage: ""
    readonly property bool clipboardBusy: clipboardJob.busy || copyJob.busy
    property string clipboardRequest: ""
    property var weather: null
    property string weatherError: ""
    property var locations: []
    property string locationError: ""
    readonly property bool locationBusy: locationJob.busy
    readonly property string temperatureUnit: weatherConfig.unit === "F" ? "F" : "C"
    function temperature(value) {
        return Math.round(temperatureUnit === "F" ? value * 9 / 5 + 32 : value) + "°" + temperatureUnit;
    }
    function searchLocation(query) {
        locations = [];
        locationError = "";
        return locationJob.run("dock-weather-search", {
            query: query
        });
    }
    function setUnit(unit) {
        return saveWeatherConfig(Object.assign({}, weatherConfig, {
            unit: unit === "F" ? "F" : "C"
        }));
    }
    ToolJob {
        id: locationJob
        onCompleted: (op, r) => {
            root.locations = r.ok ? r.rows : [];
            root.locationError = r.ok ? (r.rows.length ? "" : "No locations found") : r.error;
        }
    }
    property string requestedWeatherKey: ""
    property real weatherUpdated: 0
    readonly property bool weatherBusy: weatherJob.busy
    readonly property int statsInterval: [2, 5, 10].indexOf(config.moduleStatsInterval) >= 0 ? config.moduleStatsInterval : 5
    function acceptStats(s) {
        if (!s || !isFinite(s.total) || !isFinite(s.idle))
            return;
        var delta = previousSample ? s.total - previousSample.total : 0;
        cpu = delta > 0 ? Math.max(0, Math.min(100, 100 * (1 - (s.idle - previousSample.idle) / delta))) : -1;
        coreUsage = Array.isArray(s.cores) && previousSample && Array.isArray(previousSample.cores) ? s.cores.map((c, i) => {
            var old = previousSample.cores[i], delta = old ? c.total - old.total : 0;
            return delta > 0 ? Math.max(0, Math.min(100, 100 * (1 - (c.idle - old.idle) / delta))) : -1;
        }) : [];
        previousSample = s;
        sample = s;
        if (cpu >= 0)
            cpuHistory = cpuHistory.concat([cpu]).slice(-30);
    }
    function refreshStats() {
        if (!statsJob.busy)
            statsJob.run("module-stats", {});
    }
    function refreshClipboard() {
        if (clipboardJob.busy)
            return;
        clipboardRequest = query + "|" + kind;
        clipboardJob.run("module-clipboard", {
            query: query,
            kind: kind
        });
    }
    function copyClip(id) {
        copyMessage = "";
        if (!clipboardBusy)
            copyJob.run("module-copy", {
                id: id
            });
    }
    function refreshWeather() {
        if (!weatherEnabled || weatherJob.busy)
            return;
        requestedWeatherKey = weatherKey;
        weatherError = "";
        weatherJob.run("module-weather", {
            latitude: weatherConfig.latitude,
            longitude: weatherConfig.longitude
        });
    }
    function saveWeatherConfig(value) {
        if (!preferences)
            return false;
        if (!instanceId)
            return preferences.update({
                moduleWeather: value
            });
        var instances = Object.assign({}, config.weatherInstances || {});
        instances[instanceId] = value;
        return preferences.update({
            weatherInstances: instances
        });
    }
    function saveWeather(name, latitude, longitude, enabled) {
        if (!preferences)
            return false;
        if (enabled && (String(latitude).trim() === "" || String(longitude).trim() === "" || !isFinite(Number(latitude)) || !isFinite(Number(longitude)) || Math.abs(Number(latitude)) > 90 || Math.abs(Number(longitude)) > 180)) {
            weatherError = "Enter a latitude (−90 to 90) and longitude (−180 to 180).";
            return false;
        }
        return saveWeatherConfig({
            name: String(name).slice(0, 80),
            latitude: Number(latitude),
            longitude: Number(longitude),
            enabled: enabled,
            unit: temperatureUnit
        });
    }
    onStatsVisibleChanged: {
        previousSample = null;
        cpu = -1;
        if (statsVisible)
            refreshStats();
    }
    onClipboardVisibleChanged: {
        if (clipboardVisible)
            refreshClipboard();
        else {
            clips = [];
            query = "";
            copyMessage = "";
        }
    }
    onQueryChanged: if (clipboardVisible)
        searchDelay.restart()
    onKindChanged: if (clipboardVisible)
        searchDelay.restart()
    onWeatherVisibleChanged: if (weatherVisible && Date.now() - weatherUpdated > 900000)
        refreshWeather()
    onWeatherKeyChanged: {
        weather = null;
        weatherUpdated = 0;
        weatherError = "";
        if (weatherVisible)
            weatherDelay.restart();
    }
    ToolJob {
        id: statsJob
        onCompleted: function (op, r) {
            root.statsError = r.ok ? "" : r.error;
            if (r.ok && root.statsVisible)
                root.acceptStats(r.sample);
        }
    }
    ToolJob {
        id: clipboardJob
        onCompleted: function (op, r) {
            if (!root.clipboardVisible)
                return;
            if (root.clipboardRequest !== root.query + "|" + root.kind) {
                searchDelay.restart();
                return;
            }
            root.clipboardError = r.ok ? "" : r.error;
            root.clips = r.ok ? r.rows : [];
            root.clipCount = r.ok ? r.count : 0;
        }
    }
    ToolJob {
        id: copyJob
        onCompleted: function (op, r) {
            root.clipboardError = r.ok ? "" : r.error;
            root.copyMessage = r.ok ? r.message : "";
        }
    }
    ToolJob {
        id: weatherJob
        onCompleted: function (op, r) {
            if (root.requestedWeatherKey !== root.weatherKey) {
                weatherDelay.restart();
                return;
            }
            root.weatherError = r.ok ? "" : "Weather unavailable. Check your connection and retry.";
            if (r.ok) {
                root.weather = r.weather;
                root.weatherUpdated = Date.now();
            }
        }
    }
    Timer {
        id: searchDelay
        interval: 180
        onTriggered: if (root.clipboardVisible)
            root.refreshClipboard()
    }
    Timer {
        id: weatherDelay
        interval: 200
        onTriggered: if (root.weatherVisible)
            root.refreshWeather()
    }
    Timer {
        interval: root.statsInterval * 1000
        repeat: true
        running: root.statsVisible
        onTriggered: root.refreshStats()
    }
    Timer {
        interval: 3000
        repeat: true
        running: root.clipboardVisible
        onTriggered: root.refreshClipboard()
    }
    Timer {
        interval: 900000
        repeat: true
        running: root.weatherVisible && root.weatherEnabled
        onTriggered: root.refreshWeather()
    }
}
