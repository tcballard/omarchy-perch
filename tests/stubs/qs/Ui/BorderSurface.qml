import QtQuick
Rectangle {
    property var borderSpec: ({color:"transparent",width:0})
    border.color: borderSpec.color
    border.width: borderSpec.width
}
