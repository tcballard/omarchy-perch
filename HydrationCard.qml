import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

Controls.ScrollView {
    id: root
    property var state: null
    property color ink: Color.foreground
    property color surface: Color.background
    implicitHeight: Style.space(300)
    contentWidth: availableWidth
    clip: true
    ColumnLayout {
        width: root.availableWidth
        spacing: Style.space(9)
        Text {
            text: root.state ? root.state.todayVolume + " mL" : "—"
            color: root.ink
            font.pixelSize: Style.space(36)
            font.bold: true
        }
        Text {
            text: root.state ? root.state.todayDrinks.length + " drinks logged today" + (root.state.todayDrinks.some(r => r.amount === 0) ? " · volume is partial" : "") : "Hydration unavailable"
            color: Qt.alpha(root.ink, 0.65)
            font.pixelSize: Style.space(12)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        PerchAction {
            objectName: "drink-water"
            text: root.state && root.state.config.enabled ? "I drank water" : "Log water"
            enabled: !!root.state && !root.state.busy
            ink: root.ink
            surface: root.surface
            onClicked: root.state.drink()
        }
        Text {
            text: root.state && root.state.config.enabled ? (root.state.drinkDue ? "Time for a drink" : "Next reminder in " + Math.max(0, Math.ceil((root.state.nextDrink - root.state.now) / 60000)) + " min") : "Reminder stopped"
            color: root.ink
            font.pixelSize: Style.space(12)
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Every (minutes)"
                color: root.ink
                font.pixelSize: Style.space(11)
                Layout.fillWidth: true
            }
            Controls.SpinBox {
                id: interval
                from: 5
                to: 240
                stepSize: 5
                value: root.state ? root.state.config.minutes || 30 : 30
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Drink size (mL; 0 = time only)"
                color: root.ink
                font.pixelSize: Style.space(11)
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
            Controls.SpinBox {
                id: amount
                from: 0
                to: 2000
                stepSize: 50
                value: root.state && root.state.config.amount !== undefined ? root.state.config.amount : 250
            }
        }
        Controls.CheckBox {
            id: history
            text: "Save drink history"
            checked: !root.state || root.state.config.history !== false
            palette.windowText: root.ink
        }
        RowLayout {
            PerchAction {
                text: "Start / apply"
                ink: root.ink
                surface: root.surface
                onClicked: root.state.configureHydration(true, interval.value, amount.value, history.checked)
            }
            PerchAction {
                text: "Stop"
                ink: root.ink
                surface: root.surface
                onClicked: root.state.configureHydration(false, interval.value, amount.value, history.checked)
            }
        }
        Text {
            text: "Recent drinks"
            color: root.ink
            font.bold: true
            font.pixelSize: Style.space(13)
        }
        Repeater {
            model: root.state ? root.state.drinks.slice(-30).reverse() : []
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Text {
                    text: new Date(modelData.at * 1000).toLocaleString() + " · " + (modelData.amount ? modelData.amount + " mL" : "Time only")
                    color: root.ink
                    Layout.fillWidth: true
                    font.pixelSize: Style.space(10)
                    elide: Text.ElideRight
                }
                PerchAction {
                    text: "−"
                    Accessible.name: "Remove drink"
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.state.removeDrink(modelData)
                }
            }
        }
        PerchAction {
            text: "Undo removal"
            visible: !!root.state && !!root.state.undoDrink
            ink: root.ink
            surface: root.surface
            onClicked: root.state.undoRemove()
        }
        Text {
            text: root.state ? root.state.error : ""
            color: "#e47b76"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            font.pixelSize: Style.space(11)
            textFormat: Text.PlainText
        }
    }
}
