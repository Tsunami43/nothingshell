// VPN popout: the NetworkManager profiles, active ones first.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

BarPopout {
    id: pop
    name: "vpn"
    implicitWidth: 288
    bodyHeight: vpnCol.implicitHeight + 28

    ColumnLayout {
        id: vpnCol
        anchors { top: parent.top; left: parent.left; right: parent.right
                  topMargin: 14 + Config.popFillet * 2 - pop.botPad; leftMargin: 16; rightMargin: 16 }
        spacing: 8

        Text { text: "VPN"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 15; font.bold: true }
        Text {
            Layout.topMargin: 2
            text: {
                const n = Net.vpnList.length, c = Net.vpnList.filter(v => v.active).length;
                return n + " profile" + (n === 1 ? "" : "s") + (c > 0 ? " (" + c + " active)" : "");
            }
            color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
        }
        Repeater {
            model: ScriptModel {
                objectProp: "name"
                values: [...Net.vpnList].sort((a, b) => (b.active - a.active) || a.name.localeCompare(b.name))
            }
            // No per-row entrance animation — see the Wi-Fi list.
            RowLayout {
                id: vpnItem
                required property var modelData
                Layout.fillWidth: true
                spacing: 8

                MatIcon { text: vpnItem.modelData.active ? "vpn_lock" : "vpn_key"; font.pixelSize: 17; color: vpnItem.modelData.active ? Config.accent : Config.dim }
                Text {
                    Layout.fillWidth: true
                    text: vpnItem.modelData.name
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: vpnItem.modelData.active ? Config.accent : Config.fg
                    font.family: Config.textFont; font.pixelSize: 13; font.bold: vpnItem.modelData.active
                }
                Rectangle {
                    implicitWidth: 30; implicitHeight: 30; radius: 15
                    color: vpnItem.modelData.active ? Config.accent : "transparent"
                    Behavior on color { ColorAnim {} }
                    MatIcon {
                        anchors.centerIn: parent
                        text: vpnItem.modelData.active ? "link_off" : "link"
                        font.pixelSize: 16
                        color: vpnItem.modelData.active ? Config.accentText : Config.fg
                    }
                    StateLayer {
                        ovRadius: 15; tint: vpnItem.modelData.active ? Config.accentText : Config.fg
                        onTapped: vpnItem.modelData.active ? Net.vpnDown(vpnItem.modelData.name) : Net.vpnUp(vpnItem.modelData.name)
                    }
                }
            }
        }
    }
}
