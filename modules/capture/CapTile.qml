// Capture-panel tile (icon over label): source and mode pickers, laid out in a row.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components

Rectangle {
    id: tile
    property string icon
    property string label
    property bool on: false
    property bool focused: false
    signal picked()

    implicitWidth: 104
    implicitHeight: 68
    radius: 14
    color: tile.on ? Config.accent : Config.container
    Behavior on color { ColorAnim {} }

    // Keyboard focus ring, drawn inside the fill so it never changes the tile's footprint.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: 2
        border.color: tile.focused ? Config.focusRing : "transparent"
        Behavior on border.color { ColorAnim {} }
    }

    Column {
        anchors.centerIn: parent
        spacing: 4
        MatIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.icon; font.pixelSize: 22
            color: tile.on ? Config.accentText : Config.fg
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.label
            color: tile.on ? Config.accentText : Config.dim
            font.family: Config.textFont; font.pixelSize: 11
        }
    }

    StateLayer { ovRadius: 14; tint: tile.on ? Config.accentText : Config.fg; onTapped: tile.picked() }
}
