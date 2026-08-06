// Row with a label (+ optional subtext) and a Material switch. Emits toggled() on tap.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
ConnectedRect {
    id: row
    property string text: ""
    property string subtext: ""
    property bool checked: false
    signal toggled()
    // Assembled from primitives, so role, name and state all have to be stated.
    Accessible.role: Accessible.CheckBox
    Accessible.name: row.text
    Accessible.description: row.subtext
    Accessible.checkable: true
    Accessible.checked: row.checked
    Accessible.onToggleAction: row.toggled()
    Accessible.onPressAction: row.toggled()
    Layout.fillWidth: true
    implicitHeight: subtext !== "" ? 60 : 52
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                text: row.text; color: Config.fg; font.family: Config.textFont; font.pixelSize: 13
                Layout.fillWidth: true; elide: Text.ElideRight
            }
            Text {
                visible: row.subtext !== ""; text: row.subtext; color: Config.dim
                font.family: Config.textFont; font.pixelSize: 11
                Layout.fillWidth: true; elide: Text.ElideRight
            }
        }
        Rectangle {
            implicitWidth: 44; implicitHeight: 26; radius: 13
            color: row.checked ? Config.accent : Config.switchTrackOff
            // The off track and the row it sits on are both `container`, so without an outline an
            // unchecked switch reads as a lone floating dot (M3 outlines it for the same reason).
            border.width: row.checked ? 0 : 1
            border.color: Config.outlineStrong
            Behavior on color { ColorAnim {} }
            Rectangle {
                width: 20; height: 20; radius: 10; y: 3
                x: row.checked ? parent.width - width - 3 : 3
                color: row.checked ? Config.accentText : Config.dim
                Behavior on x { Spatial {} }
                Behavior on color { ColorAnim {} }
            }
        }
    }
    StateLayer { onTapped: row.toggled() }
}
