// Compact label + switch for the capture settings sheet. settings/common/ToggleRow is the same idea
// at 52px with its own card background, which is too heavy for a dense inline sheet.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components

RowLayout {
    id: row
    property string label
    property bool checked: false
    signal toggled()

    Layout.fillWidth: true
    spacing: 10
    implicitHeight: 28

    Text {
        Layout.preferredWidth: 78
        text: row.label
        color: Config.dim
        font.family: Config.textFont; font.pixelSize: 11
    }
    Rectangle {
        implicitWidth: 38; implicitHeight: 22; radius: 11
        color: row.checked ? Config.accent : Config.switchTrackOff
        Behavior on color { ColorAnim {} }
        Rectangle {
            width: 16; height: 16; radius: 8; y: 3
            x: row.checked ? parent.width - width - 3 : 3
            color: row.checked ? Config.accentText : Config.dim
            Behavior on x { Spatial {} }
            Behavior on color { ColorAnim {} }
        }
        StateLayer { ovRadius: 11; onTapped: row.toggled() }
    }
    Item { Layout.fillWidth: true }
}
