// VPN settings, from both sources the shell knows about:
//   * NetworkManager profiles (nmcli), which the bar's VPN popout also shows — imported from
//     .ovpn/.conf files and toggled with `nmcli con up/down`;
//   * custom providers, arbitrary connect/disconnect commands for anything NM does not manage
//     (tailscale, warp-cli, a bare wg-quick).
// Side by side, so one page answers "what VPNs do I have" — which neither half could alone.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs
import qs.services
import qs.components
import qs.modules.settings.common
StackView {
    id: stack
    clip: true
    initialItem: mainPage

    Component {
        id: mainPage
        PageBase {
            title: "VPN"

            SectionHeader { first: true; text: "NetworkManager profiles" }
            ItemList {
                id: nmProfiles
                visible: Net.vpnList.length > 0
                placeholderIcon: "vpn_lock"
                placeholderText: "No NetworkManager VPN profiles"
                model: ScriptModel { values: [...Net.vpnList] }
                delegate: Item {
                    id: nm
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    implicitHeight: 56
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 8; spacing: 12
                        Rectangle {
                            implicitWidth: 34; implicitHeight: 34; radius: 17
                            color: nm.modelData.active ? Config.accent : Config.container
                            Behavior on color { ColorAnim {} }
                            MatIcon {
                                anchors.centerIn: parent
                                text: nm.modelData.active ? "vpn_lock" : "vpn_key_off"
                                font.pixelSize: 18
                                color: nm.modelData.active ? Config.accentText : Config.fg
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text {
                                text: nm.modelData.name; textFormat: Text.PlainText; color: Config.fg
                                font.family: Config.textFont; font.pixelSize: 13
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                // Name the carrier it rides on — with wired and Wi-Fi both able
                                // to be up, "Connected" alone does not say over what.
                                text: !nm.modelData.active ? "Tap to connect"
                                    : nm.modelData.device ? "Connected via " + nm.modelData.device
                                    : "Connected"
                                color: nm.modelData.active ? Config.accent : Config.dim
                                font.family: Config.textFont; font.pixelSize: 11
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                        }
                        IconBtn {
                            icon: "delete"; tint: Config.danger; iconSize: 18
                            onClicked: VPN.deleteNm(nm.modelData.name)
                        }
                    }
                    StateLayer {
                        ovTopRadius: nmProfiles.rowTop(nm.index)
                        ovBottomRadius: nmProfiles.rowBottom(nm.index)
                        onTapped: nm.modelData.active ? Net.vpnDown(nm.modelData.name)
                                                      : Net.vpnUp(nm.modelData.name)
                    }
                }
            }
            NavRow {
                first: true; last: true
                icon: "file_open"; label: "Import a configuration"
                status: "OpenVPN .ovpn or WireGuard .conf"
                onClicked: stack.push(importPage)
            }

            SectionHeader { text: "Custom provider" }
            ToggleRow {
                text: "Connection"
                subtext: VPN.active ? (VPN.connected ? "Connected · " + VPN.active.name : VPN.busy ? "Working…" : VPN.active.name) : "No provider selected"
                checked: VPN.connected
                onToggled: { if (VPN.active && !VPN.busy) VPN.toggle(); }
            }

            SectionHeader { text: "Providers" }
            ItemList {
                id: providers
                Layout.fillHeight: true
                placeholderIcon: "vpn_key_off"
                placeholderText: "No VPN providers configured"
                model: ScriptModel { values: [...VPN.providers] }
                delegate: Item {
                    id: prov
                    required property var modelData
                    required property int index
                    readonly property bool selected: prov.index === VPN.selectedIndex
                    readonly property bool isConnected: prov.selected && VPN.connected
                    width: ListView.view.width
                    implicitHeight: 56
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 8; spacing: 12
                        Rectangle {
                            implicitWidth: 34; implicitHeight: 34; radius: 17
                            color: prov.isConnected ? Config.accent : prov.selected ? Config.accentContainer : Config.container
                            MatIcon {
                                anchors.centerIn: parent
                                text: prov.isConnected || prov.selected ? "vpn_key" : "vpn_key_off"
                                font.pixelSize: 18; color: prov.isConnected ? Config.accentText : Config.fg
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text {
                                text: prov.modelData.name || "Unnamed"; textFormat: Text.PlainText; color: Config.fg
                                font.family: Config.textFont; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                text: prov.isConnected ? "Connected" : prov.selected ? "Selected · tap edit" : "Tap to select"
                                color: prov.isConnected ? Config.accent : Config.dim
                                font.family: Config.textFont; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight
                            }
                        }
                        IconBtn { icon: "edit"; onClicked: stack.push(editPage, { editIndex: prov.index }) }
                    }
                    StateLayer {
                        ovTopRadius: providers.rowTop(prov.index)
                        ovBottomRadius: providers.rowBottom(prov.index)
                        onTapped: VPN.setActive(prov.index)
                    }
                }
            }

            NavRow {
                first: true; last: true
                icon: "add"; label: "Add provider"
                onClicked: stack.push(editPage, { editIndex: -1 })
            }
        }
    }

    // --- Import an NM configuration ---
    Component {
        id: importPage
        PageBase {
            id: imp
            property string path: ""
            title: "Import a VPN configuration"
            isSubPage: true
            onBack: stack.pop()

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: "Hands the file to `nmcli connection import`. A .conf is treated as WireGuard, "
                      + "anything else as OpenVPN. The profile then appears in the list and in the bar."
                color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
            TextRow {
                first: true; last: true
                label: "File"
                value: imp.path
                placeholder: "/home/you/Downloads/office.ovpn"
                live: true
                onEdited: t => imp.path = t
            }
            ButtonRow {
                first: true; last: true
                icon: "download"; label: "Import"
                enabled: imp.path.length > 0
                onClicked: { VPN.importConfig(imp.path); stack.pop(); }
            }
        }
    }

    // --- Add / edit provider ---
    Component {
        id: editPage
        PageBase {
            id: ep
            property int editIndex: -1
            readonly property var existing: editIndex >= 0 ? VPN.providers[editIndex] : null
            title: editIndex >= 0 ? "Edit provider" : "Add provider"
            isSubPage: true
            onBack: stack.pop()

            component Field: Rectangle {
                id: field
                property alias text: ti.text
                property string placeholder: ""
                property bool mono: false
                Layout.fillWidth: true
                implicitHeight: 48; radius: 10; color: Config.container
                TextInput {
                    id: ti
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter; clip: true
                    color: Config.fg; font.family: field.mono ? "monospace" : Config.textFont; font.pixelSize: 13
                    Text {
                        anchors.verticalCenter: parent.verticalCenter; visible: ti.text === ""
                        text: field.placeholder; color: Config.dim
                        font.family: Config.textFont; font.pixelSize: 13
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Field { id: nameF; placeholder: "Display name (e.g. Home WireGuard)"; text: ep.existing?.name ?? "" }
                Field { id: ifaceF; placeholder: "Interface (e.g. wg0, tailscale0)"; text: ep.existing?.iface ?? "" }
                Field { id: connF; mono: true; placeholder: "Connect command (e.g. wg-quick up wg0)"; text: ep.existing?.connectCmd ?? "" }
                Field { id: discF; mono: true; placeholder: "Disconnect command (e.g. wg-quick down wg0)"; text: ep.existing?.disconnectCmd ?? "" }

                RowLayout {
                    Layout.fillWidth: true; Layout.topMargin: 8; spacing: 8
                    Rectangle {
                        visible: ep.editIndex >= 0
                        implicitWidth: 46; implicitHeight: 46; radius: 14; color: Config.container
                        MatIcon { anchors.centerIn: parent; text: "delete"; color: Config.error; font.pixelSize: 20 }
                        StateLayer { ovRadius: 14; onTapped: { VPN.deleteProvider(ep.editIndex); stack.pop(); } }
                    }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 46; radius: 14
                        color: nameF.text.length > 0 ? Config.accent : Config.container
                        Text {
                            anchors.centerIn: parent; text: ep.editIndex >= 0 ? "Save" : "Add provider"
                            color: nameF.text.length > 0 ? Config.accentText : Config.dim
                            font.family: Config.textFont; font.pixelSize: 14; font.bold: true
                        }
                        StateLayer {
                            ovRadius: 14
                            onTapped: {
                                if (nameF.text.length === 0) return;
                                const p = { name: nameF.text, iface: ifaceF.text, connectCmd: connF.text, disconnectCmd: discF.text };
                                if (ep.editIndex >= 0) VPN.updateProvider(ep.editIndex, p);
                                else VPN.addProvider(p);
                                stack.pop();
                            }
                        }
                    }
                }
            }
        }
    }
}
