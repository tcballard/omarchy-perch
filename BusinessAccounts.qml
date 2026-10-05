import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import qs.Commons

ColumnLayout {
    id: root
    property var manager: null
    property color ink: Color.foreground
    property color surface: Color.background
    property string disconnectId: ""
    property string editingId: ""
    property string importPath: ""
    signal accountChosen(string id)
    spacing: Style.space(10)
    Text {
        text: "Business accounts"
        font.pixelSize: Style.space(19)
        font.bold: true
        color: root.ink
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "Give each business a name and colour. Tiles can share an account while showing different metrics."
        font.pixelSize: Style.space(11)
        color: Qt.alpha(root.ink, 0.7)
    }
    Repeater {
        model: root.manager ? root.manager.accounts : []
        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            RowLayout {
                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 32
                    radius: 4
                    color: modelData.color
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        font.bold: true
                        font.pixelSize: Style.space(13)
                        color: root.ink
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.provider + " · " + (modelData.sandbox === true ? "Sandbox" : modelData.sandbox === false ? "Live" : "Store") + " · " + modelData.storage
                        font.pixelSize: Style.space(10)
                        color: Qt.alpha(root.ink, 0.6)
                        elide: Text.ElideRight
                    }
                }
                PerchAction {
                    text: "Use"
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.accountChosen(modelData.id)
                }
                PerchAction {
                    text: "Edit"
                    ink: root.ink
                    surface: root.surface
                    onClicked: {
                        root.editingId = modelData.id;
                        accountName.text = modelData.name;
                        accountColor.text = modelData.color;
                    }
                }
            }
            RowLayout {
                visible: root.editingId === modelData.id
                PerchAction {
                    text: "Test"
                    enabled: !!root.manager && !root.manager.busy
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.manager.test(modelData.id, "USD", "local")
                }
                PerchAction {
                    text: "Disconnect…"
                    enabled: !!root.manager && !root.manager.busy
                    ink: root.ink
                    surface: root.surface
                    onClicked: root.disconnectId = modelData.id
                }
            }
        }
    }
    ColumnLayout {
        visible: root.disconnectId !== ""
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Disconnect this account and remove its Perch history? Its tiles will need another account. Imported source files and provider keys are not revoked."
            textFormat: Text.PlainText
            color: root.ink
            font.pixelSize: Style.space(11)
        }
        RowLayout {
            PerchAction {
                text: "Disconnect account"
                enabled: !!root.manager && !root.manager.busy
                ink: root.ink
                surface: root.surface
                onClicked: {
                    root.manager.disconnect(root.disconnectId);
                    root.disconnectId = "";
                    root.editingId = "";
                }
            }
            PerchAction {
                text: "Cancel"
                ink: root.ink
                surface: root.surface
                onClicked: root.disconnectId = ""
            }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Qt.alpha(root.ink, 0.12)
    }
    Text {
        text: root.editingId ? "Edit account" : "Add account"
        font.pixelSize: Style.space(15)
        font.bold: true
        color: root.ink
    }
    Controls.TextField {
        id: accountName
        objectName: "business-account-name"
        Layout.fillWidth: true
        placeholderText: "Account name"
        maximumLength: 60
        color: root.ink
        palette.base: root.surface
    }
    Controls.TextField {
        id: accountColor
        Layout.fillWidth: true
        text: "#85b8d9"
        placeholderText: "Colour (#85b8d9)"
        maximumLength: 7
        color: root.ink
        palette.base: root.surface
    }
    RowLayout {
        visible: root.editingId !== ""
        PerchAction {
            text: "Save account"
            enabled: !!root.manager && !root.manager.busy
            ink: root.ink
            surface: root.surface
            onClicked: root.manager.rename(root.editingId, accountName.text, accountColor.text)
        }
        PerchAction {
            text: "Add another"
            ink: root.ink
            surface: root.surface
            onClicked: {
                root.editingId = "";
                accountName.text = "";
            }
        }
    }
    ColumnLayout {
        visible: root.editingId === ""
        Layout.fillWidth: true
        Controls.ComboBox {
            id: provider
            objectName: "business-provider"
            Layout.fillWidth: true
            model: ["Stripe", "Paddle", "Shopify"]
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: Style.space(11)
            color: Qt.alpha(root.ink, 0.7)
            text: provider.currentIndex === 0 ? "Create a restricted key with Balance and Subscriptions read access. Use rk_live_ for live payments or rk_test_ for sandbox data." : provider.currentIndex === 1 ? "Create a Paddle Billing API key with Metrics → Read (metrics.read). Live and sandbox keys are supported." : "Install your same-organization Shopify app with read_orders. Have its myshopify.com domain, Client ID and Client secret ready."
        }
        Controls.ComboBox {
            id: storage
            Layout.fillWidth: true
            model: ["Secret Service keyring", "Private local file (not encrypted)"]
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: Style.space(10)
            color: Qt.alpha(root.ink, 0.6)
            text: storage.currentIndex === 0 ? "Requires libsecret/secret-tool and an unlocked Secret Service keyring. Perch never silently switches storage methods." : "Credentials are stored in Perch's private state directory with owner-only permissions. They are not encrypted. Dock exports contain no keys."
        }
        PerchAction {
            text: root.manager && root.manager.busy ? "Waiting / checking…" : "Enter credentials and connect…"
            enabled: !!root.manager && !root.manager.busy
            ink: root.ink
            surface: root.surface
            onClicked: root.manager.connect(provider.currentText.toLowerCase(), accountName.text, accountColor.text, storage.currentIndex === 0 ? "keyring" : "file", "USD", "local")
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "A separate masked dialog collects your credentials, then Perch checks read-only access before saving. The dialog requires zenity."
            color: Qt.alpha(root.ink, 0.55)
            font.pixelSize: Style.space(10)
        }
        PerchAction {
            text: "Import existing private file…"
            enabled: !!root.manager && !root.manager.busy
            ink: root.ink
            surface: root.surface
            onClicked: picker.open()
        }
        Text {
            visible: root.importPath !== ""
            text: root.importPath
            Layout.fillWidth: true
            wrapMode: Text.WrapAnywhere
            color: Qt.alpha(root.ink, 0.6)
            font.pixelSize: Style.space(10)
            textFormat: Text.PlainText
        }
        PerchAction {
            visible: root.importPath !== ""
            text: "Import connection"
            enabled: !!root.manager && !root.manager.busy
            ink: root.ink
            surface: root.surface
            onClicked: root.manager.importFile(root.importPath, accountName.text, accountColor.text)
        }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: root.manager ? root.manager.error || root.manager.message : "Account manager unavailable"
        textFormat: Text.PlainText
        font.pixelSize: Style.space(11)
        color: root.manager && root.manager.error ? "#e47b76" : Qt.alpha(root.ink, 0.7)
    }
    FileDialog {
        id: picker
        onAccepted: root.importPath = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""))
    }
}
