// Read-only info row: optional icon + label + right-aligned value.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
ConnectedRect {
    id: row
    property string icon: ""
    property string label: ""
    property string value: ""
    // A fact, not a control.
    Accessible.role: Accessible.StaticText
    Accessible.name: row.label
    Accessible.description: row.value
    Layout.fillWidth: true
    implicitHeight: 46
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12
        MatIcon { visible: row.icon !== ""; text: row.icon; color: Config.dim; font.pixelSize: 18 }
        Text {
            text: row.label; color: Config.fg; font.family: Config.textFont; font.pixelSize: 13
            Layout.fillWidth: true; elide: Text.ElideRight
        }
        Text {
            // PlainText: the value side carries scraped system strings (hostname, GPU model).
            text: row.value; textFormat: Text.PlainText; color: Config.dim; font.family: Config.textFont; font.pixelSize: 13
            horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft; Layout.maximumWidth: parent.width * 0.55
        }
    }
}
