import QtQuick
import ".."
Rectangle {
    width: 800; height: 510; color: "#202831"
    DemoMedia { id: complete }
    DemoMedia { id: attention }
    Text { x: 28; y: 24; text: "PERCH / COMPLETION & ATTENTION"; color: "#e9edf4"; font.pixelSize: 23 }
    NotchView {
        id: completionCard
        x: 28; y: 90; width: implicitWidth; height: implicitHeight
        media: complete; expanded: true; reducedMotion: true
    }
    NotchView {
        id: attentionCard
        x: 425; y: 90; width: implicitWidth; height: implicitHeight
        media: attention; expanded: true; reducedMotion: true
    }
    Text { x: 28; y: 478; text: "PRODUCTION QML · FICTIONAL DATA · NOT A LIVE DESKTOP CAPTURE"; color: "#9aa6b2"; font.pixelSize: 10 }
    Component.onCompleted: {
        complete.live.activity(JSON.stringify({id: "done", state: "done", title: "Perch", detail: "Turn complete", kind: "agent", agent: "Codex", project: "perch", target: "0x123"}));
        attention.live.activity(JSON.stringify({id: "approval", state: "waiting", attention: "approval", title: "RSS Feed", detail: "Needs your attention in Claude Code", kind: "agent", agent: "Claude", project: "rss-feed", target: "0x456"}));
        completionCard.eventId = "done"; completionCard.page = "event";
        attentionCard.eventId = "approval"; attentionCard.page = "event";
    }
}
