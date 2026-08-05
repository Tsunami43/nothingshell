// Tappable navigation row: icon + label + optional status + chevron. Emits clicked().
// Setting actionIcon adds a button before the chevron for the row's primary action, so it
// can be reached without opening the sub-page. The state layer sits below the content, or
// it would swallow that button's clicks.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
ConnectedRect {
    id: row
    property string icon: ""
    property string label: ""
    property string status: ""
    property string actionIcon: ""
    property color actionTint: Config.fg
    signal clicked()
    signal actionClicked()
    Layout.fillWidth: true
    implicitHeight: 54
    StateLayer { onTapped: row.clicked() }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        spacing: 12
        MatIcon { visible: row.icon !== ""; text: row.icon; color: Config.fg; font.pixelSize: 20 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                text: row.label; color: Config.fg; font.family: Config.textFont; font.pixelSize: 13; font.bold: true
                Layout.fillWidth: true; elide: Text.ElideRight
            }
            Text {
                visible: row.status !== ""; text: row.status; color: Config.dim
                font.family: Config.textFont; font.pixelSize: 11
                Layout.fillWidth: true; elide: Text.ElideRight
            }
        }
        IconBtn {
            visible: row.actionIcon !== ""
            icon: row.actionIcon; tint: row.actionTint; iconSize: 18
            onClicked: row.actionClicked()
        }
        MatIcon { text: "chevron_right"; color: Config.dim; font.pixelSize: 20 }
    }
}
