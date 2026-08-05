// Clickable icon button with hover + active state.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
Rectangle {
    id: btn
    property string icon
    property color tint: Config.fg
    property bool active: false
    property int iconSize: 16
    signal clicked()
    signal hoverIn()
    signal hoverOut()
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: 32; implicitHeight: 32; radius: 9
    color: active ? Config.accent : (btnMa.containsMouse ? Config.container : "transparent")
    Behavior on color { ColorAnim {} }
    MatIcon {
        anchors.centerIn: parent
        text: btn.icon
        font.pixelSize: btn.iconSize
        color: btn.active ? Config.accentText : btn.tint
    }
    MouseArea {
        id: btnMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
        onEntered: btn.hoverIn()
        onExited: btn.hoverOut()
    }
}
