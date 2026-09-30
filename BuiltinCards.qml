import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import "MediaPolicy.js" as Policy

// Trusted built-in cards. The host owns navigation and shared service state.
Item {
    id: cards
    required property var host
    property Component hubCard: Component {
        ToolsView {
            host: cards.host
        }
    }
    property Component shelfCard: Component {
        Item {
            implicitHeight: Style.space(304)
            property color ink
            property color surface
            ShelfView {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    bottom: feedback.top
                    bottomMargin: Style.space(8)
                }
                onInteractionChanged: active => cards.host.interactionActive = active
                work: cards.host.work
                ink: cards.host.ink
                surface: cards.host.surface
            }
            Text {
                id: feedback
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                text: cards.host.work ? (cards.host.work.busy ? PerchStrings.t("Working…") : cards.host.work.error || cards.host.work.message) : "Demo: integration unavailable"
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Qt.alpha(cards.host.ink, 0.6)
                font.pixelSize: Style.space(10)
            }
        }
    }
    property Component calendarCard: Component {
        Item {
            implicitHeight: Style.space(304)
            property color ink
            property color surface
            CalendarView {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    bottom: feedback.top
                    bottomMargin: Style.space(8)
                }
                onInteractionChanged: active => cards.host.interactionActive = active
                work: cards.host.work
                ink: cards.host.ink
                surface: cards.host.surface
            }
            Text {
                id: feedback
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                text: cards.host.work ? (cards.host.work.busy ? PerchStrings.t("Working…") : cards.host.work.error || cards.host.work.message) : "Demo: integration unavailable"
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Qt.alpha(cards.host.ink, 0.6)
                font.pixelSize: Style.space(10)
            }
        }
    }
    property Component setupCard: Component {
        Item {
            implicitHeight: Style.space(304)
            property color ink
            property color surface
            SetupView {
                codexServer: cards.host.media && cards.host.media.codexServer !== undefined ? cards.host.media.codexServer : null
                relay: cards.host.media && cards.host.media.relay !== undefined ? cards.host.media.relay : null
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    bottom: feedback.top
                    bottomMargin: Style.space(8)
                }
                work: cards.host.work
                ink: cards.host.ink
                surface: cards.host.surface
            }
            Text {
                id: feedback
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                text: cards.host.work ? (cards.host.work.busy ? PerchStrings.t("Working…") : cards.host.work.error || cards.host.work.message) : "Demo: integration unavailable"
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Qt.alpha(cards.host.ink, 0.6)
                font.pixelSize: Style.space(10)
            }
        }
    }
    property Component inboxCard: Component {
        Item {
            implicitHeight: Style.space(304)
            property color ink
            property color surface
            InboxView {
                anchors.fill: parent
                onPopupToggled: open => cards.host.popupOpen = open
                inbox: cards.host.inbox
                ink: cards.host.ink
                surface: cards.host.surface
            }
        }
    }
    property Component lyricsCard: Component {
        Item {
            implicitHeight: children.length ? children[0].implicitHeight : 0
            property color ink
            property color surface
            Controls.ScrollView {
                anchors.fill: parent
                clip: true
                contentWidth: availableWidth
                Text {
                    width: parent.width
                    text: cards.host.media && cards.host.media.plainLyrics ? cards.host.media.plainLyrics : cards.host.media && cards.host.media.lyrics ? cards.host.media.lyrics.map(function (l) {
                        return l.text;
                    }).join("\n") : "Choose a lyrics file from the music page."
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    color: cards.host.ink
                    font.pixelSize: Style.space(13)
                }
            }
        }
    }
    property Component desktopCard: Component {
        Item {
            implicitHeight: Style.space(304)
            property color ink
            property color surface
            DesktopView {
                anchors.fill: parent
                onPopupToggled: open => cards.host.popupOpen = open
                work: cards.host.work
                desktop: cards.host.desktop
                ink: cards.host.ink
                surface: cards.host.surface
                onLaunched: cards.host.collapseRequested()
            }
        }
    }
    property Component timerCard: Component {
        Item {
            implicitHeight: children.length ? children[0].implicitHeight : 0
            property color ink
            property color surface
            TimerView {
                anchors.fill: parent
                onPopupToggled: open => cards.host.popupOpen = open
                live: cards.host.live
                ink: cards.host.ink
                surface: cards.host.surface
            }
        }
    }
    property Component systemCard: Component {
        Item {
            implicitHeight: Style.space(304)
            property color ink
            property color surface
            SystemView {
                anchors.fill: parent
                onPopupToggled: open => cards.host.popupOpen = open
                work: cards.host.work
                system: cards.host.system
                ink: cards.host.ink
                surface: cards.host.surface
            }
        }
    }
    property Component activityCard: Component {
        Item {
            implicitHeight: children.length ? children[0].implicitHeight : 0
            property color ink
            property color surface
            Controls.ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth
                clip: true
                ActivityView {
                    onReviewRequested: id => {
                        cards.host.eventId = id;
                        cards.host.page = "event";
                    }
                    width: parent.width
                    live: cards.host.live
                    ink: cards.host.ink
                    surface: cards.host.surface
                }
            }
        }
    }
    property Component playersCard: Component {
        Item {
            implicitHeight: children.length ? children[0].implicitHeight : 0
            property color ink
            property color surface
            Controls.ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth
                clip: true
                PlayersView {
                    width: parent.width
                    media: cards.host.media
                    ink: cards.host.ink
                    surface: cards.host.surface
                    onSelected: cards.host.page = "music"
                }
            }
        }
    }
    property Component musicCard: Component {
        Item {
            implicitHeight: children.length ? children[0].implicitHeight : 0
            property color ink
            property color surface
            Controls.ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    width: parent.width
                    spacing: Style.space(14)
                    RowLayout {
                        spacing: Style.space(14)
                        Rectangle {
                            Layout.preferredWidth: Style.space(cards.host.hasPlayer ? 52 : 40)
                            Layout.preferredHeight: width
                            radius: Style.space(10)
                            color: Qt.alpha(cards.host.ink, 0.07)
                            clip: true
                            PerchIcon {
                                anchors.centerIn: parent
                                name: "music"
                                ink: Qt.alpha(cards.host.ink, 0.65)
                                width: Style.space(24)
                                height: width
                            }
                            Image {
                                anchors.fill: parent
                                source: cards.host.hasPlayer ? cards.host.media.art : ""
                                sourceSize.width: 128
                                sourceSize.height: 128
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: cards.host.hasPlayer && cards.host.media.canRaise
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: cards.host.media.raisePlayer()
                                Accessible.role: Accessible.Button
                                Accessible.name: "Open media player"
                                Accessible.onPressAction: if (enabled)
                                    cards.host.media.raisePlayer()
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(5)
                            Text {
                                Layout.fillWidth: true
                                text: cards.host.caption
                                textFormat: Text.PlainText
                                color: cards.host.ink
                                font.family: Style.font.family
                                font.pixelSize: Style.space(14)
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: cards.host.hasPlayer ? cards.host.media.artist : PerchStrings.t("Play music or a video.\nYour controls will appear here.")
                                textFormat: Text.PlainText
                                color: Qt.alpha(cards.host.ink, 0.55)
                                font.family: Style.font.family
                                font.pixelSize: Style.space(11)
                                wrapMode: cards.host.hasPlayer ? Text.NoWrap : Text.WordWrap
                                elide: Text.ElideRight
                            }
                        }
                    }
                    RowLayout {
                        objectName: "transport"
                        visible: cards.host.hasPlayer
                        Layout.fillWidth: true
                        spacing: Style.space(10)
                        Text {
                            Layout.fillWidth: true
                            text: cards.host.playing ? PerchStrings.t("Playing") : PerchStrings.t("Paused")
                            color: Qt.alpha(cards.host.ink, 0.45)
                            font.pixelSize: Style.space(10)
                        }
                        NotchButton {
                            glyph: "previous"
                            label: PerchStrings.t("Previous track")
                            ink: cards.host.ink
                            surface: cards.host.surface
                            enabled: cards.host.hasPlayer && cards.host.media.canPrevious
                            onClicked: cards.host.media.act("previous")
                        }
                        NotchButton {
                            objectName: "playback"
                            glyph: cards.host.playing ? "pause" : "play"
                            label: cards.host.playing ? PerchStrings.t("Pause") : PerchStrings.t("Play")
                            prominent: true
                            ink: cards.host.ink
                            surface: cards.host.surface
                            enabled: cards.host.hasPlayer && cards.host.media.canToggle
                            onClicked: cards.host.media.act("toggle")
                        }
                        NotchButton {
                            glyph: "next"
                            label: PerchStrings.t("Next track")
                            ink: cards.host.ink
                            surface: cards.host.surface
                            enabled: cards.host.hasPlayer && cards.host.media.canNext
                            onClicked: cards.host.media.act("next")
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        NotchButton {
                            visible: cards.host.hasPlayer
                            glyph: "players"
                            label: PerchStrings.t("Switch player")
                            ink: cards.host.ink
                            surface: cards.host.surface
                            onClicked: cards.host.page = "players"
                        }
                    }
                    RowLayout {
                        visible: cards.host.hasPlayer && cards.host.media.timeline
                        Layout.fillWidth: true
                        spacing: Style.space(10)
                        Text {
                            text: cards.host.hasPlayer ? Policy.time(cards.host.media.position) : ""
                            color: Qt.alpha(cards.host.ink, 0.45)
                            font.pixelSize: Style.space(9)
                        }
                        PerchSlider {
                            id: seek
                            objectName: "seek"
                            Layout.fillWidth: true
                            ink: cards.host.ink
                            enabled: cards.host.hasPlayer && cards.host.media.canSeek
                            property string capturedPlayer: ""
                            property string capturedTrack: ""
                            value: cards.host.hasPlayer && cards.host.media.timeline ? Policy.progress(cards.host.media.position, cards.host.media.duration) : 0
                            Accessible.name: "Track position"
                            onPressedChanged: {
                                if (pressed) {
                                    capturedPlayer = cards.host.media.playerKey;
                                    capturedTrack = cards.host.media.trackKey;
                                } else if (cards.host.hasPlayer)
                                    cards.host.media.seekTo(value * cards.host.media.duration, capturedPlayer, capturedTrack);
                            }
                            onMoved: if (!pressed && cards.host.hasPlayer)
                                cards.host.media.seekTo(value * cards.host.media.duration, cards.host.media.playerKey, cards.host.media.trackKey)
                        }
                        Text {
                            text: cards.host.hasPlayer ? Policy.time(cards.host.media.duration) : ""
                            color: Qt.alpha(cards.host.ink, 0.45)
                            font.pixelSize: Style.space(9)
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: cards.host.media && cards.host.media.lyricLine !== undefined ? cards.host.media.lyricLine : ""
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Qt.alpha(cards.host.ink, 0.65)
                            font.pixelSize: Style.space(11)
                        }
                        RowLayout {
                            PerchAction {
                                text: PerchStrings.t("Load lyrics")
                                ink: cards.host.ink
                                surface: cards.host.surface
                                enabled: cards.host.hasPlayer && !cards.host.demo
                                onClicked: cards.host.openLyrics()
                            }
                            PerchAction {
                                text: PerchStrings.t("Read lyrics")
                                ink: cards.host.ink
                                surface: cards.host.surface
                                enabled: !!cards.host.media && !!cards.host.media.lyrics && cards.host.media.lyrics.length > 0
                                onClicked: cards.host.page = "lyrics"
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: cards.host.media && cards.host.media.mediaError !== undefined ? cards.host.media.mediaError : ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Qt.alpha(cards.host.ink, 0.5)
                        font.pixelSize: Style.space(10)
                    }
                    Text {
                        visible: text !== ""
                        Layout.fillWidth: true
                        text: cards.host.available ? cards.host.media.actionError : ""
                        textFormat: Text.PlainText
                        color: cards.host.ink
                        font.pixelSize: Style.space(10)
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
