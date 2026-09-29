import QtQuick
import ".."
Rectangle {
    width: 1080; height: 610; color: "#202831"
    DemoMedia { id: fixture }
    Text { x:28; y:20; text:"PERCH / SETTINGS"; color:"#e9edf4"; font.pixelSize:23 }
    NotchView { x:28; y:75; width:implicitWidth; height:implicitHeight; media:fixture; expanded:true; settingsOpen:true; demo:true }
    NotchView { x:670; y:75; width:344; height:implicitHeight; media:fixture; expanded:true; settingsOpen:true; demo:true }
    Text { x:28; y:570; text:"PRODUCTION QML · FICTIONAL DATA · WIDE AND CONSTRAINED LAYOUTS"; color:"#9aa6b2"; font.pixelSize:10 }
}
