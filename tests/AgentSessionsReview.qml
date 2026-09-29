import QtQuick
import ".."

Rectangle {
    width: 900; height: 650; color: "#202831"
    DemoMedia { id: sessions }
    Text { x: 28; y: 24; text: "PERCH / AGENT SESSIONS"; color: "#e9edf4"; font.pixelSize: 23 }
    NotchView { x: 28; y: 90; width: implicitWidth; height: implicitHeight; media: sessions }
    NotchView {
        x: 28; y: 150; width: implicitWidth; height: implicitHeight
        media: sessions; expanded: true; page: "activity"; reducedMotion: true
        displaySettings: ({modules: ["activity", "music", "plugin:example.notes", "timer"]})
    }
    Text {
        x: 425; y: 165; width: 420
        text: "See what needs you.\nReturn to its window."
        color: "#e9edf4"; font.pixelSize: 26; wrapMode: Text.WordWrap
    }
    Text {
        x: 425; y: 260; width: 405
        text: "Project names, agent labels and last updates keep concurrent sessions distinguishable. Attention comes first; other work stays in the same list."
        color: "#9aa6b2"; font.pixelSize: 17; wrapMode: Text.WordWrap
    }
    Text {
        x: 425; y: 455; width: 405
        text: "PRODUCTION QML · FICTIONAL DATA\nNOT A LIVE DESKTOP CAPTURE"
        color: "#9aa6b2"; font.pixelSize: 10
    }
    Component.onCompleted: {
        sessions.setState("empty");
        sessions.live.items = [];
        sessions.live.activity(JSON.stringify({id: "claude.perch", kind: "agent", agent: "Claude", title: "Perch", project: "omarchy-perch", state: "waiting", detail: "Needs your attention in Claude Code", target: "0x123"}));
        sessions.live.activity(JSON.stringify({id: "codex.sheets", kind: "agent", agent: "Codex", title: "OmaSheets", project: "OmaSheets", state: "done", detail: "Turn complete", target: "0x456"}));
    }
}
