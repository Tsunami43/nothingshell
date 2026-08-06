// Screen-lock surface: clock, password field, error. Auth lives in the Lock service.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs
import qs.components
import qs.services

WlSessionLock {
    id: sessionLock
    locked: Lock.locked

    WlSessionLockSurface {
        id: lockSurface
        color: Config.bg

        // The video's still, for when the decoder is stopped (battery saver).
        Image {
            anchors.fill: parent
            visible: Config.videoWallpaperPoster !== "" && !Power.videoWallpaper
            source: visible ? Config.videoWallpaperPoster : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize: Qt.size(width, height)
        }

        // Live video background, paused while the outputs are blanked — most of a lock's life.
        VideoWall {
            anchors.fill: parent
            visible: Config.videoWallpaper.length > 0
            active: Power.videoWallpaper && !Idle.displaysOff
            file: Config.videoWallpaper
        }
        // Scrim so the clock + password stay readable over the video.
        Rectangle {
            anchors.fill: parent
            visible: Config.videoWallpaper.length > 0
            color: Config.scrim
        }

        property var now: new Date()
        // hh:mm and a date — a minute-aligned tick, like the bar and the desktop clock.
        Timer {
            id: lockMinuteTick
            interval: 60000 - (Date.now() % 60000)
            running: true
            onTriggered: {
                lockSurface.now = new Date();
                lockMinuteTick.interval = 60000 - (Date.now() % 60000);
                lockMinuteTick.restart();
            }
        }

        property bool showPw: false   // reveal the typed password

        // Focus the password field whenever the lock appears (and hide any revealed password).
        onVisibleChanged: if (visible) { lockSurface.showPw = false; pwField.forceActiveFocus(); }

        ColumnLayout {
            anchors.centerIn: parent
            width: 300
            spacing: 14
            // Fade the clock + password in when the lock appears.
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { Anim { type: Anim.Effect } }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(lockSurface.now, "hh:mm")
                color: Config.fg; font.family: Config.textFont; font.pixelSize: 68; font.bold: true
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 12
                text: Qt.formatDateTime(lockSurface.now, "dddd, d MMMM")
                color: Config.dim; font.family: Config.textFont; font.pixelSize: 15
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 260; implicitHeight: 46
                radius: 12
                color: Config.container
                border.width: 1
                border.color: Lock.error.length > 0 ? Config.error : (pwField.activeFocus ? Config.accent : Config.outline)

                TextInput {
                    id: pwField
                    anchors.fill: parent
                    anchors.leftMargin: 16; anchors.rightMargin: 44
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: lockSurface.showPw ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    color: Config.fg
                    font.family: Config.textFont; font.pixelSize: 15
                    enabled: !Lock.busy
                    focus: true
                    clip: true
                    text: Lock.password
                    onTextEdited: Lock.password = text
                    onAccepted: Lock.submit()
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 16
                    visible: pwField.text.length === 0
                    text: Lock.busy ? "Checking…" : "Password"
                    color: Config.dim; font.family: Config.textFont; font.pixelSize: 15
                }
                // Reveal / hide the typed password.
                MatIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right; anchors.rightMargin: 12
                    text: lockSurface.showPw ? "visibility_off" : "visibility"
                    font.pixelSize: 20
                    color: revealMa.containsMouse ? Config.fg : Config.dim
                    visible: pwField.text.length > 0
                    MouseArea {
                        id: revealMa
                        anchors.fill: parent; anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { lockSurface.showPw = !lockSurface.showPw; pwField.forceActiveFocus(); }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: Lock.error.length > 0
                text: Lock.error
                color: Config.error; font.family: Config.textFont; font.pixelSize: 12
            }
        }
    }
}
