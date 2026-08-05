// Horizontal slider (draggable fill).
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
Rectangle {
    id: hs
    property real value: 0
    property color fill: Config.accent
    signal moved(real v)
    Layout.fillWidth: true
    implicitHeight: 8
    radius: 4
    color: Config.track
    Rectangle {
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        width: parent.width * Math.max(0, Math.min(1, hs.value)); height: parent.height
        radius: 4; color: hs.fill
        Behavior on width { Effect {} }
    }
    MouseArea {
        anchors.fill: parent; anchors.topMargin: -7; anchors.bottomMargin: -7
        cursorShape: Qt.PointingHandCursor
        function setv(x) { hs.moved(Math.max(0, Math.min(1, x / width))); }
        onPressed: e => setv(e.x)
        onPositionChanged: e => setv(e.x)
    }
}
