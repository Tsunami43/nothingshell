// Network popout: Wi-Fi toggle, the wired links that are up, and the strongest networks in range.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

BarPopout {
    id: pop
    name: "network"
    implicitWidth: 288
    bodyHeight: netCol.implicitHeight + 28

    ColumnLayout {
        id: netCol
        anchors { top: parent.top; left: parent.left; right: parent.right
                  topMargin: 14 + Config.popFillet * 2 - pop.botPad; leftMargin: 16; rightMargin: 16 }
        spacing: 8

        Text { text: "Wireless"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 15; font.bold: true }

        RowLayout {
            Layout.fillWidth: true; spacing: 12
            Text { text: "Enabled"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 13; Layout.fillWidth: true }
            Rectangle {
                implicitWidth: 42; implicitHeight: 24; radius: 12
                color: Net.wifiOn ? Config.accent : Config.switchTrackOff
                Behavior on color { ColorAnim {} }
                Rectangle {
                    width: 18; height: 18; radius: 9
                    color: Net.wifiOn ? Config.accentText : Config.dim
                    anchors.verticalCenter: parent.verticalCenter
                    x: Net.wifiOn ? parent.width - width - 3 : 3
                    Behavior on x { SpatialFast {} }
                    Behavior on color { ColorAnim {} }
                }
                StateLayer { ovRadius: 12; onTapped: Net.toggleWifi() }
            }
        }

        // One line per wired link, marking whichever owns the default route.
        Repeater {
            model: Net.ethernetLinks.filter(l => l.stateCode >= 40)
            RowLayout {
                id: ethItem
                required property var modelData
                Layout.fillWidth: true; Layout.topMargin: 2; spacing: 8
                readonly property bool primary: ethItem.modelData.isDefault
                MatIcon {
                    text: "cable"; font.pixelSize: 17
                    color: ethItem.primary ? Config.accent : Config.fg
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text {
                        text: ethItem.modelData.connection || "Ethernet"
                        textFormat: Text.PlainText
                        color: ethItem.primary ? Config.accent : Config.fg
                        font.family: Config.textFont; font.pixelSize: 12; font.bold: true
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text {
                        text: ethItem.modelData.device
                            + (ethItem.modelData.ip4 ? " · " + ethItem.modelData.ip4.split("/")[0] : "")
                        textFormat: Text.PlainText
                        color: Config.dim; font.family: Config.textFont; font.pixelSize: 10
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                }
                Text {
                    visible: ethItem.primary
                    text: "primary"; color: Config.accent
                    font.family: Config.textFont; font.pixelSize: 10
                }
            }
        }

        Text {
            Layout.topMargin: 2
            text: Net.wifiOn ? (Net.wifiScan.length + " networks available") : "Wi-Fi is off"
            color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
        }

        // Net.wifiScan is already active-first, strongest-next and capped at 8.
        // ScriptModel keyed on the ssid: a plain array would rebuild all eight delegates per scan.
        Repeater {
            model: ScriptModel {
                objectProp: "ssid"
                values: Net.wifiOn ? Net.wifiScan : []
            }
            RowLayout {
                id: netItem
                required property var modelData
                Layout.fillWidth: true
                spacing: 8

                MatIcon { text: Net.netIcon(netItem.modelData.signal); font.pixelSize: 17; color: netItem.modelData.active ? Config.accent : Config.dim }
                MatIcon { visible: netItem.modelData.secure; text: "lock"; font.pixelSize: 12; color: Config.dim }
                Text {
                    Layout.fillWidth: true
                    text: netItem.modelData.ssid
                    // An SSID is chosen by whoever runs the AP — never rich text.
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: netItem.modelData.active ? Config.accent : Config.fg
                    font.family: Config.textFont; font.pixelSize: 13; font.bold: netItem.modelData.active
                }
                Rectangle {
                    implicitWidth: 30; implicitHeight: 30; radius: 15
                    color: netItem.modelData.active ? Config.accent : "transparent"
                    Behavior on color { ColorAnim {} }
                    MatIcon {
                        anchors.centerIn: parent
                        text: netItem.modelData.active ? "link_off" : "link"
                        font.pixelSize: 16
                        color: netItem.modelData.active ? Config.accentText : Config.fg
                    }
                    StateLayer {
                        ovRadius: 15; tint: netItem.modelData.active ? Config.accentText : Config.fg
                        onTapped: netItem.modelData.active ? Net.disconnectWifi(netItem.modelData.ssid) : Net.connectWifi(netItem.modelData.ssid)
                    }
                }
            }
        }

        Rectangle {
            visible: Net.wifiOn
            Layout.fillWidth: true; Layout.topMargin: 4
            implicitHeight: 36; radius: 18
            color: Config.container
            RowLayout {
                anchors.centerIn: parent; spacing: 6
                MatIcon { text: "wifi_find"; font.pixelSize: 17; color: Config.accent }
                Text { text: "Rescan networks"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 12 }
            }
            StateLayer { ovRadius: 18; onTapped: Net.scan() }
        }
    }
}
