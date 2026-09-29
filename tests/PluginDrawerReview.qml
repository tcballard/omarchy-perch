import QtQuick
import ".."
Rectangle {
    width: 900; height: 610; color: "#202831"
    DemoMedia { id: demo }
    Text { x: 28; y: 24; text: "PERCH / NATIVE PLUGIN DRAWER"; color: "#e9edf4"; font.pixelSize: 23 }
    NotchView {
        id: drawer
        x: 28; y: 90; width: implicitWidth; height: implicitHeight
        media: demo; expanded: true; reducedMotion: true
        displaySettings: ({layoutMode: "strip", modules: ["music", "plugin:example.notes", "timer", "clipboard"]})
    }
    Text { x: 425; y: 110; width: 410; text: "Your plugins.\nInside Perch."; color: "#e9edf4"; font.pixelSize: 30; wrapMode: Text.WordWrap }
    Text { x: 425; y: 235; width: 410; text: "Native status, headlines and actions from the existing RSS service. Open the full reader when you want more room."; color: "#9aa6b2"; font.pixelSize: 18; wrapMode: Text.WordWrap }
    Text { x: 425; y: 445; width: 405; text: "PRODUCTION QML · FICTIONAL DATA\nNOT A LIVE DESKTOP CAPTURE"; color: "#9aa6b2"; font.pixelSize: 10 }
    Component.onCompleted: {
        demo.setState("empty");
        demo.pluginPins.plugins = [{id: "example.notes", name: "RSS Feed", enabled: true}];
        drawer.activateModule("plugin:example.notes", false);
    }
}
