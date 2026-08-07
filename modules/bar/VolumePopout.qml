// Volume popout: vertical slider + mute.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

BarPopout {
    id: pop
    name: "volume"
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
            text: Audio.muted ? "muted" : Math.round(Audio.volume * 100) + "%"
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
                height: parent.height * Math.min(1, Audio.volume)
                radius: 5
                color: Audio.muted ? Config.dim : Config.accent
            }
            MouseArea {
                anchors.fill: parent
                function setVol(y) { Audio.setVolume(1 - y / height); }
                onPressed: e => setVol(e.y)
                onPositionChanged: e => setVol(e.y)
            }
        }

        MatIcon {
            Layout.alignment: Qt.AlignHCenter
            text: Audio.muted ? "volume_off" : "volume_up"
            color: Audio.muted ? Config.dim : Config.fg
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.toggleMute()
            }
        }
    }
}
