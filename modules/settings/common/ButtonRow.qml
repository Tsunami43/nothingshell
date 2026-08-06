// Row that performs an action rather than holding a value (Apply, Forget, Reboot…). `destructive`
// tints it with the danger role — the palette's "this will undo something" colour, distinct from
// error, which reports that something already went wrong.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
ConnectedRect {
    id: row
    property string icon: ""
    property string label: ""
    property string subtext: ""
    property bool destructive: false
    property bool busy: false
    readonly property color tint: row.destructive ? Config.danger : Config.accent
    signal clicked()
    Accessible.role: Accessible.Button
    Accessible.name: row.label
    Accessible.description: row.subtext
    Accessible.onPressAction: row.clicked()

    Layout.fillWidth: true
    implicitHeight: row.subtext !== "" ? 60 : 52
    opacity: row.enabled ? 1 : 0.45

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16; anchors.rightMargin: 16
        spacing: 12
        MatIcon {
            visible: row.icon !== "" && !row.busy
            text: row.icon; color: row.tint; font.pixelSize: 20
        }
        // Spinner while the action's process is still running.
        MatIcon {
            visible: row.busy
            text: "progress_activity"; color: row.tint; font.pixelSize: 20
            RotationAnimation on rotation {
                running: row.busy; loops: Animation.Infinite
                from: 0; to: 360; duration: 900
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                text: row.label; color: row.tint; font.family: Config.textFont
                font.pixelSize: 13; font.bold: true
                Layout.fillWidth: true; elide: Text.ElideRight
            }
            Text {
                visible: row.subtext !== ""; text: row.subtext; color: Config.dim
                font.family: Config.textFont; font.pixelSize: 11
                Layout.fillWidth: true; elide: Text.ElideRight
            }
        }
    }
    StateLayer {
        tint: row.tint
        enabled: !row.busy
        onTapped: row.clicked()
    }
}
