import QtQuick
import ".."
Rectangle {
    width: 1080; height: 740; color: "#202831"
    DemoMedia { id: music }
    DemoMedia { id: quiet }
    Text { x:28; y:24; text:"PERCH / TWO PRESENTATIONS"; color:"#e9edf4"; font.pixelSize:23 }
    Text { x:28; y:75; text:"Notch · one useful context"; color:"#9aa6b2"; font.pixelSize:13 }
    NotchView { x:28; y:102; width:implicitWidth; height:implicitHeight; media:music }
    NotchView { x:265; y:102; width:implicitWidth; height:implicitHeight; media:quiet }
    Text { x:580; y:75; text:"Plugin Perch · your chosen tiles"; color:"#9aa6b2"; font.pixelSize:13 }
    NotchView { x:580; y:102; width:implicitWidth; height:implicitHeight; media:music; displaySettings:({layoutMode:"strip",modules:["music","timer","plugin:example.notes","clipboard","stats"]}) }
    Text { x:28; y:180; text:"Both open the same cards and pinned plugins"; color:"#e9edf4"; font.pixelSize:14 }
    NotchView { x:28; y:215; width:implicitWidth; height:implicitHeight; media:music; expanded:true; demo:true; displaySettings:({modules:["music","timer","plugin:example.notes","stats","weather"]}) }
    Text { x:415; y:240; width:580; text:"The notch stays small. Your tools and plugin pins appear when you open it. Choose Plugin Perch in Settings to keep those tiles visible."; wrapMode:Text.WordWrap; color:"#9aa6b2"; font.pixelSize:18 }
    Text { x:415; y:405; width:580; text:"PRODUCTION QML · FICTIONAL DATA · NOT A LIVE DESKTOP CAPTURE"; wrapMode:Text.WordWrap; color:"#9aa6b2"; font.pixelSize:10 }
    Component.onCompleted: quiet.setState("empty")
}
