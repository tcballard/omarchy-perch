import QtQuick
import ".."
Rectangle {
    width: 1110; height: 600; color: "#202831"
    Text { x:24; y:20; text:"PERCH / REQUESTS & USAGE"; color:"#e9edf4"; font.pixelSize:23 }
    function seed(card, value) {
        card.children.find(function(c) { return c.objectName === "request-state"; }).request = value;
    }
    Rectangle {
        x:24; y:70; width:340; height:470; radius:18; color:"#10151b"
        Text { x:16; y:16; text:"Permission needed · Bash"; color:"#e9edf4"; font.pixelSize:14; font.bold:true }
        RequestCard { id: approval; objectName:"approval-review"; x:16; y:50; width:308; height:400; ink:"#e9edf4"; surface:"#10151b" }
    }
    Rectangle {
        x:384; y:70; width:340; height:470; radius:18; color:"#10151b"
        Text { x:16; y:16; text:"Input needed · four questions"; color:"#e9edf4"; font.pixelSize:14; font.bold:true }
        RequestCard { id: questions; objectName:"question-review"; x:16; y:50; width:308; height:400; ink:"#e9edf4"; surface:"#10151b" }
    }
    Rectangle {
        x:744; y:70; width:340; height:470; radius:18; color:"#10151b"
        Text { x:16; y:16; text:"AI usage"; color:"#e9edf4"; font.pixelSize:14; font.bold:true }
        UsageCard {
            x:16; y:50; width:308; height:400; ink:"#e9edf4"; surface:"#10151b"
            state: QtObject {
                property bool usageEnabled: true
                property bool busy: false
                property string error: ""
                property var sources: [{name:"Codex",status:"available",updatedAt:1780000000,windows:[{label:"5 hour",used:37,resetsAt:1780014400},{label:"Weekly",used:18,resetsAt:1780480000}]},{name:"Claude",status:"unavailable",updatedAt:0,windows:[]}]
                function setEnabled(v) { usageEnabled=v; }
                function refresh() {}
            }
        }
    }
    Text { x:24; y:565; text:"PRODUCTION QML · FICTIONAL DATA · NO LIVE AGENT REQUESTS OR ACCOUNT DATA"; color:"#9aa6b2"; font.pixelSize:10 }
    Component.onCompleted: {
        seed(approval,{id:"a".repeat(32),kind:"approval",tool:"Bash",cwd:"/work/perch",input:{command:"python3 -m pytest tests/",description:"Run the project tests"},expiresAt:Date.now()/1000+120});
        seed(questions,{id:"b".repeat(32),kind:"question",tool:"AskUserQuestion",cwd:"/work/perch",input:{questions:[1,2,3,4].map(function(i){return {question:"Which option should question "+i+" use?",options:[{label:"Recommended",description:"Use the default behavior for this example."},{label:"Custom",description:"Choose your own value."}]};})},expiresAt:Date.now()/1000+120});
    }
}
