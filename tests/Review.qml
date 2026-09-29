import QtQuick
import ".."
Rectangle {
    width: 1160; height: 960
    color: "#202831"
    DemoMedia { id: music }
    DemoMedia { id: timerDemo }
    DemoMedia { id: activityDemo }
    DemoMedia { id: settingsDemo; state: "empty" }
    Text { x: 40; y: 26; text: "PERCH / 0.1.0"; color: "#e9edf4"; font.pixelSize: 23; font.letterSpacing: 2 }
    Text { x: 40; y: 65; text: "Music. Time. Progress. Right at the edge."; color: "#9aa6b2"; font.pixelSize: 14 }
    NotchView { x: 40; y: 106; width: implicitWidth; height: implicitHeight; media: music }
    NotchView { x: 272; y: 106; width: implicitWidth; height: implicitHeight; media: timerDemo }
    NotchView { x: 506; y: 106; width: implicitWidth; height: implicitHeight; media: activityDemo }
    NotchView { x: 40; y: 164; width: implicitWidth; height: implicitHeight; media: music; expanded: true; demo: true }
    NotchView { id: timer; x: 408; y: 164; width: implicitWidth; height: implicitHeight; media: timerDemo; expanded: true; demo: true; page: "timer" }
    NotchView { x: 776; y: 164; width: implicitWidth; height: implicitHeight; media: music; expanded: true; demo: true; page: "system" }
    NotchView { x: 40; y: 464; width: implicitWidth; height: implicitHeight; media: settingsDemo; expanded: true; settingsOpen: true }
    NotchView { id: activities; x: 408; y: 558; width: implicitWidth; height: implicitHeight; media: activityDemo; expanded: true; demo: true; page: "activity" }
    Text { x: 790; y: 590; width: 310; text: "Four edges. One quiet companion.\n\n• Seek and choose your player\n• Volume, mute and battery\n• Timers survive shell restarts\n• Progress from scripts and agents\n• Preferences saved in Omarchy"; color: "#b9c3ce"; font.pixelSize: 14; lineHeight: 1.6; wrapMode: Text.WordWrap }
    Text { anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 8 } text: "RELEASE CANDIDATE · ACTUAL QML · FICTIONAL DATA · THEME STUBS"; color: "#9aa6b2"; font.pixelSize: 9; font.letterSpacing: 1 }
    Component.onCompleted: {
        timerDemo.live.start(1500,"Focus"); timer.page="timer";
        activityDemo.live.activity(JSON.stringify({id:"build",title:"Building Perch",detail:"Checking QML and running tests",state:"running",progress:0.72}));
        activityDemo.live.activity(JSON.stringify({id:"backup",title:"Backup complete",detail:"Everything is up to date",state:"done",progress:1}));
        activities.page="activity";
    }
}
