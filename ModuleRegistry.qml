import QtQuick
import "MediaPolicy.js" as Media

Item {
    id: root
    property var state: null
    required property var host
    BuiltinCards {
        id: builtins
        host: root.host
    }
    readonly property var modules: [usage, clipboard, stats, weather, module_hub, module_shelf, module_calendar, module_setup, module_inbox, module_lyrics, module_desktop, module_timer, module_system, module_activity, module_players, module_music]
    PerchModule {
        id: usage
        moduleId: "usage"
        title: "AI usage"
        compactText: "Usage"
        card: Component {
            UsageCard {
                state: root.host.media && root.host.media.usage !== undefined ? root.host.media.usage : null
            }
        }
    }
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
    PerchModule {
        id: module_hub
        moduleId: "hub"
        title: "All tools"
        compactText: title
        state: root.host.media
        card: builtins.hubCard
    }
    PerchModule {
        id: module_shelf
        moduleId: "shelf"
        title: "Files"
        compactText: title
        state: root.host.media
        card: builtins.shelfCard
    }
    PerchModule {
        id: module_calendar
        moduleId: "calendar"
        title: "Calendar"
        compactText: root.host.work && root.host.work.meetingSummary ? root.host.work.meetingSummary : "Calendar"
        state: root.host.media
        card: builtins.calendarCard
    }
    PerchModule {
        id: module_setup
        moduleId: "setup"
        title: "Setup & health"
        compactText: title
        state: root.host.media
        card: builtins.setupCard
    }
    PerchModule {
        id: module_inbox
        moduleId: "inbox"
        title: "Notifications"
        compactText: root.host.notificationPreview || "Inbox"
        state: root.host.media
        card: builtins.inboxCard
    }
    PerchModule {
        id: module_lyrics
        moduleId: "lyrics"
        title: "Lyrics"
        compactText: title
        state: root.host.media
        card: builtins.lyricsCard
    }
    PerchModule {
        id: module_desktop
        moduleId: "desktop"
        title: "Desktop"
        compactText: title
        state: root.host.media
        card: builtins.desktopCard
    }
    PerchModule {
        id: module_timer
        moduleId: "timer"
        title: "Timer"
        compactText: root.host.live && root.host.live.timerActive ? (root.host.live.timerStatus === "done" ? "Finished" : Media.time(root.host.live.remaining)) : "Timers"
        state: root.host.media
        card: builtins.timerCard
    }
    PerchModule {
        id: module_system
        moduleId: "system"
        title: "Devices"
        compactText: root.host.displaySettings.systemFeedback !== false && root.host.system && root.host.system.banner ? root.host.system.banner : "Devices"
        state: root.host.media
        card: builtins.systemCard
    }
    PerchModule {
        id: module_activity
        moduleId: "activity"
        title: "Activity"
        compactText: root.host.live && root.host.live.focused ? root.host.live.focused.title : "Activity"
        state: root.host.media
        card: builtins.activityCard
    }
    PerchModule {
        id: module_players
        moduleId: "players"
        title: "Players"
        compactText: title
        state: root.host.media
        card: builtins.playersCard
    }
    PerchModule {
        id: module_music
        moduleId: "music"
        title: "Music"
        compactText: root.host.hasPlayer ? root.host.media.title : "Music"
        state: root.host.media
        card: builtins.musicCard
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
