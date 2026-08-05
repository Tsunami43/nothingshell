pragma Singleton

// Bluetooth adapter + devices (adapter power is read-only in this setup → toggle via bluetoothctl).
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root
    readonly property var  adapter:     Bluetooth.defaultAdapter
    readonly property bool enabled:     adapter?.enabled ?? false
    readonly property bool connected:   (Bluetooth.devices?.values ?? []).some(d => d.connected)
    readonly property var  devices:     Bluetooth.devices?.values ?? []
    readonly property bool discovering: adapter?.discovering ?? false
    function toggle()     { Quickshell.execDetached(["bluetoothctl", "power", enabled ? "off" : "on"]); }
    function toggleScan() { if (adapter) adapter.discovering = !adapter.discovering; }
    function icon(ic) {
        ic = (ic || "").toLowerCase();
        if (ic.includes("headset") || ic.includes("headphone")) return "headphones";
        if (ic.includes("audio")) return "speaker";
        if (ic.includes("phone")) return "smartphone";
        if (ic.includes("mouse")) return "mouse";
        if (ic.includes("keyboard")) return "keyboard";
        return "bluetooth";
    }
}
