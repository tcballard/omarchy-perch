import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import "RequestPolicy.js" as RequestPolicy

ColumnLayout {
    id: root
    property string requestId: ""
    property color ink: Color.foreground
    property color surface: Color.background
    property var answers: ({})
    property var choices: ({})
    readonly property bool answersComplete: !state.request || state.request.kind !== "question" || state.request.input.questions.every(function (q) {
        var value = root.answers[q.question];
        return typeof value === "string" && value.trim().length > 0 && value.length <= 2000;
    })
    signal responded
    RequestState {
        id: state
        requestId: root.requestId
        onResponded: root.responded()
    }
    onRequestIdChanged: { answers = ({}); choices = ({}) }
    function answer(question, value) {
        answers = RequestPolicy.put(answers, question, value);
    }
    function choose(question, label, multiple) {
        var values = RequestPolicy.select(choices[question], label, multiple);
        choices = RequestPolicy.put(choices, question, values);
        answer(question, values.join(", "));
    }
    spacing: Style.space(10)
    Text {
        Layout.fillWidth: true
        text: state.request ? state.request.cwd : PerchStrings.t("Loading request…")
        textFormat: Text.PlainText
        wrapMode: Text.WrapAnywhere
        color: Qt.alpha(root.ink, 0.65)
        font.pixelSize: Style.space(11)
    }
    Controls.ScrollView {
        id: requestScroll
        objectName: "request-scroll"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: Math.min(Style.space(210), requestBody.implicitHeight)
        Layout.minimumHeight: Style.space(60)
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            id: requestBody
            width: requestScroll.availableWidth
            spacing: Style.space(10)
            Controls.TextArea {
                Layout.fillWidth: true
                visible: !!state.request && state.request.kind === "approval"
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
                            selected: Array.isArray(root.choices[questionRow.modelData.question]) && root.choices[questionRow.modelData.question].indexOf(modelData.label) >= 0
                            ink: root.ink
                            surface: root.surface
                            enabled: !state.expired && !state.busy && !state.delivered
                            onClicked: {
                                root.choose(questionRow.modelData.question, modelData.label, questionRow.modelData.multiSelect === true);
                            }
                        }
                    }
                    Controls.TextField {
                        Layout.fillWidth: true
                        text: root.answers[questionRow.modelData.question] || ""
                        placeholderText: questionRow.modelData.multiSelect ? PerchStrings.t("Select options or type your answer") : PerchStrings.t("Choose or type your answer")
                        maximumLength: 2000
                        color: root.ink
                        palette.base: root.surface
                        palette.placeholderText: Qt.alpha(root.ink, 0.5)
                        enabled: !state.expired && !state.busy && !state.delivered
                        onTextEdited: {
                            root.choices = RequestPolicy.put(root.choices, questionRow.modelData.question, []);
                            root.answer(questionRow.modelData.question, text);
                        }
                    }
                }
            }
        }
    }
    Flow {
        Layout.fillWidth: true
        spacing: Style.space(6)
        PerchAction {
            objectName: "request-allow"
            text: state.request && state.request.kind === "question" ? PerchStrings.t("Send answers") : PerchStrings.t("Allow once")
            ink: root.ink
            surface: root.surface
            enabled: !!state.request && !state.expired && !state.busy && !state.delivered && root.answersComplete
            onClicked: state.reply(state.request.kind === "question" ? "answer" : "allow", root.answers)
        }
        PerchAction {
            objectName: "request-deny"
            text: PerchStrings.t("Deny")
            ink: root.ink
            surface: root.surface
            enabled: !!state.request && !state.expired && !state.busy && !state.delivered
            onClicked: state.reply("deny", {})
        }
        PerchAction {
            objectName: "request-session"
            text: PerchStrings.t("Answer in session")
            ink: root.ink
            surface: root.surface
            enabled: !!state.request && !state.expired && !state.busy && !state.delivered
            onClicked: state.reply("session", {})
        }
    }
    Text {
        Layout.fillWidth: true
        text: state.error || (state.expired ? PerchStrings.t("Expired. Continue in your agent session.") : state.request ? PerchStrings.t("Returns to the session in ") + Math.max(0, Math.ceil(state.request.expiresAt - state.now)) + PerchStrings.t("s. Allow applies to this request only.") : PerchStrings.t("Request is unavailable."))
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Qt.alpha(root.ink, 0.6)
        font.pixelSize: Style.space(10)
    }
}
