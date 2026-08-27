// A Bluetooth device row (icon badge + name + status) for use as a list delegate.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs
import qs.services
import qs.components
Item {
    id: row
    property var dev
    property string subtitle: ""
    property bool showSettings: false
    // Explicit connect/disconnect affordance. Tapping the row does the same thing, but a paired
    // device that is merely *saved* gives no hint that the row is the disconnect button.
    property bool showConnect: false
    // Corner radii of the card slot this row occupies; the list owner knows them, not the row.
    property real topRadius: 0
    property real bottomRadius: 0
    signal tapped()
    signal settings()
    readonly property bool connected: row.dev && row.dev.state === BluetoothDeviceState.Connected
    width: ListView.view ? ListView.view.width : (parent ? parent.width : 0)
    implicitHeight: 54

    // Below the content: the connect and settings buttons on top of it must get their
    // own clicks.
    StateLayer { ovTopRadius: row.topRadius; ovBottomRadius: row.bottomRadius; onTapped: row.tapped() }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16; anchors.rightMargin: 8; spacing: 12
        Rectangle {
            implicitWidth: 34; implicitHeight: 34; radius: 17
            color: row.connected ? Config.accent : Config.accentContainer
            MatIcon {
                anchors.centerIn: parent; text: Bt.icon(row.dev?.icon ?? "")
                font.pixelSize: 18; color: row.connected ? Config.accentText : Config.fg
            }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Text {
                // PlainText: the device names itself over the air.
                text: row.dev?.name ?? "Unknown"; textFormat: Text.PlainText; color: Config.fg
                font.family: Config.textFont; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight
            }
            Text {
                visible: row.subtitle !== ""; text: row.subtitle; textFormat: Text.PlainText
                color: row.connected ? Config.accent : Config.dim
                font.family: Config.textFont; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight
            }
        }
        IconBtn {
            visible: row.showConnect
            icon: row.connected ? "link_off" : "link"
            tint: row.connected ? Config.danger : Config.accent
            iconSize: 18
            onClicked: if (row.dev) row.dev.connected = !row.connected
        }
        IconBtn { visible: row.showSettings; icon: "settings"; onClicked: row.settings() }
    }
}
