import QtQuick
import ".."
Rectangle {
    width: 1160; height: 1700
    color: "#202831"
    DemoMedia { id: music }
    DemoMedia { id: timerDemo }
    DemoMedia { id: activityDemo }
    DemoMedia { id: inboxDemo }
    Text { x: 40; y: 26; text: "PERCH / NATIVE CARDS"; color: "#e9edf4"; font.pixelSize: 23; font.letterSpacing: 2 }
    Text { x: 40; y: 65; text: "Music, files, meetings and tasks. Right at the edge."; color: "#9aa6b2"; font.pixelSize: 14 }
    NotchView { x: 40; y: 106; width: implicitWidth; height: implicitHeight; media: music }
    NotchView { x: 408; y: 106; width: implicitWidth; height: implicitHeight; media: timerDemo }
    NotchView { x: 776; y: 106; width: implicitWidth; height: implicitHeight; media: activityDemo }
    NotchView { x: 40; y: 180; width: implicitWidth; height: implicitHeight; media: music; expanded: true; demo: true }
    NotchView { id: timer; x: 408; y: 180; width: implicitWidth; height: implicitHeight; media: timerDemo; expanded: true; demo: true; page: "timer" }
    NotchView { x: 776; y: 180; width: implicitWidth; height: implicitHeight; id: inbox; media: inboxDemo; expanded: true; demo: true; page: "inbox" }
    NotchView { x: 40; y: 685; width: implicitWidth; height: implicitHeight; media: music; expanded: true; demo: true; page: "desktop" }
    NotchView { id: activities; x: 408; y: 685; width: implicitWidth; height: implicitHeight; media: activityDemo; expanded: true; demo: true; page: "activity" }
    NotchView { x: 776; y: 685; width: implicitWidth; height: implicitHeight; media: music; expanded: true; demo: true; page: "system" }
    NotchView {x:40;y:1190;width:implicitWidth;height:implicitHeight;media:music;expanded:true;demo:true;page:"shelf"}
    NotchView {x:408;y:1190;width:implicitWidth;height:implicitHeight;media:music;expanded:true;demo:true;page:"calendar"}
    NotchView {x:776;y:1190;width:implicitWidth;height:implicitHeight;media:music;expanded:true;demo:true;page:"setup"}
    Text { anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 8 } text: "UNRELEASED · ACTUAL QML · FICTIONAL DATA · THEME STUBS"; color: "#9aa6b2"; font.pixelSize: 9; font.letterSpacing: 1 }
    Component.onCompleted: {
        inboxDemo.setState("inbox"); inbox.page="inbox";
        timerDemo.live.start(1500,"Focus"); timer.page="timer";
        activityDemo.live.activity(JSON.stringify({id:"build",title:"Building Perch",detail:"Checking QML and running tests",state:"running",progress:0.72}));
        activityDemo.live.activity(JSON.stringify({id:"backup",title:"Backup complete",detail:"Everything is up to date",state:"done",progress:1}));
        activities.page="activity";
    }
}
