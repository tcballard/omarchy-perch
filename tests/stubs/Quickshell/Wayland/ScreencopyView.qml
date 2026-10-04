import QtQuick

Item {
    property var captureSource: null
    property bool live: false
    property bool paintCursor: false
    property size constraintSize: Qt.size(0, 0)
    property bool hasContent: false
    implicitWidth: constraintSize.width
    implicitHeight: constraintSize.height
    function captureFrame() {
    }
}
