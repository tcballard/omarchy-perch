pragma Singleton
import QtQuick
QtObject {
    property int cornerRadius: 12
    function space(n) { return n }
    readonly property QtObject font: QtObject { property string family: "DejaVu Sans"; property int caption: 10; property int body: 12; property int heading: 16; property int displayLarge: 28 }
    readonly property QtObject bar: QtObject { property int sizeHorizontal: 26 }
}
