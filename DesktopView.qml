import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

Controls.ScrollView {
    id: root
    property var work: null
    property var desktop: null
    property color ink: Color.foreground
    property color surface: Color.background
    signal launched
    signal popupToggled(bool open)
    clip: true
    contentWidth: availableWidth
    ColumnLayout {
        width: root.availableWidth
        spacing: Style.space(8)

        Text {
            text: PerchStrings.t("Quick access to Omarchy")
            color: Qt.alpha(root.ink, 0.55)
            font.pixelSize: Style.space(11)
        }
        RowLayout {
            Layout.fillWidth: true
            PerchCombo {
                id: apps
                ink: root.ink
                surface: root.surface
                onPopupToggled: open => root.popupToggled(open)
                Layout.fillWidth: true
                model: root.work ? root.work.apps : []
                textRole: "name"
                displayText: count ? currentText : PerchStrings.t("No installed apps loaded")
                Accessible.name: PerchStrings.t("Application to launch or pin")
            }
            PerchAction {
                text: PerchStrings.t("Open")
                ink: root.ink
                surface: root.surface
                enabled: !!root.work && apps.currentIndex >= 0 && !root.work.busy
                onClicked: if (root.work.request("app-open", {
                    id: root.work.apps[apps.currentIndex].id
                }))
                    root.launched()
            }
            PerchAction {
                text: PerchStrings.t("Pin")
                ink: root.ink
                surface: root.surface
                enabled: !!root.desktop && !!root.work && apps.currentIndex >= 0
                onClicked: root.desktop.pin(root.work.apps[apps.currentIndex])
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Style.space(8)
            columnSpacing: Style.space(8)
            Repeater {
                model: root.desktop ? root.desktop.entries : []
                delegate: PerchAction {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Style.space(44)
                    text: modelData.label
                    Accessible.description: modelData.detail
                    ink: root.ink
                    surface: root.surface
                    enabled: !!root.desktop && !root.desktop.busy
                    onClicked: if (root.desktop.launch(modelData.id))
                        root.launched()
                }
            }
        }
        Repeater {
            model: root.desktop && root.desktop.pins ? root.desktop.pins : []
            delegate: PerchAction {
                required property var modelData
                Layout.fillWidth: true
                text: PerchStrings.t("Unpin · ") + modelData.name
                ink: root.ink
                surface: root.surface
                onClicked: root.desktop.unpin(modelData.id)
            }
        }
        Text {
            text: PerchStrings.t("Pinned links")
            color: root.ink
            font.pixelSize: Style.space(12)
        }
        Controls.TextField {
            id: linkName
            objectName: "link-name"
            Layout.fillWidth: true
            placeholderText: PerchStrings.t("Name")
            maximumLength: 100
            color: root.ink
            palette.base: root.surface
        }
        Controls.TextField {
            id: linkUrl
            objectName: "link-url"
            Layout.fillWidth: true
            placeholderText: "https://…"
            maximumLength: 2048
            color: root.ink
            palette.base: root.surface
        }
        PerchAction {
            objectName: "link-add"
            text: PerchStrings.t("Pin link")
            enabled: !!root.desktop && typeof root.desktop.addLink === "function"
            ink: root.ink
            surface: root.surface
            onClicked: if (root.desktop.addLink(linkName.text, linkUrl.text)) {
                linkName.clear();
                linkUrl.clear();
            }
        }
        Repeater {
            model: root.desktop && root.desktop.links !== undefined ? root.desktop.links : []
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                PerchAction {
                    Layout.fillWidth: true
                    text: modelData.name
                    ink: root.ink
                    surface: root.surface
                    onClicked: if (root.desktop.openLink(modelData.url))
                        root.launched()
                }
                PerchAction {
                    text: PerchStrings.t("Unpin")
                    Accessible.name: "Unpin " + modelData.name
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.desktop.removeLink(modelData.url)
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: root.desktop ? root.desktop.error : "Desktop shortcuts are unavailable in demo mode."
            wrapMode: Text.WordWrap
            color: Qt.alpha(root.ink, 0.6)
            font.pixelSize: Style.space(11)
        }
    }
}
