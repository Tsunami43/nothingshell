// Bottom-centre "now playing" pop, shown briefly when the track changes.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: mosdWin
    required property var modelData
    screen: modelData
    anchors { bottom: true }
    // Padded like VolumeOsd so the card's shadow is not clipped by the surface edge.
    readonly property int pad: 28
    margins.bottom: 130 - pad
    implicitWidth: 340 + pad * 2
    implicitHeight: 72 + pad * 2
    color: "transparent"
    readonly property bool shown: Osd.media && Media.player !== null
    visible: shown || mosdBody.opacity > 0.01   // stay mapped through the fade-out
    exclusiveZone: 0
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay

    Rectangle {
        id: mosdBody
        anchors.fill: parent
        anchors.margins: mosdWin.pad
        radius: 18
        // Same fill the Frame shader uses, so the pop reads as part of the same surface.
        color: Config.bg
        border.width: 1; border.color: Config.outline

        Elevation { anchors.fill: parent; radius: parent.radius; z: -1; level: 5 }
        // Reveal: fade + a small slide up from below.
        opacity: mosdWin.shown ? 1 : 0
        Behavior on opacity { Anim { type: Anim.Effect } }
        transform: Translate { y: mosdWin.shown ? 0 : 16; Behavior on y { Anim { type: Anim.Spatial } } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 48; Layout.preferredHeight: 48
                radius: 10; color: Config.container; clip: true
                FadeImage {
                    id: mediaOsdArt
                    anchors.fill: parent
                    source: Media.artUrl
                    box: 48
                    visible: ready
                }
                MatIcon { anchors.centerIn: parent; visible: !mediaOsdArt.ready; text: "music_note"; font.pixelSize: 22; color: Config.dim }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                // PlainText: MPRIS metadata is whatever the stream says it is.
                Text {
                    text: Media.trackTitle
                    textFormat: Text.PlainText
                    color: Config.fg; font.family: Config.textFont; font.pixelSize: 14; font.bold: true
                    Layout.fillWidth: true; elide: Text.ElideRight
                }
                Text {
                    visible: (Media.player?.trackArtist ?? "").length > 0
                    text: Media.player?.trackArtist ?? ""
                    textFormat: Text.PlainText
                    color: Config.dim; font.family: Config.textFont; font.pixelSize: 12
                    Layout.fillWidth: true; elide: Text.ElideRight
                }
            }
            MatIcon { text: Media.player?.isPlaying ? "play_arrow" : "pause"; font.pixelSize: 20; color: Config.accent }
        }
    }
}
