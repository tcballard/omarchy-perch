import QtQuick
import QtQuick.Controls
import ".."
Rectangle {
    width: 720; height: 820; color: "#202831"
    DemoMedia { id: fixture }
    Text { x: 30; y: 24; text: "PERCH / PLUGIN PINS"; color: "#e9edf4"; font.pixelSize: 23 }
    NotchView { x: 30; y: 75; width: implicitWidth; height: implicitHeight; media: fixture; displaySettings: ({modules:["music","plugin:example.notes","timer"]}) }
    Rectangle {
        x: 30; y: 150; width: 660; height: 620; radius: 18; color: "#10151b"
        ScrollView {
            anchors.fill: parent; anchors.margins: 24; contentWidth: availableWidth; clip: true
            ModuleSettings { width: parent.width; items: ["music","plugin:example.notes","timer"]; pluginState: fixture.pluginPins; ink: "#e9edf4"; surface: "#10151b" }
        }
    }
    Text { x:30; y:790; text: "PRODUCTION QML · FICTIONAL PLUGINS · NO REAL LAUNCH"; color:"#9aa6b2"; font.pixelSize:10 }
}
