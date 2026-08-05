// One segment of a segmented option row (mkv | mp4 | webm).
pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.components

Rectangle {
    id: seg
    property string label
    property bool on: false
    signal picked()

    implicitWidth: segText.implicitWidth + 22
    implicitHeight: 28
    radius: 9
    color: seg.on ? Config.accent : Config.surface
    Behavior on color { ColorAnim {} }

    Text {
        id: segText
        anchors.centerIn: parent
        text: seg.label
        color: seg.on ? Config.accentText : Config.dim
        font.family: Config.textFont; font.pixelSize: 11; font.bold: seg.on
    }

    StateLayer { ovRadius: 9; tint: seg.on ? Config.accentText : Config.fg; onTapped: seg.picked() }
}
