import QtQuick

Item {
    id: root
    property var state: null
    readonly property var modules: [clipboard, stats, weather]
    function get(id) {
        return modules.find(function (m) {
            return m.moduleId === id;
        }) || null;
    }
    PerchModule {
        id: clipboard
        moduleId: "clipboard"
        title: "Clipboard"
        compactText: "Clipboard"
        state: root.state
        status: !state ? "unavailable" : state.clipboardError ? "error" : state.clipboardBusy ? "loading" : state.clips.length ? "ready" : "empty"
        actions: [
            {
                id: "refresh",
                title: "Refresh"
            }
        ]
        card: Component {
            ClipboardCard {
                state: root.state
            }
        }
    }
    PerchModule {
        id: stats
        moduleId: "stats"
        title: "System stats"
        compactText: state && !state.statsError && state.cpu >= 0 ? "CPU " + Math.round(state.cpu) + "%" : "Stats"
        state: root.state
        status: !state ? "unavailable" : state.statsError ? "error" : state.sample ? "ready" : "loading"
        actions: [
            {
                id: "refresh",
                title: "Refresh"
            }
        ]
        card: Component {
            StatsCard {
                state: root.state
            }
        }
        settings: Component {
            StatsSettings {
                state: root.state
            }
        }
    }
    PerchModule {
        id: weather
        moduleId: "weather"
        title: "Weather"
        compactText: state && state.weather && !state.weatherError ? Math.round(state.weather.temperature) + "°C" : "Weather"
        state: root.state
        status: !state ? "unavailable" : !state.weatherEnabled ? "unconfigured" : state.weatherError ? "offline" : state.weather ? "ready" : "loading"
        actions: [
            {
                id: "refresh",
                title: "Refresh"
            }
        ]
        card: Component {
            WeatherCard {
                state: root.state
            }
        }
        settings: Component {
            WeatherSettings {
                state: root.state
            }
        }
    }
    function action(id, actionId) {
        if (!state || actionId !== "refresh")
            return;
        if (id === "clipboard")
            state.refreshClipboard();
        if (id === "stats")
            state.refreshStats();
        if (id === "weather")
            state.refreshWeather();
    }
}
