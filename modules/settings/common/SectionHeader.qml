// Small dimmed section label above a group of Settings rows.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
Text {
    property bool first: false
    Layout.fillWidth: true
    Layout.topMargin: first ? 0 : 12
    Layout.leftMargin: 6
    Layout.bottomMargin: 2
    color: Config.dim
    font.family: Config.textFont
    font.pixelSize: 12
    font.bold: true
}
