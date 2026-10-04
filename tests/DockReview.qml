import QtQuick
import ".."

Rectangle {
    id: root
    width: 1000
    height: 660
    color: "#151c24"
    property alias service: live.service
    property alias dock: live.service.dock
    ServiceHarness {
        id: live
    }
    DemoMedia {
        id: demo
    }
    NotchView {
        id: notch
        objectName: "dock-review"
        anchors.centerIn: parent
        media: live.service
        expanded: true
        page: "dock"
        preferredWidth: 600
        width: implicitWidth
        height: implicitHeight
        displaySettings: live.service.preferences.values
        onPreferenceChanged: (key, value) => {
            var patch = {};
            patch[key] = value;
            live.service.preferences.update(patch);
        }
        onExpandRequested: expanded = true
        onCollapseRequested: expanded = false
    }
    Component.onCompleted: Qt.callLater(function () {
        live.service.dock.create("Everyday", "everyday");
        live.service.dock.resize("weather", true);
        live.service.dock.resize("calendar", true);
        live.service.utilities.reminders = [
            {
                id: "one",
                title: "Finish the release notes",
                list: "Work",
                done: false
            },
            {
                id: "two",
                title: "Pack the train bag",
                list: "Personal",
                done: false
            }
        ];
        live.service.utilities.drinks = [
            {
                id: "demo",
                amount: 250,
                at: Date.now() / 1000
            }
        ];
        live.service.modules.weather = {
            temperature: 16,
            code: 2,
            wind: 8,
            hours: []
        };
        live.service.modules.weatherUpdated = Date.now();
        live.service.modules.sample = {
            memory: 42,
            disk: 31
        };
        live.service.modules.cpu = 23;
    })
    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        text: "PERCH · PRODUCTION QML · FICTIONAL DATA / HOST STUBS"
        color: "#94a3b8"
        font.pixelSize: 10
        font.letterSpacing: 1
    }
}
