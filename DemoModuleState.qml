import QtQuick

QtObject {
    property var preferences: null
    property bool statsVisible: false
    property bool clipboardVisible: false
    property bool weatherVisible: false
    property var sample: ({
            memory: 42,
            disk: 63
        })
    property real cpu: 24
    property var cpuHistory: [12, 18, 32, 24, 46, 39, 23, 24, 18, 15, 21, 24]
    property int statsInterval: 5
    property string statsError: ""
    property bool statsBusy: false
    property string query: ""
    property string kind: "all"
    property var sourceClips: [
        {
            id: "demo-1",
            kind: "text",
            preview: "Review Perch’s native module cards"
        },
        {
            id: "demo-2",
            kind: "link",
            preview: "https://omarchy.org"
        },
        {
            id: "demo-3",
            kind: "image",
            preview: "Image · fictional screenshot"
        }
    ]
    readonly property var clips: sourceClips.filter(function (c) {
        return (kind === "all" || c.kind === kind) && c.preview.toLowerCase().indexOf(query.toLowerCase()) >= 0;
    })
    property int clipCount: 3
    property string clipboardError: ""
    property string copyMessage: ""
    property bool clipboardBusy: false
    property bool weatherEnabled: true
    property var weatherConfig: ({
            name: "Demo location",
            latitude: 51.5,
            longitude: -0.1,
            enabled: true
        })
    property var weather: ({
            temperature: 18,
            code: 2,
            wind: 12,
            hours: [
                {
                    time: "2026-09-29T16:00",
                    temperature: 18
                },
                {
                    time: "2026-09-29T17:00",
                    temperature: 17
                },
                {
                    time: "2026-09-29T18:00",
                    temperature: 16
                },
                {
                    time: "2026-09-29T19:00",
                    temperature: 15
                },
                {
                    time: "2026-09-29T20:00",
                    temperature: 14
                },
                {
                    time: "2026-09-29T21:00",
                    temperature: 13
                }
            ]
        })
    property string weatherError: ""
    property bool weatherBusy: false
    property real weatherUpdated: new Date(2026, 8, 29, 16, 0).getTime()
    function refreshStats() {
    }
    function refreshClipboard() {
    }
    function refreshWeather() {
    }
    function copyClip(id) {
        copyMessage = "Demo copy · the real clipboard is unchanged";
    }
    function saveWeather(name, latitude, longitude, enabled) {
        weatherConfig = {
            name: name,
            latitude: Number(latitude),
            longitude: Number(longitude),
            enabled: enabled
        };
        weatherEnabled = enabled;
        return true;
    }
}
