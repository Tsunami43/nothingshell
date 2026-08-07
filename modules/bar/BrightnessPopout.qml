// Brightness popout: vertical slider over whichever backlight services/Brightness.qml found.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

BarPopout {
    id: pop
    name: "brightness"
    implicitWidth: 64
    bodyHeight: 220

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        anchors.topMargin: 12 + Config.popFillet * 2 - pop.botPad
        anchors.bottomMargin: 12 + pop.botPad
        spacing: 10

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Brightness.brightness + "%"
            color: Config.fg
            font.family: Config.textFont; font.pixelSize: 12; font.bold: true
        }
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            implicitWidth: 10
            radius: 5
            color: Config.track
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * (Brightness.brightness / 100)
                radius: 5
                color: Config.accent
            }
            MouseArea {
                anchors.fill: parent
                function setBri(y) { Brightness.set((1 - y / height) * 100); }
                onPressed: e => setBri(e.y)
                onPositionChanged: e => setBri(e.y)
            }
        }
        MatIcon {
            Layout.alignment: Qt.AlignHCenter
            text: "brightness_medium"
            color: Config.fg
        }
    }
}
