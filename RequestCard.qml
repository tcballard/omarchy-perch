import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property string requestId: ""
    property color ink: Color.foreground
    property color surface: Color.background
    property var answers: ({})
    signal responded
    RequestState {
        id: state
        requestId: root.requestId
        onResponded: root.responded()
    }
    onRequestIdChanged: answers = ({})
    function answer(question, value) {
        var next = Object.assign({}, answers);
        next[question] = value;
        answers = next;
    }
    spacing: Style.space(10)
    Text {
        Layout.fillWidth: true
        text: state.request ? state.request.cwd : "Loading request…"
        textFormat: Text.PlainText
        wrapMode: Text.WrapAnywhere
        color: Qt.alpha(root.ink, 0.65)
        font.pixelSize: Style.space(11)
    }
    Controls.ScrollView {
        visible: !!state.request && state.request.kind === "approval"
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(150)
        clip: true
        contentWidth: availableWidth
        Controls.TextArea {
            width: parent.width
            text: state.request ? JSON.stringify(state.request.input, null, 2) : ""
            readOnly: true
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.WrapAnywhere
            color: root.ink
            font.pixelSize: Style.space(11)
            background: Rectangle {
                color: Qt.alpha(root.ink, 0.04)
                radius: Style.space(8)
            }
        }
    }
    Repeater {
        model: state.request && state.request.kind === "question" ? state.request.input.questions : []
        delegate: ColumnLayout {
            id: questionRow
            required property var modelData
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: questionRow.modelData.question
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                font.pixelSize: Style.space(12)
                color: root.ink
            }
            Repeater {
                model: questionRow.modelData.options || []
                delegate: Text {
                    required property var modelData
                    Layout.fillWidth: true
                    visible: !!modelData.description
                    text: modelData.label + " · " + (modelData.description || "")
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Qt.alpha(root.ink, 0.65)
                    font.pixelSize: Style.space(11)
                }
            }
            Repeater {
                model: questionRow.modelData.options || []
                delegate: PerchAction {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.label
                    Accessible.description: modelData.description || ""
                    ink: root.ink
                    surface: root.surface
                    enabled: !state.expired && !state.busy
                    onClicked: {
                        var current = root.answers[questionRow.modelData.question] || "";
                        if (questionRow.modelData.multiSelect) {
                            var values = current ? current.split(", ") : [];
                            var at = values.indexOf(modelData.label);
                            if (at >= 0)
                                values.splice(at, 1);
                            else
                                values.push(modelData.label);
                            root.answer(questionRow.modelData.question, values.join(", "));
                        } else
                            root.answer(questionRow.modelData.question, modelData.label);
                    }
                }
            }
            Controls.TextField {
                Layout.fillWidth: true
                text: root.answers[questionRow.modelData.question] || ""
                placeholderText: questionRow.modelData.multiSelect ? "Select options or type your answer" : "Choose or type your answer"
                maximumLength: 2000
                color: root.ink
                palette.base: root.surface
                enabled: !state.expired && !state.busy
                onTextEdited: root.answer(questionRow.modelData.question, text)
            }
        }
    }
    Flow {
        Layout.fillWidth: true
        spacing: Style.space(6)
        PerchAction {
            objectName: "request-allow"
            text: state.request && state.request.kind === "question" ? "Send answers" : "Allow once"
            ink: root.ink
            surface: root.surface
            enabled: !!state.request && !state.expired && !state.busy && !state.delivered
            onClicked: state.reply(state.request.kind === "question" ? "answer" : "allow", root.answers)
        }
        PerchAction {
            objectName: "request-deny"
            text: "Deny"
            ink: root.ink
            surface: root.surface
            enabled: !!state.request && !state.expired && !state.busy && !state.delivered
            onClicked: state.reply("deny", {})
        }
        PerchAction {
            objectName: "request-session"
            text: "Answer in session"
            ink: root.ink
            surface: root.surface
            enabled: !!state.request && !state.expired && !state.busy && !state.delivered
            onClicked: state.reply("session", {})
        }
    }
    Text {
        Layout.fillWidth: true
        text: state.error || (state.expired ? "Expired. Continue in your agent session." : state.request ? "Returns to the session in " + Math.max(0, Math.ceil(state.request.expiresAt - state.now)) + "s. Allow applies to this request only." : "Request is unavailable.")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Qt.alpha(root.ink, 0.6)
        font.pixelSize: Style.space(10)
    }
}
