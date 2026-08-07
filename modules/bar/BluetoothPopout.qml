// Bluetooth popout: power and discovery toggles, then the devices worth showing.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

BarPopout {
    id: pop
    name: "bluetooth"
    implicitWidth: 288
    bodyHeight: btCol.implicitHeight + 28

    ColumnLayout {
        id: btCol
        anchors { top: parent.top; left: parent.left; right: parent.right
                  topMargin: 14 + Config.popFillet * 2 - pop.botPad; leftMargin: 16; rightMargin: 16 }
        spacing: 8

        Text { text: "Bluetooth"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 15; font.bold: true }

        RowLayout {
            Layout.fillWidth: true; spacing: 12
            Text { text: "Enabled"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 13; Layout.fillWidth: true }
            Rectangle {
                implicitWidth: 42; implicitHeight: 24; radius: 12
                color: Bt.enabled ? Config.accent : Config.switchTrackOff
                Behavior on color { ColorAnim {} }
                Rectangle {
                    width: 18; height: 18; radius: 9; color: Bt.enabled ? Config.accentText : Config.dim
                    anchors.verticalCenter: parent.verticalCenter
                    x: Bt.enabled ? parent.width - width - 3 : 3
                    Behavior on x { SpatialFast {} }
                    Behavior on color { ColorAnim {} }
                }
                StateLayer { ovRadius: 12; onTapped: Bt.toggle() }
            }
        }
        RowLayout {
            visible: Bt.enabled
            Layout.fillWidth: true; spacing: 12
            Text { text: "Discovering"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 13; Layout.fillWidth: true }
            Rectangle {
                implicitWidth: 42; implicitHeight: 24; radius: 12
                color: Bt.discovering ? Config.accent : Config.switchTrackOff
                Behavior on color { ColorAnim {} }
                Rectangle {
                    width: 18; height: 18; radius: 9; color: Bt.discovering ? Config.accentText : Config.dim
                    anchors.verticalCenter: parent.verticalCenter
                    x: Bt.discovering ? parent.width - width - 3 : 3
                    Behavior on x { SpatialFast {} }
                    Behavior on color { ColorAnim {} }
                }
                StateLayer { ovRadius: 12; onTapped: Bt.toggleScan() }
            }
        }

        Text {
            Layout.topMargin: 2
            text: {
                if (!Bt.enabled) return "Bluetooth is off";
                const n = Bt.devices.length, c = Bt.devices.filter(d => d.connected).length;
                return n + " device" + (n === 1 ? "" : "s") + " available" + (c > 0 ? " (" + c + " connected)" : "");
            }
            color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
        }

        // Device list (connected first, then paired, then name).
        Repeater {
            model: ScriptModel {
                objectProp: "address"
                values: Bt.enabled ? [...Bt.devices].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name ?? "").localeCompare(b.name ?? "")).slice(0, 6) : []
            }
            // No per-row entrance animation — see the Wi-Fi list.
            RowLayout {
                id: btItem
                required property var modelData
                Layout.fillWidth: true
                spacing: 8

                MatIcon { text: Bt.icon(btItem.modelData.icon); font.pixelSize: 17; color: btItem.modelData.connected ? Config.accent : Config.dim }
                Text {
                    Layout.fillWidth: true
                    text: btItem.modelData.name ?? ""
                    textFormat: Text.PlainText   // the device names itself over the air
                    elide: Text.ElideRight
                    color: btItem.modelData.connected ? Config.accent : Config.fg
                    font.family: Config.textFont; font.pixelSize: 13; font.bold: btItem.modelData.connected
                }
                MatIcon {
                    visible: btItem.modelData.connected && (btItem.modelData.batteryAvailable ?? false)
                    text: "battery_full"
                    font.pixelSize: 14
                    color: (btItem.modelData.battery ?? 1) < 0.2 ? Config.error : Config.dim
                }
                Rectangle {
                    implicitWidth: 30; implicitHeight: 30; radius: 15
                    color: btItem.modelData.connected ? Config.accent : "transparent"
                    Behavior on color { ColorAnim {} }
                    MatIcon {
                        anchors.centerIn: parent
                        text: btItem.modelData.connected ? "link_off" : "link"
                        font.pixelSize: 16
                        color: btItem.modelData.connected ? Config.accentText : Config.fg
                    }
                    StateLayer {
                        ovRadius: 15; tint: btItem.modelData.connected ? Config.accentText : Config.fg
                        onTapped: {
                            if (btItem.modelData.connected && btItem.modelData.disconnect) btItem.modelData.disconnect();
                            else if (btItem.modelData.connect) btItem.modelData.connect();
                        }
                    }
                }
            }
        }
    }
}
