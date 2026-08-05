//@ pragma UseQApplication
// greetd greeter — the lock screen's twin: same video wallpaper, clock and password
// field, but it authenticates through greetd and launches the session on success.
// Run by greetd as the `greeter` user: qs -p ~/.config/quickshell/greeter (install.sh bakes
// the real absolute path into /etc/greetd/hyprland.conf).
// Under a normal user greetd is unavailable, so it just previews the UI (Esc quits).
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
// The shell's palette, fonts and widgets are reused verbatim, so the greeter and the lock screen
// look identical. This file is a SECOND entry point inside the same config root — quickshell can
// be pointed at a .qml file rather than a directory — which is why it imports the shell the same
// way every other file does. The old shape was a separate config directory with a symlink into
// this tree, which is what a symlink into a parent always is: a workaround for being outside.
import qs
import qs.components
import qs.greeter

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            // The login card lives on one output only; the others just show the wallpaper.
            readonly property bool primary: modelData === Quickshell.screens[0]

            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: Config.bg
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "greeter"
            WlrLayershell.keyboardFocus: win.primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // Live video background (same clips the desktop and lock screen use).
            VideoWall {
                anchors.fill: parent
                visible: Config.videoWallpaper.length > 0
                file: Config.videoWallpaper
            }
            // Scrim so the clock + password stay readable over the video.
            Rectangle {
                anchors.fill: parent
                visible: Config.videoWallpaper.length > 0
                color: Config.scrim
            }

            property var now: new Date()
            // hh:mm only — tick on the minute boundary, as the lock screen does.
            Timer {
                id: minuteTick
                interval: 60000 - (Date.now() % 60000)
                running: true
                onTriggered: {
                    win.now = new Date();
                    minuteTick.interval = 60000 - (Date.now() % 60000);
                    minuteTick.restart();
                }
            }

            property bool showPw: false   // reveal the typed password

            Component.onCompleted: if (win.primary) pwField.forceActiveFocus()

            ColumnLayout {
                anchors.centerIn: parent
                width: 300
                spacing: 14
                // Fade everything in on start.
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { Anim { type: Anim.Effect } }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(win.now, "hh:mm")
                    color: Config.fg; font.family: Config.textFont; font.pixelSize: 68; font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 12
                    text: Qt.formatDateTime(win.now, "dddd, d MMMM")
                    color: Config.dim; font.family: Config.textFont; font.pixelSize: 15
                }

                // Avatar + account name: this greeter only ever logs in Greet.user.
                Rectangle {
                    visible: win.primary
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 64; implicitHeight: 64
                    radius: width / 2
                    color: Config.container
                    border.width: 1
                    border.color: Config.outline

                    MatIcon {
                        anchors.centerIn: parent
                        text: "person"
                        font.pixelSize: 34
                        color: Config.accent
                    }
                }
                Text {
                    visible: win.primary
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 4
                    text: Greet.user
                    color: Config.fg; font.family: Config.textFont; font.pixelSize: 16
                }

                Rectangle {
                    visible: win.primary
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 260; implicitHeight: 46
                    radius: 12
                    color: Config.container
                    border.width: 1
                    border.color: Greet.error.length > 0 ? Config.error : (pwField.activeFocus ? Config.accent : Config.outline)

                    TextInput {
                        id: pwField
                        anchors.fill: parent
                        anchors.leftMargin: 16; anchors.rightMargin: 44
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: win.showPw ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        color: Config.fg
                        font.family: Config.textFont; font.pixelSize: 15
                        enabled: !Greet.busy && !Greet.launching
                        focus: true
                        clip: true
                        text: Greet.password
                        onTextEdited: Greet.password = text
                        onAccepted: Greet.submit()
                        // Esc is only an escape hatch for the preview run; a real greeter
                        // has nothing to quit back to.
                        Keys.onEscapePressed: if (!Greet.available) Qt.quit()
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 16
                        visible: pwField.text.length === 0
                        text: Greet.launching ? "Starting session…" : (Greet.busy ? "Checking…" : "Password")
                        color: Config.dim; font.family: Config.textFont; font.pixelSize: 15
                    }
                    // Reveal / hide the typed password.
                    MatIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right; anchors.rightMargin: 12
                        text: win.showPw ? "visibility_off" : "visibility"
                        font.pixelSize: 20
                        color: revealMa.containsMouse ? Config.fg : Config.dim
                        visible: pwField.text.length > 0
                        MouseArea {
                            id: revealMa
                            anchors.fill: parent; anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { win.showPw = !win.showPw; pwField.forceActiveFocus(); }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: win.primary && Greet.error.length > 0
                    text: Greet.error
                    color: Config.error; font.family: Config.textFont; font.pixelSize: 12
                }
            }

            // Power actions, bottom-right. polkit lets the active seat's greeter session do these.
            RowLayout {
                visible: win.primary
                anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.margins: 28
                spacing: 8

                Repeater {
                    model: [
                        { icon: "restart_alt",        cmd: ["systemctl", "reboot"] },
                        { icon: "power_settings_new", cmd: ["systemctl", "poweroff"] }
                    ]

                    Rectangle {
                        id: powerBtn
                        required property var modelData
                        implicitWidth: 44; implicitHeight: 44
                        radius: width / 2
                        color: powerMa.containsMouse ? Config.container : Config.scrim
                        border.width: 1
                        border.color: Config.outline
                        Behavior on color { ColorAnim {} }

                        MatIcon {
                            anchors.centerIn: parent
                            text: powerBtn.modelData.icon
                            font.pixelSize: 20
                            color: powerMa.containsMouse ? Config.accent : Config.fg
                        }
                        MouseArea {
                            id: powerMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(powerBtn.modelData.cmd)
                        }
                    }
                }
            }
        }
    }
}
