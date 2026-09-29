import QtQuick

// Model the host name collision: qs.Ui.Button is not a Qt Controls Button.
// In particular, it exposes selected, not checked/checkable.
Item {
    property string text: ""
    property bool selected: false
    signal clicked()
}
