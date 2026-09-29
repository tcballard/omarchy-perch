import QtQuick
import ".."
Rectangle {
    width: 960; height: 610
    color: "#202831"
    DemoMedia { id: music }
    DemoMedia { id: silent; state: "empty" }
    Text { x: 40; y: 30; text: "PERCH"; color: "#e9edf4"; font.pixelSize: 22; font.letterSpacing: 3 }
    Text { x: 40; y: 65; text: "A quieter edge. A quicker interaction."; color: "#9aa6b2"; font.pixelSize: 13 }
    NotchView { x: 40; y: 120; width: implicitWidth; height: implicitHeight; media: music }
    NotchView { x: 420; y: 120; width: implicitWidth; height: implicitHeight; media: music; edge: "right" }
    NotchView { x: 40; y: 176; width: implicitWidth; height: implicitHeight; media: music; expanded: true; demo: true }
    NotchView { x: 40; y: 406; width: implicitWidth; height: implicitHeight; media: silent; expanded: true }
    NotchView { x: 500; y: 176; width: implicitWidth; height: implicitHeight; media: music; expanded: true; settingsOpen: true }
    Text { x: 500; y: 536; text: "90 ms hover · 140 ms expansion\nTop / bottom / left / right"; color: "#9aa6b2"; font.pixelSize: 12; lineHeight: 1.5 }
    Text { anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 16 } text: "DEVELOPMENT PREVIEW · ACTUAL QML · FICTIONAL MEDIA · THEME STUBS"; color: "#9aa6b2"; font.pixelSize: 9; font.letterSpacing: 1 }
}
