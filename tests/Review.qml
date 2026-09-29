import QtQuick
import ".."
Rectangle {
    width: 1160; height: 960
    color: "#202831"
    DemoMedia { id: music }
    DemoMedia { id: timerDemo }
    DemoMedia { id: activityDemo }
    DemoMedia { id: inboxDemo }
    Text { x: 40; y: 26; text: "PERCH / 0.1.0-rc.2"; color: "#e9edf4"; font.pixelSize: 23; font.letterSpacing: 2 }
    Text { x: 40; y: 65; text: "Your music, messages and desktop. Right at the edge."; color: "#9aa6b2"; font.pixelSize: 14 }
    NotchView { x: 40; y: 106; width: implicitWidth; height: implicitHeight; media: music }
    NotchView { x: 272; y: 106; width: implicitWidth; height: implicitHeight; media: timerDemo }
    NotchView { x: 506; y: 106; width: implicitWidth; height: implicitHeight; media: activityDemo }
    NotchView { x: 40; y: 164; width: implicitWidth; height: implicitHeight; media: music; expanded: true; demo: true }
    NotchView { id: timer; x: 408; y: 164; width: implicitWidth; height: implicitHeight; media: timerDemo; expanded: true; demo: true; page: "timer" }
    NotchView { x: 776; y: 164; width: implicitWidth; height: implicitHeight; id: inbox; media: inboxDemo; expanded: true; demo: true; page: "inbox" }
    NotchView { x: 40; y: 558; width: implicitWidth; height: implicitHeight; media: music; expanded: true; demo: true; page: "desktop" }
    NotchView { id: activities; x: 408; y: 558; width: implicitWidth; height: implicitHeight; media: activityDemo; expanded: true; demo: true; page: "activity" }
    NotchView { x: 776; y: 558; width: implicitWidth; height: implicitHeight; media: music; expanded: true; demo: true; page: "system" }
    Text { anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 8 } text: "RELEASE CANDIDATE · ACTUAL QML · FICTIONAL DATA · THEME STUBS"; color: "#9aa6b2"; font.pixelSize: 9; font.letterSpacing: 1 }
    Component.onCompleted: {
        inboxDemo.setState("inbox"); inbox.page="inbox";
        timerDemo.live.start(1500,"Focus"); timer.page="timer";
        activityDemo.live.activity(JSON.stringify({id:"build",title:"Building Perch",detail:"Checking QML and running tests",state:"running",progress:0.72}));
        activityDemo.live.activity(JSON.stringify({id:"backup",title:"Backup complete",detail:"Everything is up to date",state:"done",progress:1}));
        activities.page="activity";
    }
}
