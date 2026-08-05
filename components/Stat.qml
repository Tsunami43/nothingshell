// Compact vertical stat: icon over a small value.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
ColumnLayout {
    id: stat
    property string icon
    property string value
    property color tint: Config.tertiary
    Layout.alignment: Qt.AlignHCenter
    spacing: -1
    MatIcon {
        Layout.alignment: Qt.AlignHCenter
        text: stat.icon
        font.pixelSize: 15
        color: stat.tint
    }
    Text {
        Layout.alignment: Qt.AlignHCenter
        text: stat.value
        font.family: Config.textFont
        font.pixelSize: 9
        color: Config.dim
    }
}
