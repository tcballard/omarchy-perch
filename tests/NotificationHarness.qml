import QtQuick
import "../companions/notifications" as Companion
Item {
    property alias service: daemon
    property alias notice: notification
    Companion.Service { id: daemon }
    QtObject {
        id: notification
        property string lastReply:""
        function sendInlineReply(text){lastReply=text;}
        property bool hasInlineReply:false
        property string appIcon:"test-app"
        property bool tracked: false
        property string appName: "Test app"
        property string summary: "Hello"
        property string body: "<b>Plain text</b>"
        property var actions: [action]
        property int urgency: 1
        property real expireTimeout: 8
        property var hints: ({})
        property bool resident: false
        property int invoked: 0
        property int dismissed: 0
        property int expired: 0
        signal closed(int reason)
        function dismiss() { dismissed++; tracked=false; closed(2); }
        function expire() { expired++; tracked=false; closed(1); }
    }
    QtObject {
        id: action
        property string identifier: "default"
        property string text: "Open"
        function invoke() { notification.invoked++; }
    }
}
