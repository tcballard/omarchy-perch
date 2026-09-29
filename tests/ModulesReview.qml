import QtQuick
import ".."
Rectangle {
    width: 1144; height: 700; color: "#202831"
    DemoMedia { id: clips }
    DemoMedia { id: stats }
    DemoMedia { id: weather }
    Text { x: 30; y: 22; text: "PERCH / NATIVE MODULES"; color: "#e9edf4"; font.pixelSize: 23 }
    Text { x: 30; y: 60; text: "Choose your tools. Keep them at the edge."; color: "#9aa6b2"; font.pixelSize: 14 }
    NotchView { x: 30; y: 100; width: implicitWidth; height: implicitHeight; media: clips; displaySettings: ({layoutMode:"strip", modules:["music","timer","clipboard","stats","weather","shelf","calendar"]}) }
    NotchView { x: 30; y: 180; width: implicitWidth; height: implicitHeight; media: clips; expanded: true; demo: true; page: "clipboard"; displaySettings: ({layoutMode:"strip"}) }
    NotchView { x: 400; y: 180; width: implicitWidth; height: implicitHeight; media: stats; expanded: true; demo: true; page: "stats"; displaySettings: ({layoutMode:"strip"}) }
    NotchView { x: 770; y: 180; width: implicitWidth; height: implicitHeight; media: weather; expanded: true; demo: true; page: "weather"; displaySettings: ({layoutMode:"strip"}) }
    Text { x:30; y:672; text: "PRODUCTION QML · FICTIONAL DATA · THEME STUBS · NOT A LIVE DESKTOP CAPTURE"; color: "#9aa6b2"; font.pixelSize: 10 }
}
