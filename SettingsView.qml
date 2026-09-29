import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    required property var host
    property string section: "display"
    readonly property bool wide: width >= Style.space(480)
    readonly property var sections: [
        {
            id: "display",
            title: "Placement",
            detail: "Choose where Perch lives on your desktop."
        },
        {
            id: "behavior",
            title: "Behaviour",
            detail: "Control how Perch opens and moves."
        },
        {
            id: "alerts",
            title: "Alerts & sound",
            detail: "Choose interruptions, previews and sounds."
        },
        {
            id: "modules",
            title: "Your strip",
            detail: "Choose and arrange up to eight tools and plugin pins."
        },
        {
            id: "plugins",
            title: "Plugin pins",
            detail: "Pin plugins for native cards and quick access to their full panels."
        }
    ]
    readonly property var current: sections.find(function (s) {
        return s.id === section;
    }) || sections[0]
    spacing: Style.space(12)
    Text {
        Layout.fillWidth: true
        text: "Changes apply automatically"
        color: Qt.alpha(root.host.ink, 0.6)
        font.pixelSize: Style.space(11)
        font.family: Style.font.family
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Qt.alpha(root.host.ink, 0.12)
    }
    Flow {
        visible: !root.wide
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        spacing: Style.space(4)
        Repeater {
            model: root.sections
            delegate: PerchAction {
                required property var modelData
                objectName: "settings-compact-" + modelData.id
                text: modelData.title
                selected: root.section === modelData.id
                ink: root.host.ink
                surface: root.host.surface
                onClicked: root.section = modelData.id
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.space(20)
        ColumnLayout {
            visible: root.wide
            Layout.preferredWidth: Style.space(132)
            Layout.alignment: Qt.AlignTop
            spacing: Style.space(6)
            Repeater {
                model: root.sections
                delegate: PerchAction {
                    required property var modelData
                    objectName: "settings-nav-" + modelData.id
                    Layout.fillWidth: true
                    text: modelData.title
                    selected: root.section === modelData.id
                    ink: root.host.ink
                    surface: root.host.surface
                    onClicked: root.section = modelData.id
                }
            }
        }
        Controls.ScrollView {
            id: scroll
            objectName: "settings-scroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
            ColumnLayout {
                width: scroll.availableWidth
                spacing: Style.space(12)
                Text {
                    Layout.fillWidth: true
                    text: root.current.title
                    color: root.host.ink
                    font.family: Style.font.family
                    font.pixelSize: Style.space(16)
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: root.current.detail
                    wrapMode: Text.WordWrap
                    color: Qt.alpha(root.host.ink, 0.6)
                    font.pixelSize: Style.space(11)
                }
                ColumnLayout {
                    visible: root.section === "behavior"
                    Layout.fillWidth: true
                    Text {
                        text: "Compact presentation"
                        color: root.host.ink
                        font.pixelSize: Style.space(12)
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: childrenRect.height
                        spacing: Style.space(6)
                        PerchAction {
                            objectName: "presentation-notch"
                            text: "Notch"
                            selected: !root.host.perchMode
                            ink: root.host.ink
                            surface: root.host.surface
                            onClicked: root.host.preferenceChanged("layoutMode", "notch")
                        }
                        PerchAction {
                            objectName: "presentation-perch"
                            text: "Plugin Perch"
                            selected: root.host.perchMode
                            ink: root.host.ink
                            surface: root.host.surface
                            onClicked: root.host.preferenceChanged("layoutMode", "strip")
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: root.host.perchMode ? "Keep your chosen tools and plugin pins visible at the edge." : "Show one useful context. Your tools and pins appear when you open Perch."
                        color: Qt.alpha(root.host.ink, 0.6)
                        font.pixelSize: Style.space(11)
                    }
                }
                ColumnLayout {
                    visible: root.section === "display"
                    Layout.fillWidth: true
                    Text {
                        text: "Appearance"
                        color: root.host.ink
                        font.pixelSize: Style.space(12)
                    }
                    PerchCombo {
                        objectName: "settings-appearance"
                        Layout.fillWidth: true
                        ink: root.host.ink
                        surface: root.host.surface
                        model: ["Dark island", "Follow Omarchy theme"]
                        currentIndex: root.host.displaySettings.chromeMode === "theme" ? 1 : 0
                        onActivated: index => root.host.preferenceChanged("chromeMode", index === 1 ? "theme" : "dark")
                        onPopupToggled: open => root.host.popupOpen = open
                    }
                    spacing: Style.space(12)
                    Text {
                        text: "Display"
                        color: root.host.ink
                        font.pixelSize: Style.space(11)
                    }
                    PerchCombo {
                        objectName: "monitor-choice"
                        Layout.fillWidth: true
                        ink: root.host.ink
                        surface: root.host.surface
                        model: ["Follow focused display"].concat(root.host.displayNames)
                        currentIndex: Math.max(0, root.host.displayNames.indexOf(root.host.displaySettings.monitor || "") + 1)
                        onActivated: index => root.host.preferenceChanged("monitor", index === 0 ? "" : root.host.displayNames[index - 1])
                        onPopupToggled: open => root.host.popupOpen = open
                    }
                    PerchToggle {
                        Layout.fillWidth: true
                        text: "Per-display placement"
                        description: "Remember a different edge and size for each display."
                        checked: root.host.displaySettings.perDisplay === true
                        ink: root.host.ink
                        surface: root.host.surface
                        onToggled: root.host.preferenceChanged("perDisplay", checked)
                    }
                    Text {
                        text: "Screen edge"
                        color: root.host.ink
                        font.pixelSize: Style.space(11)
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: childrenRect.height
                        spacing: Style.space(4)
                        Repeater {
                            model: ["top", "bottom", "left", "right"]
                            delegate: PerchAction {
                                required property string modelData
                                objectName: "edge-" + modelData
                                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                selected: root.host.edge === modelData
                                ink: root.host.ink
                                surface: root.host.surface
                                onClicked: root.host.edgeRequested(modelData)
                            }
                        }
                    }
                    Repeater {
                        model: [
                            {
                                key: "panelWidth",
                                title: "Card width",
                                min: 304,
                                max: 544,
                                step: 40,
                                fallback: 344
                            },
                            {
                                key: "edgeOffset",
                                title: "Extra edge spacing",
                                min: 0,
                                max: 64,
                                step: 4,
                                fallback: 0
                            }
                        ]
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    color: root.host.ink
                                    font.pixelSize: Style.space(11)
                                }
                                Text {
                                    text: Math.round(sizeControl.value) + " px"
                                    color: root.host.ink
                                    font.pixelSize: Style.space(11)
                                }
                            }
                            PerchSlider {
                                id: sizeControl
                                objectName: "settings-" + modelData.key
                                Layout.fillWidth: true
                                ink: root.host.ink
                                from: modelData.min
                                to: modelData.max
                                stepSize: modelData.step
                                value: root.host.displaySettings[modelData.key] === undefined ? modelData.fallback : root.host.displaySettings[modelData.key]
                                Accessible.name: modelData.title
                                onMoved: root.host.preferenceChanged(modelData.key, Math.round(value))
                            }
                        }
                    }
                    PerchToggle {
                        Layout.fillWidth: true
                        text: "Attach to screen edge"
                        description: "Remove the gap between Perch and the edge."
                        checked: root.host.edgeAttached
                        ink: root.host.ink
                        surface: root.host.surface
                        onToggled: root.host.preferenceChanged("edgeAttached", checked)
                    }
                }
                ColumnLayout {
                    visible: root.section === "behavior"
                    Layout.fillWidth: true
                    spacing: Style.space(12)
                    PerchToggle {
                        objectName: "settings-reducedMotion"
                        Layout.fillWidth: true
                        text: "Reduce motion"
                        description: "Show cards immediately without transitions."
                        checked: root.host.reducedMotion
                        ink: root.host.ink
                        surface: root.host.surface
                        onToggled: root.host.preferenceChanged("reducedMotion", checked)
                    }
                    PerchToggle {
                        Layout.fillWidth: true
                        text: "Open on hover"
                        description: "Preview built-in cards by hovering. Plugin pins still need a click."
                        checked: root.host.hoverOpen
                        ink: root.host.ink
                        surface: root.host.surface
                        onToggled: root.host.preferenceChanged("hoverOpen", checked)
                    }
                    Text {
                        text: "During fullscreen"
                        color: root.host.ink
                        font.pixelSize: Style.space(11)
                    }
                    PerchCombo {
                        Layout.fillWidth: true
                        ink: root.host.ink
                        surface: root.host.surface
                        model: ["Hide Perch", "Show timer and activity alerts", "Keep Perch visible"]
                        currentIndex: Math.max(0, ["hide", "alerts", "show"].indexOf(root.host.displaySettings.fullscreenPolicy || "hide"))
                        onActivated: index => root.host.preferenceChanged("fullscreenPolicy", ["hide", "alerts", "show"][index])
                        onPopupToggled: open => root.host.popupOpen = open
                    }
                }
                ColumnLayout {
                    visible: root.section === "alerts"
                    Layout.fillWidth: true
                    Repeater {
                        model: [
                            {
                                key: "rememberSessions",
                                title: "Remember agent sessions",
                                detail: "Keep up to eight last-seen sessions for one day across shell restarts. Pending requests are never saved."
                            },
                            {
                                key: "quietMode",
                                title: "Quiet mode",
                                detail: "Pause automatic cards, previews, sounds and timer notifications. Timers and the inbox keep working."
                            },
                            {
                                key: "notificationPreviews",
                                title: "Notification previews",
                                detail: "Briefly show new notifications ahead of music and running timers."
                            },
                            {
                                key: "activitySound",
                                title: "Activity sounds",
                                detail: "Play a sound for new completion or attention events."
                            },
                            {
                                key: "systemFeedback",
                                title: "Device feedback",
                                detail: "Show volume, power and Bluetooth changes."
                            },
                            {
                                key: "timerSound",
                                title: "Timer sound",
                                detail: "Play a sound when a timer finishes."
                            },
                            {
                                key: "timerNotifications",
                                title: "Timer notifications",
                                detail: "Send completed timers to desktop notifications."
                            },
                            {
                                key: "remoteArtwork",
                                title: "Remote cover artwork",
                                detail: "Allow downloading cover images from your media player."
                            },
                            {
                                key: "eventBanners",
                                title: "Activity cards",
                                detail: "Open new completion and attention cards while Perch is collapsed."
                            }
                        ]
                        delegate: PerchToggle {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.title
                            description: modelData.detail
                            checked: ["eventBanners", "notificationPreviews", "systemFeedback"].indexOf(modelData.key) >= 0 ? root.host.displaySettings[modelData.key] !== false : root.host.displaySettings[modelData.key] === true
                            ink: root.host.ink
                            surface: root.host.surface
                            onToggled: root.host.preferenceChanged(modelData.key, checked)
                        }
                    }
                    Text {
                        text: "Alert sound"
                        color: root.host.ink
                        font.pixelSize: Style.space(12)
                    }
                    PerchCombo {
                        objectName: "settings-sound"
                        Layout.fillWidth: true
                        ink: root.host.ink
                        surface: root.host.surface
                        model: ["Complete", "Message", "Bell"]
                        currentIndex: Math.max(0, ["complete", "message-new-instant", "bell"].indexOf(root.host.displaySettings.soundPreset || "complete"))
                        onActivated: index => root.host.preferenceChanged("soundPreset", ["complete", "message-new-instant", "bell"][index])
                        onPopupToggled: open => root.host.popupOpen = open
                    }
                    PerchAction {
                        objectName: "settings-preview-sound"
                        text: "Preview sound"
                        enabled: !root.host.demo && !!root.host.media && typeof root.host.media.previewSound === "function" && !root.host.displaySettings.quietMode && !(root.host.inbox && root.host.inbox.dnd)
                        ink: root.host.ink
                        surface: root.host.surface
                        onClicked: root.host.media.previewSound()
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: !!root.host.media && root.host.media.alertMessage !== undefined && root.host.media.alertMessage !== ""
                        text: visible ? root.host.media.alertMessage : ""
                        textFormat: Text.PlainText
                        color: Qt.alpha(root.host.ink, 0.7)
                        font.pixelSize: Style.space(11)
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Inbox Do Not Disturb also silences Perch sounds. Sound playback needs canberra-gtk-play."
                        color: Qt.alpha(root.host.ink, 0.55)
                        font.pixelSize: Style.space(11)
                        wrapMode: Text.Wrap
                    }
                    PerchAction {
                        text: "Integration setup…"
                        ink: root.host.ink
                        surface: root.host.surface
                        onClicked: {
                            root.host.settingsOpen = false;
                            root.host.page = "setup";
                        }
                    }
                }
                ModuleSettings {
                    visible: root.section === "modules" || root.section === "plugins"
                    Layout.fillWidth: true
                    showModules: root.section === "modules"
                    showPlugins: root.section === "plugins"
                    pluginState: root.host.pluginState
                    items: root.host.moduleItems
                    shortcuts: root.host.moduleShortcuts
                    onShortcutChanged: bindings => root.host.preferenceChanged("moduleShortcuts", bindings)
                    ink: root.host.ink
                    surface: root.host.surface
                    onChanged: order => root.host.preferenceChanged("modules", order)
                }
            }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Qt.alpha(root.host.ink, 0.12)
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        elide: Text.ElideRight
        text: root.host.settingsError || (root.host.pluginState ? root.host.pluginState.error : "") || (root.host.demo ? "Demo · fictional data" : "Saved automatically in Omarchy settings")
        textFormat: Text.PlainText
        color: Qt.alpha(root.host.ink, 0.65)
        font.pixelSize: Style.space(10)
    }
    onSectionChanged: {
        if (scroll.contentItem && scroll.contentItem.contentY !== undefined)
            scroll.contentItem.contentY = 0;
    }
}
