import QtQuick
import qs.Commons
import ".."
Rectangle {
    id: root
    width: 720; height: 440
    color: "#202831"
    property string previewState: "playing"
    DemoMedia { id: demoMedia; objectName: "demoMedia" }
    NotchView {
        id: notch
        objectName: "notch"
        anchors.centerIn: parent
        width: implicitWidth; height: implicitHeight
        media: demoMedia
        expanded: root.previewState !== "compact"
        demo: true
        onEdgeRequested: function(value) { notch.edge = value }
        onCollapseRequested: root.previewState = "compact"
        onExpandRequested: root.previewState = "playing"
        onSettingsChanged: function(hideIdle, reducedMotion, edgeAttached) { notch.hideIdle=hideIdle; notch.reducedMotion=reducedMotion; notch.edgeAttached=edgeAttached }
    }
    Component.onCompleted: demoMedia.setState(previewState)
    Text { anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 20 } text: "PERCH · DEVELOPMENT PREVIEW · FICTIONAL MEDIA"; color: "#9aa6b2"; font.pixelSize: 10; font.letterSpacing: 1 }
}
