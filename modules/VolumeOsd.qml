// Bottom-centre volume/brightness level bar, shown briefly on change.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: osdWin
    required property var modelData
    screen: modelData
    anchors { bottom: true }
    // The window is padded all round so the body's drop shadow has room to fall off
    // instead of being clipped at the surface edge; the margin cancels the padding, so
    // the visible card sits exactly where it did before.
    readonly property int pad: 28
    margins.bottom: 64 - pad
    implicitWidth: 300 + pad * 2
    implicitHeight: 56 + pad * 2
    color: "transparent"
    readonly property bool shown: Osd.kind !== ""
    visible: shown || osdBody.opacity > 0.01   // stay mapped through the fade-out
    exclusiveZone: 0
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property bool isBri: Osd.kind === "brightness"
    readonly property real frac: isBri ? (Brightness.brightness / 100) : Math.min(1, Audio.volume)

    Rectangle {
        id: osdBody
        anchors.fill: parent
        anchors.margins: osdWin.pad
        radius: 18
        // Matches MediaOsd / the Frame fill — the two OSDs stack and must read as one family.
        color: Config.bg
        border.width: 1; border.color: Config.outline

        Elevation { anchors.fill: parent; radius: parent.radius; z: -1; level: 5 }
        // Reveal: fade + a small slide up from below.
        opacity: osdWin.shown ? 1 : 0
        Behavior on opacity { Anim { type: Anim.Effect } }
        transform: Translate { y: osdWin.shown ? 0 : 16; Behavior on y { Anim { type: Anim.Spatial } } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18; anchors.rightMargin: 18
            spacing: 12
            MatIcon {
                text: osdWin.isBri ? "brightness_medium"
                    : (Audio.muted ? "volume_off" : (Audio.volume > 0.5 ? "volume_up" : "volume_down"))
                font.pixelSize: 22
                color: (!osdWin.isBri && Audio.muted) ? Config.dim : Config.accent
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6; radius: 3
                color: Config.track
                Rectangle {
                    height: parent.height; radius: 3
                    width: parent.width * osdWin.frac
                    color: (!osdWin.isBri && Audio.muted) ? Config.dim : Config.accent
                    Behavior on width { Effect {} }
                }
            }
            Text {
                text: Math.round(osdWin.frac * 100) + "%"
                color: Config.fg; font.family: Config.textFont; font.pixelSize: 14; font.bold: true
            }
        }
    }
}
