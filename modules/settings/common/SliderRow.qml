// Row with an icon + label + value readout and a horizontal slider. Emits moved(v) in 0..1.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
ConnectedRect {
    id: row
    property string icon: ""
    property string label: ""
    property real value: 0
    property string valueText: Math.round(row.value * 100) + "%"
    signal moved(real v)
    Layout.fillWidth: true
    implicitHeight: 60
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 8
        anchors.bottomMargin: 10
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            MatIcon { visible: row.icon !== ""; text: row.icon; color: Config.dim; font.pixelSize: 18 }
            Text {
                text: row.label; color: Config.fg; font.family: Config.textFont; font.pixelSize: 13
                Layout.fillWidth: true; elide: Text.ElideRight
            }
            Text { text: row.valueText; color: Config.dim; font.family: Config.textFont; font.pixelSize: 12 }
        }
        HSlider { value: row.value; onMoved: v => row.moved(v) }
    }
}
