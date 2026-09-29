pragma Singleton
import QtQuick
QtObject {
    readonly property color background: "#11151c"
    readonly property color foreground: "#e9edf4"
    readonly property color accent: "#a8c7a0"
    readonly property QtObject popups: QtObject { readonly property color background: "#11151c"; readonly property color text: "#e9edf4"; readonly property color border: "#35404a" }
}
