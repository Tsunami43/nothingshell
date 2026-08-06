pragma Singleton

// Lean VPN engine: user-defined providers, each running arbitrary connect/disconnect CLI
// commands (wg-quick, tailscale, warp-cli, …). Providers persist in Config.vpnProviders; connection
// status is inferred from the provider's network interface existing. Deliberately minimal —
// enough to add a provider and toggle it on/off, nothing more.
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // providers: [{ name, iface, connectCmd, disconnectCmd }]
    readonly property var providers: Config.vpnProviders ?? []
    readonly property int selectedIndex: {
        const i = providers.findIndex(p => p.name === Config.vpnSelected);
        return i >= 0 ? i : (providers.length > 0 ? 0 : -1);
    }
    readonly property var active: selectedIndex >= 0 ? providers[selectedIndex] : null

    property bool connected: false
    property bool busy: false

    function persistList(list) { Config.vpnProviders = list; }
    function addProvider(p) { const l = providers.slice(); l.push(p); persistList(l); if (!Config.vpnSelected) Config.vpnSelected = p.name; }
    function updateProvider(i, p) { const l = providers.slice(); l[i] = p; persistList(l); }
    function deleteProvider(i) {
        const l = providers.slice();
        const removed = l.splice(i, 1)[0];
        persistList(l);
        if (removed && Config.vpnSelected === removed.name) Config.vpnSelected = l.length ? l[0].name : "";
    }
    function setActive(i) { if (providers[i]) Config.vpnSelected = providers[i].name; }

    // --- NetworkManager profiles ---
    // The profiles themselves are tracked in services/Net.qml (one `nmcli con show` also feeds the
    // bar's VPN popout). Only the two operations the settings page adds live here, so the settings
    // window has one VPN service to talk to rather than two.
    function importConfig(path) {
        if (!path) return;
        // .conf is WireGuard, everything else (.ovpn) goes to the OpenVPN importer.
        const type = /\.conf$/i.test(path) ? "wireguard" : "openvpn";
        Quickshell.execDetached(["sh", "-c",
            'nmcli connection import type "$1" file "$2" || notify-send "VPN import failed" "$2"',
            "sh", type, path.replace(/^file:\/\//, "")]);
    }
    function deleteNm(name) { Quickshell.execDetached(["nmcli", "con", "delete", "id", name]); }

    function toggle() { if (connected) disconnect(); else connect(); }
    function connect() {
        if (!active || !active.connectCmd) return;
        root.busy = true;
        proc.command = ["sh", "-c", active.connectCmd];
        proc.running = true;
    }
    function disconnect() {
        if (!active || !active.disconnectCmd) return;
        root.busy = true;
        proc.command = ["sh", "-c", active.disconnectCmd];
        proc.running = true;
    }
    // The interface either has a sysfs entry or it does not, which is the whole test. Reading the
    // file directly replaces a `sh -c "test -d …"` that both spawned two processes every 5s and
    // interpolated `iface` — a field typed by hand in Settings — straight into a shell script.
    function checkStatus() {
        if (!active || !active.iface) { root.connected = false; return; }
        ifaceProbe.reload();
    }

    FileView {
        id: ifaceProbe
        // operstate rather than the directory: a FileView wants a file, and this one exists for
        // exactly as long as the link does.
        path: root.active?.iface ? "/sys/class/net/" + root.active.iface + "/operstate" : ""
        printErrors: false
        onLoaded: root.connected = true
        onLoadFailed: root.connected = false
    }

    Process {
        id: proc
        onExited: { root.busy = false; root.checkStatus(); }   // qmllint disable signal-handler-parameters
    }
    // Poll while any provider exists; throttled on battery rather than stopped.
    Timer {
        interval: Power.vpnPollMs; repeat: true; running: root.providers.length > 0; triggeredOnStart: true
        onTriggered: root.checkStatus()
    }
}
