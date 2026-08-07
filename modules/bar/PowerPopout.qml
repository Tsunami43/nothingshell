// Power popout: the session actions, each on a half-second hold so a stray click can't reboot.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

BarPopout {
    id: pop
    name: "power"
    implicitWidth: 208
    bodyHeight: powerCol.implicitHeight + 24

    // Kept in step both ways, so `ipc call session toggle` closes a hover-opened menu.
    onOpened: Shell.sessionVisible = true
    onClosed: Shell.sessionVisible = false

    // Mirror the IPC flag onto the popout slot rather than owning a second state.
    Connections {
        target: Shell
        function onSessionVisibleChanged() {
            if (Shell.sessionVisible) pop.bar.showPopout("power");
            else if (pop.bar.popout === "power") pop.bar.popout = "";
        }
    }

    ColumnLayout {
        id: powerCol
        anchors { top: parent.top; left: parent.left; right: parent.right
                  topMargin: 12 + Config.popFillet * 2 - pop.botPad; leftMargin: 10; rightMargin: 10 }
        spacing: 2

        Repeater {
            model: pop.bar.sessionActions
            // A row, not a button: only a wash under the cursor in the action's own colour.
            Item {
                id: pbtn
                required property var modelData
                required property int index
                readonly property color tone: pop.bar.sessionTones[pbtn.index]
                readonly property bool holding: pbtnMa.pressed
                property real fill: 0
                Layout.fillWidth: true
                implicitHeight: 38

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: pbtn.tone
                    opacity: pbtn.holding ? 0.20 : (pbtnMa.containsMouse ? 0.11 : 0)
                    Behavior on opacity { Anim { type: Anim.Effect } }
                }

                onHoldingChanged: {
                    if (pbtn.holding) { pbtn.fill = 0; pfillAnim.restart(); }
                    else { pfillAnim.stop(); pbtn.fill = 0; }
                }
                NumberAnimation {
                    id: pfillAnim
                    target: pbtn; property: "fill"; from: 0; to: 1; duration: 500
                    onFinished: { Shell.sessionVisible = false; pop.bar.popout = ""; pbtn.modelData.run(); }
                }

                // Hold progress: a rail under the row, not a flood of the whole row.
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                              leftMargin: 10; rightMargin: 10; bottomMargin: 3 }
                    height: 2; radius: 1
                    color: Config.outline
                    opacity: pbtn.holding ? 1 : 0
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: parent.width * pbtn.fill
                        radius: 1
                        color: pbtn.tone
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 12
                    MatIcon { text: pbtn.modelData.icon; font.pixelSize: 19; color: pbtn.tone }
                    Text {
                        Layout.fillWidth: true
                        text: pbtn.modelData.label
                        color: Config.fg; font.family: Config.textFont; font.pixelSize: 13
                    }
                }

                MouseArea {
                    id: pbtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
