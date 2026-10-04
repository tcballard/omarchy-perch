import QtQuick
import QtQml.Models
import "MediaPolicy.js" as Media

Item {
    id: root
    property var state: null
    required property var host
    BuiltinCards {
        id: builtins
        host: root.host
    }
    readonly property var modules: [trash, business, storage, dockEditor, reminders, hydration, windows, folder, usage, clipboard, stats, weather, module_hub, module_shelf, module_calendar, module_setup, module_inbox, module_lyrics, module_desktop, module_timer, module_system, module_activity, module_players, module_music]
    PerchModule {
        id: usage
        moduleId: "usage"
        title: PerchStrings.t("AI usage")
        compactText: {
            var usage = root.host.media && root.host.media.usage !== undefined ? root.host.media.usage : null;
            var source = usage ? usage.sources.find(p => p.windows.length) : null;
            return source ? source.name + " " + Math.round(100 - source.windows[0].used) + "%" : "Usage";
        }
        card: Component {
            UsageCard {
                state: root.host.media && root.host.media.usage !== undefined ? root.host.media.usage : null
            }
        }
    }
    PerchModule {
        id: dockEditor
        moduleId: "dock"
        title: "Your dock"
        compactText: "Edit dock"
        card: Component {
            DockEditor {
                state: root.host.dockState
                registry: root
                pluginState: root.host.pluginState
            }
        }
    }
    PerchModule {
        id: reminders
        moduleId: "reminders"
        title: "Reminders"
        compactText: root.host.utilityState ? root.host.utilityState.remainingCount + " remaining" : "Reminders"
        card: Component {
            RemindersCard {
                state: root.host.utilityState
            }
        }
    }
    PerchModule {
        id: hydration
        moduleId: "hydration"
        title: "Hydration"
        compactText: root.host.utilityState ? (root.host.utilityState.drinkDue ? "Time for water" : root.host.utilityState.todayVolume + " mL") : "Water"
        card: Component {
            HydrationCard {
                state: root.host.utilityState
            }
        }
    }
    PerchModule {
        id: windows
        moduleId: "windows"
        title: "Running windows"
        compactText: root.host.utilityState ? root.host.utilityState.windows.length + " windows" : "Windows"
        card: Component {
            WindowsCard {
                state: root.host.utilityState
            }
        }
    }
    PerchModule {
        id: folder
        moduleId: "folder"
        title: "Browse folder"
        card: Component {
            FolderCard {
                state: root.host.dockState
            }
        }
    }
    PerchModule {
        id: storage
        moduleId: "storage"
        title: "Storage"
        compactText: "Storage"
        card: Component {
            StorageCard {
                state: root.host.utilityState
            }
        }
    }
    PerchModule {
        id: business
        moduleId: "business"
        title: "Business"
        compactText: root.host.businessState && root.host.businessState.report ? root.host.businessState.report.provider : "Business"
        card: Component {
            BusinessCard {
                state: root.host.businessState
            }
        }
    }
    property int instanceRevision: 0
    Instantiator {
        id: weatherDefinitions
        model: root.host.weatherInstances ? root.host.weatherInstances.ids : []
        delegate: PerchModule {
            id: definition
            required property string modelData
            moduleId: modelData
            title: "Weather"
            state: root.host.weatherInstances ? root.host.weatherInstances.get(modelData) : null
            compactText: state && state.weather ? state.temperature(state.weather.temperature) : "Weather"
            compactDetail: state ? state.weatherConfig.name || "Choose a city" : ""
            card: Component {
                WeatherCard {
                    state: definition.state
                }
            }
            settings: Component {
                WeatherSettings {
                    state: definition.state
                }
            }
        }
        onObjectAdded: root.instanceRevision++
        onObjectRemoved: root.instanceRevision++
    }
    PerchModule {
        id: trash
        moduleId: "trash"
        title: "Trash"
        compactText: root.host.utilityState ? (root.host.utilityState.trashPartial ? "≥ " : "") + root.host.utilityState.trashCount + " items" : "Trash"
        card: Component {
            TrashCard {
                state: root.host.utilityState
            }
        }
    }
    function get(id) {
        var dependency = instanceRevision;
        for (var i = 0; i < weatherDefinitions.count; i++) {
            var item = weatherDefinitions.objectAt(i);
            if (item && item.moduleId === id)
                return item;
        }

        return modules.find(function (m) {
            return m.moduleId === id;
        }) || null;
    }
    PerchModule {
        id: clipboard
        moduleId: "clipboard"
        title: PerchStrings.t("Clipboard")
        compactText: PerchStrings.t("Clipboard")
        state: root.state
        status: !state ? "unavailable" : state.clipboardError ? "error" : state.clipboardBusy ? "loading" : state.clips.length ? "ready" : "empty"
        actions: [
            {
                id: "refresh",
                title: PerchStrings.t("Refresh")
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
        compactDetail: state && state.sample ? "RAM " + Math.round(state.sample.memory) + "%" : "System activity"
        fraction: state && state.cpu >= 0 ? state.cpu / 100 : -1
        title: PerchStrings.t("System stats")
        compactText: state && !state.statsError && state.cpu >= 0 ? "CPU " + Math.round(state.cpu) + "%" : PerchStrings.t("Stats")
        state: root.state
        status: !state ? "unavailable" : state.statsError ? "error" : state.sample ? "ready" : "loading"
        actions: [
            {
                id: "refresh",
                title: PerchStrings.t("Refresh")
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
        compactDetail: state && state.weather ? (state.weatherConfig.name || "Weather") + " · " + state.weather.wind + " km/h" : "Choose a city"
        title: PerchStrings.t("Weather")
        compactText: state && state.weather && !state.weatherError ? (state.temperature ? state.temperature(state.weather.temperature) : Math.round(state.weather.temperature) + "°C") : PerchStrings.t("Weather")
        state: root.state
        status: !state ? "unavailable" : !state.weatherEnabled ? "unconfigured" : state.weatherError ? "offline" : state.weather ? "ready" : "loading"
        actions: [
            {
                id: "refresh",
                title: PerchStrings.t("Refresh")
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
        title: PerchStrings.t("Files")
        compactText: title
        state: root.host.media
        card: builtins.shelfCard
    }
    PerchModule {
        id: module_calendar
        moduleId: "calendar"
        compactDetail: root.host.work && root.host.work.nextEvent ? root.host.work.nextEvent.title : "No upcoming meeting"
        title: PerchStrings.t("Calendar")
        compactText: root.host.work && root.host.work.meetingSummary ? root.host.work.meetingSummary : PerchStrings.t("Calendar")
        state: root.host.media
        card: builtins.calendarCard
    }
    PerchModule {
        id: module_setup
        moduleId: "setup"
        title: PerchStrings.t("Setup & health")
        compactText: title
        state: root.host.media
        card: builtins.setupCard
    }
    PerchModule {
        id: module_inbox
        moduleId: "inbox"
        title: PerchStrings.t("Notifications")
        compactText: root.host.notificationPreview || PerchStrings.t("Inbox")
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
        compactDetail: root.host.live && root.host.live.timerActive ? root.host.live.timerLabel || "Timer running" : "Start a focus timer"
        title: PerchStrings.t("Timer")
        compactText: root.host.live && root.host.live.timerActive ? (root.host.live.timerStatus === "done" ? "Finished" : Media.time(root.host.live.remaining)) : PerchStrings.t("Timers")
        state: root.host.media
        card: builtins.timerCard
    }
    PerchModule {
        id: module_system
        moduleId: "system"
        title: PerchStrings.t("Devices")
        compactText: root.host.displaySettings.systemFeedback !== false && root.host.system && root.host.system.banner ? root.host.system.banner : PerchStrings.t("Devices")
        state: root.host.media
        card: builtins.systemCard
    }
    PerchModule {
        id: module_activity
        moduleId: "activity"
        compactDetail: root.host.live && root.host.live.attentionItems ? root.host.live.attentionItems.length + " need attention" : "Agent sessions"
        title: PerchStrings.t("Activity")
        compactText: root.host.live && root.host.live.focused ? root.host.live.focused.title : PerchStrings.t("Activity")
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
        compactDetail: root.host.hasPlayer ? root.host.media.artist : "Play something"
        title: PerchStrings.t("Music")
        compactText: root.host.hasPlayer ? root.host.media.title : PerchStrings.t("Music")
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
