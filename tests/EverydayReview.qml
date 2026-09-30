import QtQuick
import ".."
Rectangle {
    width: 800; height: 625; color: "#202831"
    DemoMedia { id: demo }
    Text { x: 28; y: 24; text: "PERCH / TOOLS & PLUGINS"; color: "#e9edf4"; font.pixelSize: 23 }
    NotchView {
        id: tools
        x: 28; y: 90; width: implicitWidth; height: implicitHeight
        media: demo; expanded: true; reducedMotion: true
        displaySettings: ({layoutMode: "notch", modules: ["music", "plugin:example.rss", "timer", "clipboard"]})
    }
    NotchView {
        id: music
        x: 425; y: 90; width: implicitWidth; height: implicitHeight
        media: demo; expanded: true; reducedMotion: true
        displaySettings: tools.displaySettings
    }
    Text { x: 28; y: 590; text: "PRODUCTION QML · FICTIONAL DATA · NOT A LIVE DESKTOP CAPTURE"; color: "#9aa6b2"; font.pixelSize: 10 }
    Component.onCompleted: {
        demo.setState("playing");
        demo.pluginPins.plugins = [{id: "example.rss", name: "RSS Feed", enabled: true}, {id:"example.markets",name:"Markets",enabled:true}, {id:"example.disabled",name:"SportsBar",enabled:false}];
        tools.page = "hub";
    }
}
