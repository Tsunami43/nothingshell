pragma Singleton

// VPN, from the two sources this desktop has:
//   * NetworkManager profiles, written here from the field schema in vpnschema.js. The list itself
//     lives in services/Net.qml, which owns nmcli and its refresh; this file only writes.
//   * custom providers, arbitrary connect/disconnect shell commands for what NM does not manage
//     (tailscale, warp-cli, a bare wg-quick). Persisted in Config.vpnProviders.
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "vpnschema.js" as Schema

Singleton {
    id: root

    // --- Custom providers ---
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

    // --- VPN types ---
    // A missing plugin shows as unavailable rather than as a form that fails silently on connect.
    property var installedServices: []
    readonly property var types: Schema.types.map(t => Object.assign({}, t, {
        available: !t.service || root.installedServices.indexOf(t.service) !== -1
    }))
    function typeById(id) { return Schema.byId(id); }
    function resolveValues(type, values) { return Schema.resolve(type, values); }
    function fieldVisible(f, values, showAdvanced) { return Schema.fieldVisible(f, values, showAdvanced); }
    function missingRequired(type, values) { return Schema.missingRequired(type, values); }

    Process {
        id: pluginScan
        running: true
        // `service=` in these INI files is what a profile stores in vpn.service-type.
        command: ["sh", "-c",
            "cat /usr/lib/NetworkManager/VPN/*.name /usr/local/lib/NetworkManager/VPN/*.name "
            + "/etc/NetworkManager/VPN/*.name 2>/dev/null | grep '^service=' | cut -d= -f2"]
        stdout: StdioCollector {
            id: pluginOut
            onStreamFinished: {
                const seen = [];
                for (const l of pluginOut.text.trim().split("\n")) {
                    const s = l.trim();
                    if (s && seen.indexOf(s) === -1) seen.push(s);
                }
                root.installedServices = seen;
            }
        }
    }

    // --- Writing a NetworkManager profile ---
    property bool saving: false
    property string lastError: ""
    signal saved(string uuid)
    signal failed(string message)
    signal loaded(var profile)      // { uuid, name, service, typeId, values }

    function buildProfile(type, values, existing) { return Schema.build(type, values, existing); }
    function clearKey(key) { return Schema.clearKey(key); }

    // req: { uuid, name, service, data, secrets, cleared } — an empty uuid means "create".
    property var pending: null
    function saveProfile(req) {
        if (root.saving) return;
        root.saving = true;
        root.lastError = "";
        root.pending = req;
        // vpn.data through argv: paths and usernames, nothing not already readable in the profile.
        // `con modify` replaces the dict, which is what an edit needs — a cleared key must vanish.
        const cmd = req.uuid
            ? ["nmcli", "con", "modify", "uuid", req.uuid, "connection.id", req.name]
            : ["nmcli", "con", "add", "type", "vpn", "con-name", req.name,
               "vpn-type", req.service, "autoconnect", "no"];
        // Omitted rather than sent empty, which would erase what is there. WireGuard has no vpn
        // setting at all, and an unknown plugin's profile is being renamed, not rewritten.
        if (Object.keys(req.data ?? ({})).length > 0) cmd.push("vpn.data", Schema.dictStr(req.data));
        saveProc.command = cmd;
        saveProc.running = true;
    }

    Process {
        id: saveProc
        stdout: StdioCollector { id: saveOut }
        stderr: StdioCollector { id: saveErr }
        onExited: code => {   // qmllint disable signal-handler-parameters
            const txt = saveOut.text + saveErr.text;
            if (code !== 0) { root.fail(txt); return; }
            // The success line is the only place the new UUID appears.
            const m = txt.match(/\(([0-9a-fA-F-]{36})\)/);
            const uuid = root.pending?.uuid || (m ? m[1] : "");
            const secrets = root.pending?.secrets ?? ({});
            const cleared = root.pending?.cleared ?? [];
            if (!uuid || (Object.keys(secrets).length === 0 && cleared.length === 0)) { root.finish(uuid); return; }
            root.writeSecrets(uuid, secrets, cleared);
        }
    }

    // Secrets over stdin, same rule as Net.connectWithSecret: /proc/<pid>/cmdline is world-readable,
    // a pipe is not. `con modify` has no --ask, but the interactive editor reads stdin without a tty.
    // It merges vpn.secrets where `con modify` would replace it, so a cleared secret goes by name.
    function writeSecrets(uuid, secrets, cleared) {
        const lines = [];
        for (const k of cleared) lines.push("remove vpn.secrets " + k);
        if (Object.keys(secrets).length > 0) lines.push("set vpn.secrets " + Schema.dictStr(secrets));
        lines.push("save");
        // Answers a confirmation if one is asked, harmless if not.
        lines.push("yes");
        lines.push("quit");
        secretProc.pendingUuid = uuid;
        secretProc.command = ["nmcli", "con", "edit", "uuid", uuid];
        secretProc.stdinEnabled = true;
        secretProc.running = true;
        secretProc.write(lines.join("\n") + "\n");
        // Closing stdin keeps a rejected input from hanging: a further prompt hits EOF and gives up.
        secretProc.stdinEnabled = false;
    }

    Process {
        id: secretProc
        property string pendingUuid: ""
        stdout: StdioCollector { id: secOut }
        stderr: StdioCollector { id: secErr }
        onExited: code => {   // qmllint disable signal-handler-parameters
            // The editor exits 0 even when a `set` was rejected; only its "Error:" line says so.
            const txt = secOut.text + secErr.text;
            const err = txt.split("\n").find(l => l.trim().startsWith("Error:"));
            if (code !== 0 || err) { root.fail(err || txt); return; }
            root.finish(secretProc.pendingUuid);
        }
    }

    function finish(uuid) {
        root.saving = false;
        root.pending = null;
        Net.refreshConnections();
        root.saved(uuid);
    }
    function fail(txt) {
        root.saving = false;
        root.pending = null;
        const lines = ("" + (txt || "")).split("\n").map(l => l.trim()).filter(Boolean);
        const first = lines.find(l => l.startsWith("Error:")) ?? lines[0] ?? "nmcli failed";
        root.lastError = first.replace(/^Error:\s*/, "");
        // The shell is its own notification server, so this returns as one of its toasts.
        Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "VPN",
                                 "Could not save the VPN profile", root.lastError]);
        root.failed(root.lastError);
    }

    // --- Reading one back, to edit it ---
    function loadProfile(uuid) {
        if (!uuid) return;
        readProc.pendingUuid = uuid;
        // -e no keeps the value as libnm printed it, including the '\,' parseDict needs to see.
        readProc.command = ["nmcli", "-t", "-e", "no", "-f", "connection.id,vpn.service-type,vpn.data",
                            "con", "show", "uuid", uuid];
        readProc.running = true;
    }
    Process {
        id: readProc
        property string pendingUuid: ""
        stdout: StdioCollector {
            id: readOut
            onStreamFinished: {
                let name = "", service = "", data = "";
                for (const l of readOut.text.trim().split("\n").filter(Boolean)) {
                    const i = l.indexOf(":");
                    if (i === -1) continue;
                    const k = l.slice(0, i), v = l.slice(i + 1);
                    if (k === "connection.id") name = v;
                    else if (k === "vpn.service-type") service = v;
                    else if (k === "vpn.data") data = v;
                }
                const type = Schema.byService(service);
                root.loaded({
                    uuid: readProc.pendingUuid,
                    name: name,
                    service: service,
                    typeId: type ? type.id : "",
                    // No secrets: editing the MTU must not overwrite a stored password with a blank.
                    values: Schema.parseDict(data)
                });
            }
        }
    }

    // --- Import ---
    // Type from the page, not the extension: both WireGuard and OpenVPN configs get named .conf.
    function importConfig(path, type) {
        if (!path) return;
        const clean = path.replace(/^file:\/\//, "");
        importProc.command = ["nmcli", "connection", "import",
                              "type", type || (/\.conf$/i.test(clean) ? "wireguard" : "openvpn"),
                              "file", clean];
        importProc.running = true;
    }
    Process {
        id: importProc
        stdout: StdioCollector { id: impOut }
        stderr: StdioCollector { id: impErr }
        onExited: code => {   // qmllint disable signal-handler-parameters
            if (code !== 0) { root.fail(impOut.text + impErr.text); return; }
            Net.refreshConnections();
            root.saved("");
        }
    }

    // --- Custom provider connect/disconnect ---
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
