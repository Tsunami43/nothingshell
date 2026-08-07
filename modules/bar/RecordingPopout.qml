// Recording popout: elapsed time, pause and stop.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

BarPopout {
    id: pop
    name: "rec"
    // `stopping` too: muxing after a stop is neither recording nor a reason to keep this open.
    available: Capture.active && !Capture.stopping
    implicitWidth: 150
    bodyHeight: 128

    // The widget vanishes on stop, so the hover-out that closes the others never arrives.
    onDismissed: if (pop.bar.popout === "rec") pop.bar.popout = ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        anchors.topMargin: 12 + Config.popFillet * 2 - pop.botPad
        anchors.bottomMargin: 12 + pop.botPad
        spacing: 6

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Capture.elapsedText
            color: Capture.paused ? Config.warning : Config.error
            font.family: Config.textFont; font.pixelSize: 20; font.bold: true
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: (Capture.paused ? "paused · " : "") + (Capture.source === "region" ? "region" : "screen") + " · " + Config.recFormat
            color: Config.dim
            font.family: Config.textFont; font.pixelSize: 10
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            spacing: 8
            IconBtn {
                icon: Capture.paused ? "play_arrow" : "pause"
                label: Capture.paused ? "Resume recording" : "Pause recording"
                tint: Config.warning
                onClicked: Capture.togglePause()
            }
            // Stopping saves the file rather than destroying anything, so no hold-to-confirm.
            IconBtn {
                icon: "stop"
                label: "Stop recording"
                tint: Config.error
                onClicked: Capture.stop()
            }
        }
    }
}
