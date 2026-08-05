// Bluetooth settings: adapter toggle + saved devices (connect), pair-new sub-page, device info.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
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
            title: "Bluetooth"

            SectionHeader { first: true; text: "Adapter" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                ToggleRow {
                    first: true; last: false
                    text: "Bluetooth"
                    subtext: Bt.enabled ? "On" : "Off"
                    checked: Bt.enabled
                    onToggled: Bt.toggle()
                }
                ToggleRow {
                    first: false; last: true
                    visible: Bt.enabled
                    text: "Discoverable"
                    subtext: "Scan for nearby devices"
                    checked: Bt.discovering
                    onToggled: Bt.toggleScan()
                }
            }

            SectionHeader { text: "Saved devices" }
            ItemList {
                id: savedDevices
                Layout.fillHeight: true
                placeholderIcon: Bt.enabled ? "devices_other" : "bluetooth_disabled"
                placeholderText: Bt.enabled ? "No saved devices" : "Bluetooth disabled"
                model: ScriptModel {
                    values: Bt.enabled ? (Bt.devices.filter(d => d.bonded)
                        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))) : []
                }
                delegate: BtDeviceRow {
                    required property var modelData
                    required property int index
                    dev: modelData
                    topRadius: savedDevices.rowTop(index)
                    bottomRadius: savedDevices.rowBottom(index)
                    showSettings: true
                    showConnect: true
                    subtitle: {
                        if (!modelData) return "";
                        switch (modelData.state) {
                        case BluetoothDeviceState.Connected: return modelData.batteryAvailable ? "Connected · " + Math.round(modelData.battery * 100) + "%" : "Connected";
                        case BluetoothDeviceState.Connecting: return "Connecting…";
                        case BluetoothDeviceState.Disconnecting: return "Disconnecting…";
                        default: return "Saved";
                        }
                    }
                    onTapped: if (modelData) modelData.connected = !connected
                    onSettings: stack.push(infoPage, { dev: modelData })
                }
            }

            NavRow {
                first: true; last: true
                icon: "add"; label: "Pair new device"
                enabled: Bt.enabled
                onClicked: stack.push(pairPage)
            }
        }
    }

    // --- Pair new device ---
    Component {
        id: pairPage
        PageBase {
            title: "Pair device"
            isSubPage: true
            onBack: stack.pop()
            Component.onCompleted: if (Bt.adapter) Bt.adapter.discovering = true
            Component.onDestruction: if (Bt.adapter) Bt.adapter.discovering = false
            ItemList {
                id: foundDevices
                Layout.fillHeight: true
                placeholderIcon: "bluetooth_searching"
                placeholderText: "Searching for devices…"
                model: ScriptModel {
                    values: Bt.devices.filter(d => !d.bonded && d.name).sort((a, b) => a.name.localeCompare(b.name))
                }
                delegate: BtDeviceRow {
                    required property var modelData
                    required property int index
                    dev: modelData
                    topRadius: foundDevices.rowTop(index)
                    bottomRadius: foundDevices.rowBottom(index)
                    subtitle: modelData && modelData.state === BluetoothDeviceState.Connecting ? "Pairing…" : "Tap to pair"
                    onTapped: if (modelData) modelData.pair()
                }
            }
        }
    }

    // --- Device info ---
    Component {
        id: infoPage
        PageBase {
            id: ip
            property var dev
            title: ip.dev?.name ?? "Device"
            isSubPage: true
            onBack: stack.pop()
            readonly property bool connected: ip.dev && ip.dev.state === BluetoothDeviceState.Connected

            SectionHeader { first: true; text: "Device" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                InfoRow { first: true; last: false; icon: "info"; label: "Address"; value: ip.dev?.address ?? "" }
                InfoRow {
                    first: false; last: false
                    icon: "category"; label: "Type"; value: ip.dev?.icon || "Unknown"
                }
                InfoRow {
                    first: false; last: false
                    visible: ip.dev?.batteryAvailable ?? false
                    icon: "battery_full"; label: "Battery"
                    value: Math.round((ip.dev?.battery ?? 0) * 100) + "%"
                }
                TextRow {
                    first: false; last: true
                    label: "Name"
                    subtext: "An alias stored on this machine; empty restores the device's own name"
                    value: ip.dev?.name ?? ""
                    onEdited: t => { if (ip.dev) ip.dev.name = t; }
                }
            }

            SectionHeader { text: "Behaviour" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                ToggleRow {
                    first: true; last: false
                    text: "Trusted"
                    subtext: "Let it reconnect on its own, without confirmation"
                    checked: ip.dev?.trusted ?? false
                    onToggled: if (ip.dev) ip.dev.trusted = !ip.dev.trusted
                }
                ToggleRow {
                    first: false; last: false
                    text: "Allowed to wake the system"
                    checked: ip.dev?.wakeAllowed ?? false
                    onToggled: if (ip.dev) ip.dev.wakeAllowed = !ip.dev.wakeAllowed
                }
                ToggleRow {
                    first: false; last: true
                    text: "Blocked"
                    subtext: "Reject every connection attempt from this device"
                    checked: ip.dev?.blocked ?? false
                    onToggled: if (ip.dev) ip.dev.blocked = !ip.dev.blocked
                }
            }

            SectionHeader { text: "Connection" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                ButtonRow {
                    first: true; last: false
                    icon: ip.connected ? "link_off" : "link"
                    label: ip.connected ? "Disconnect" : "Connect"
                    busy: ip.dev?.state === BluetoothDeviceState.Connecting
                          || ip.dev?.state === BluetoothDeviceState.Disconnecting
                    onClicked: if (ip.dev) ip.dev.connected = !ip.connected
                }
                ButtonRow {
                    first: false; last: true
                    icon: "delete"; label: "Forget device"; destructive: true
                    subtext: "Removes the pairing; you will have to pair again to use it"
                    onClicked: { if (ip.dev) ip.dev.forget(); stack.pop(); }
                }
            }
        }
    }
}
