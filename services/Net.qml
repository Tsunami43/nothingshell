pragma Singleton

// Network state scraped from nmcli (Wi-Fi + Ethernet + VPN); refreshed live via `nmcli monitor`.
// Sole owner of nmcli in the shell — the bar widgets and the settings network pages both read here,
// so there is exactly one `nmcli monitor` process.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Once at start-up whatever the polling policy is: the monitor only reports changes.
    Component.onCompleted: { netProc.running = true; conProc.running = true; }

    // `nmcli -t` escapes ':' inside values as '\:', so split on unescaped colons only.
    // Matters most for BSSIDs, which are nothing but colons.
    function splitEsc(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) { cur += line[++i]; continue; }
            if (c === ":") { out.push(cur); cur = ""; continue; }
            cur += c;
        }
        out.push(cur);
        return out;
    }

    // --- Wi-Fi / Ethernet ---
    property bool   wifiOn: false
    property int    wifiSignal: 0
    property var    networks: []         // [{ ssid, bssid, strength, active, isSecure }]

    // Every managed physical link, wired and wireless alike. Bridges, veth pairs and loopback
    // are dropped, so what stays is what a person would call "a port on this machine".
    // { device, type, stateCode, state, connection, mac, speed, ip4, gateway, dns, ip6, isDefault }
    property var    links: []
    property string defaultDevice: ""    // interface that currently owns the default route
    property string defaultGateway: ""

    readonly property var ethernetLinks: root.links.filter(l => l.type === "ethernet")
    readonly property var wifiLinks: root.links.filter(l => l.type === "wifi")

    // Wired and wireless can both be up at once, so each side gets its own active link
    // rather than one shared "the connection" — the default route decides who carries traffic.
    readonly property var activeEthernet: root.ethernetLinks.find(l => l.stateCode >= 100) ?? null
    readonly property var activeWifi: root.wifiLinks.find(l => l.stateCode >= 100) ?? null
    readonly property var connectingEthernet: root.ethernetLinks.find(l => l.stateCode >= 40 && l.stateCode < 100) ?? null
    readonly property var connectingWifi: root.wifiLinks.find(l => l.stateCode >= 40 && l.stateCode < 100) ?? null

    readonly property bool ethernetUp: root.activeEthernet !== null
    readonly property string activeConnection: root.activeEthernet?.connection ?? ""
    readonly property string activeInterface: root.activeEthernet?.device ?? ""
    readonly property string connectingName: root.connectingWifi?.connection ?? ""
    readonly property string wifiSsid: root.activeWifi?.connection ?? ""
    readonly property string wifiDevice: root.wifiLinks[0]?.device ?? ""

    readonly property bool wifiEnabled: root.wifiOn
    readonly property bool hasEthernetPort: root.ethernetLinks.length > 0
    readonly property bool wifiUp: root.wifiSsid !== ""
    readonly property bool netUp:  root.ethernetUp || root.wifiUp

    // True when both carriers are up — the case where a single shared icon would lie.
    readonly property bool dualUp: root.ethernetUp && root.wifiUp
    readonly property bool ethernetIsDefault: root.ethernetUp && root.activeEthernet?.isDefault === true
    readonly property bool wifiIsDefault: root.wifiUp && root.activeWifi?.isDefault === true

    // Human-readable state for a link row.
    function linkState(l) {
        if (!l) return "";
        const c = l.stateCode;
        if (c >= 100) return "Connected";
        if (c >= 40)  return "Connecting…";
        if (c === 30) return "Disconnected";
        if (c === 20) return l.type === "ethernet" ? "Cable unplugged" : (root.wifiOn ? "Unavailable" : "Wi-Fi off");
        if (c === 10) return "Unmanaged";
        return "Unknown";
    }
    function linkIcon(l) {
        if (!l) return "lan";
        if (l.type === "wifi") return l.stateCode >= 100 ? "wifi" : (root.wifiOn ? "wifi_find" : "wifi_off");
        return l.stateCode >= 100 ? "settings_ethernet" : (l.stateCode === 20 ? "power_off" : "lan");
    }

    // Compact view for the bar popout — strongest 8, with the `signal` spelling it expects.
    readonly property var wifiScan: root.networks.slice(0, 8).map(n => ({
        ssid: n.ssid, signal: n.strength, active: n.active, secure: n.isSecure
    }))

    // SSID shown as connecting on our side until nmcli catches up (or we give up).
    property string pendingSsid: ""
    function connectingSsid() { return root.connectingName || root.pendingSsid; }
    readonly property bool connecting: root.connectingName !== "" || root.pendingSsid !== ""
    Timer { id: pendingClear; interval: 20000; onTriggered: root.pendingSsid = "" }

    onWifiSsidChanged: if (root.wifiSsid !== "" && root.wifiSsid === root.pendingSsid) root.pendingSsid = "";

    // One sweep: radio state, every device with its addressing, then the default routes.
    // `device show` is keyed one "FIELD:value" per line — values are NOT colon-escaped here
    // (MACs come through raw), so split on the first colon only.
    Process {
        id: netProc
        command: ["sh", "-c",
            "echo RADIO=$(nmcli -t radio wifi); "
            + "nmcli -t -f GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,GENERAL.HWADDR,"
            + "CAPABILITIES.SPEED,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS device show; "
            + "echo ---ROUTE---; ip -o route show default"]
        stdout: StdioCollector {
            id: netOut
            onStreamFinished: {
                const out = [];
                let cur = null, inRoute = false;
                let defDev = "", defGw = "", defMetric = -1;

                const flush = () => {
                    // veth/docker legs claim type "ethernet" as well; they are all unmanaged,
                    // and bridges/loopback/xfrm are filtered by type.
                    if (cur && (cur.type === "ethernet" || cur.type === "wifi") && cur.stateCode > 10)
                        out.push(cur);
                    cur = null;
                };

                for (const line of netOut.text.split("\n")) {
                    if (line === "---ROUTE---") { flush(); inRoute = true; continue; }

                    if (inRoute) {
                        // "default via 192.168.31.1 dev enp196s0 proto dhcp src ... metric 100"
                        const t = line.trim().split(/\s+/);
                        if (t[0] !== "default") continue;
                        const di = t.indexOf("dev"), vi = t.indexOf("via"), mi = t.indexOf("metric");
                        const metric = mi !== -1 ? parseInt(t[mi + 1] || "0") : 0;
                        // Lowest metric wins, matching what the kernel actually picks.
                        if (defMetric === -1 || metric < defMetric) {
                            defMetric = metric;
                            defDev = di !== -1 ? (t[di + 1] || "") : "";
                            defGw  = vi !== -1 ? (t[vi + 1] || "") : "";
                        }
                        continue;
                    }

                    if (line.startsWith("RADIO=")) { root.wifiOn = line.slice(6) === "enabled"; continue; }
                    const sep = line.indexOf(":");
                    if (sep === -1) continue;
                    const key = line.slice(0, sep), val = line.slice(sep + 1);

                    if (key === "GENERAL.DEVICE") {
                        flush();
                        cur = { device: val, type: "", stateCode: 0, state: "", connection: "",
                                mac: "", speed: "", ip4: "", gateway: "", dns: [], ip6: "", isDefault: false };
                        continue;
                    }
                    if (!cur) continue;

                    if (key === "GENERAL.TYPE") cur.type = val;
                    else if (key === "GENERAL.STATE") {
                        cur.stateCode = parseInt(val) || 0;
                        const m = val.match(/\((.*)\)/);
                        cur.state = m ? m[1] : val;
                    }
                    else if (key === "GENERAL.CONNECTION") cur.connection = val;
                    else if (key === "GENERAL.HWADDR") cur.mac = val;
                    else if (key === "CAPABILITIES.SPEED") cur.speed = val === "unknown" ? "" : val;
                    // Only the first address of each family is worth a row.
                    else if (key === "IP4.ADDRESS[1]") cur.ip4 = val;
                    else if (key === "IP4.GATEWAY") cur.gateway = val;
                    else if (key.startsWith("IP4.DNS[")) cur.dns.push(val);
                    else if (key === "IP6.ADDRESS[1]") cur.ip6 = val;
                }
                flush();

                for (const l of out) l.isDefault = l.device === defDev;
                root.defaultDevice = defDev;
                root.defaultGateway = defGw;
                root.links = out;
            }
        }
    }
    // A safety net, not the source of truth: `nmcli monitor` below reports every change.
    // Off entirely on battery, where three spawns every 30s buy nothing.
    Timer {
        interval: Math.max(1, Power.netPollMs); running: Power.netPollMs > 0
        repeat: true; triggeredOnStart: true
        onTriggered: netProc.running = true
    }

    // --- Wi-Fi scan ---
    // scan() re-reads the cached list (bar popout); rescanWifi() asks the radio to sweep first.
    // Neither may run while an association is in flight: a sweep makes the card hop channels,
    // which stalls the handshake and the DHCP lease that follows it.
    function scan() { wifiScanProc.running = true; }
    function rescanWifi() { if (!root.connecting) wifiRescanProc.running = true; }

    Process {
        id: wifiRescanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: wifiScanProc.running = true // qmllint disable signal-handler-parameters
    }

    Process {
        id: wifiScanProc
        // `--rescan no` keeps this a pure cache read; without it nmcli sweeps on its own once
        // the cache is ~30s old, which is exactly when we poll during a connect.
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,BSSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            id: wifiScanOut
            onStreamFinished: {
                const seen = ({}); const out = [];
                for (const l of wifiScanOut.text.trim().split("\n").filter(Boolean)) {
                    const f = root.splitEsc(l);
                    if (f.length < 5) continue;
                    const ssid = f[1];
                    // nmcli lists strongest first, so the first BSS we see per SSID is the one to keep.
                    if (!ssid || seen[ssid]) continue;
                    seen[ssid] = true;
                    const active = f[0] === "*";
                    const strength = parseInt(f[3] || "0");
                    out.push({
                        ssid: ssid, bssid: f[2] || "", strength: strength,
                        active: active, isSecure: (f[4] || "").trim() !== ""
                    });
                    if (active) root.wifiSignal = strength;
                }
                out.sort((a, b) => (b.active - a.active) || (b.strength - a.strength));
                root.networks = out;
            }
        }
    }

    function enableWifi(on, cb) {
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]);
        netRefresh.restart();
        if (cb) cb(true);
    }
    function toggleWifi() { root.enableWifi(!root.wifiOn, null); }

    // A secret never travels in argv: /proc/<pid>/cmdline is world-readable, so
    // `nmcli … password <psk>` publishes the key to every process on the machine for as long as
    // nmcli runs. `--ask` makes nmcli prompt for what it is missing and read the answer from
    // stdin, which is a pipe only this process and root can see. Verified that nmcli's prompt
    // reader accepts a pipe — it does not require a tty.
    Process {
        id: secretProc
        stdinEnabled: true
        onExited: {   // qmllint disable signal-handler-parameters
            secretProc.stdinEnabled = true;   // re-arm the pipe for the next association
            netRefresh.restart();
        }
    }
    // Closing stdin right after the one line is what keeps a failed prompt from hanging: nmcli
    // asking for anything else hits EOF and gives up with an error instead of waiting forever.
    function connectWithSecret(cmd, secret) {
        if (secretProc.running) return false;   // one association in flight at a time
        secretProc.command = cmd;
        secretProc.running = true;
        secretProc.write(secret + "\n");
        secretProc.stdinEnabled = false;
        return true;
    }

    // bssid is a fallback target for hidden/unnamed networks.
    function connectToNetwork(ssid, password, bssid, cb) {
        const target = ssid || bssid || "";
        if (!target) return;
        root.pendingSsid = ssid || target;
        pendingClear.restart();
        if (password) {
            root.connectWithSecret(["nmcli", "--ask", "device", "wifi", "connect", target], password);
        } else {
            // A saved network activates straight from its profile. `device wifi connect` would
            // re-derive the profile and can block on a fresh scan first — noticeably slower.
            Quickshell.execDetached(ssid && root.hasSavedProfile(ssid)
                ? ["nmcli", "con", "up", "id", ssid]
                : ["nmcli", "device", "wifi", "connect", target]);
        }
        netRefresh.restart();
        if (cb) cb(true);
    }

    function addHiddenNetwork(ssid, password, security, hidden, cb) {
        if (!ssid) return;
        const cmd = ["nmcli", "--ask", "device", "wifi", "connect", ssid];
        if (hidden) cmd.push("hidden", "yes");
        root.pendingSsid = ssid;
        pendingClear.restart();
        if (security !== "none" && password) root.connectWithSecret(cmd, password);
        else Quickshell.execDetached(cmd);
        netRefresh.restart();
        if (cb) cb(true);
    }

    function connectWifi(ssid) { root.connectToNetwork(ssid, "", "", null); }
    function disconnectWifi(ssid) { Quickshell.execDetached(["nmcli", "con", "down", "id", ssid]); netRefresh.restart(); }
    function disconnectFromNetwork() {
        if (root.wifiDevice) Quickshell.execDetached(["nmcli", "device", "disconnect", root.wifiDevice]);
        else if (root.wifiSsid) root.disconnectWifi(root.wifiSsid);
        netRefresh.restart();
    }
    function forgetNetwork(ssid, cb) {
        Quickshell.execDetached(["nmcli", "con", "delete", "id", ssid]);
        conRefresh.restart();
        if (cb) cb(true);
    }

    Timer { id: netRefresh; interval: 900; onTriggered: { netProc.running = true; wifiScanProc.running = true; } }
    function netIcon(s) {
        if (s >= 75) return "network_wifi";
        if (s >= 50) return "network_wifi_3_bar";
        if (s >= 30) return "network_wifi_2_bar";
        if (s >= 10) return "network_wifi_1_bar";
        return "signal_wifi_0_bar";
    }

    // --- Saved profiles + VPN (one `con show` feeds both) ---
    property var    savedConnectionSsids: []
    property var    wiredProfiles: []     // [{ name, device, active }] — saved 802-3-ethernet profiles
    property bool   vpnActive: false
    property string vpnActiveName: ""
    property string vpnFirst: ""
    property string vpnDevice: ""         // carrier the active VPN rides on
    property var    vpnList: []
    readonly property bool hasVpn: root.vpnList.length > 0

    function hasSavedProfile(ssid) { return root.savedConnectionSsids.indexOf(ssid) !== -1; }
    function loadSavedConnections(cb) { conProc.running = true; if (cb) cb(true); }
    function profilesFor(device) { return root.wiredProfiles.filter(p => p.device === "" || p.device === device); }

    Process {
        id: conProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE,ACTIVE", "con", "show"]
        stdout: StdioCollector {
            id: conOut
            onStreamFinished: {
                let active = "", first = "", vpnDev = "";
                const list = [], saved = [], wired = [];
                for (const l of conOut.text.trim().split("\n").filter(Boolean)) {
                    const f = root.splitEsc(l);
                    const name = f[0], type = f[1] || "", dev = f[2] || "", isActive = f[3] === "yes";
                    if (type === "vpn" || type === "wireguard") {
                        list.push({ name: name, active: isActive, device: dev });
                        if (!first) first = name;
                        if (isActive) { active = name; vpnDev = dev; }
                    } else if (type === "802-11-wireless") {
                        saved.push(name);
                    } else if (type === "802-3-ethernet") {
                        wired.push({ name: name, device: dev, active: isActive });
                    }
                }
                root.vpnList = list;
                root.vpnActiveName = active;
                root.vpnActive = active !== "";
                root.vpnDevice = vpnDev;
                root.vpnFirst = first;
                root.savedConnectionSsids = saved;
                root.wiredProfiles = wired;
            }
        }
    }

    // --- Wired actions (device-scoped, since more than one port can exist) ---
    function connectDevice(dev) {
        if (!dev) return;
        Quickshell.execDetached(["nmcli", "device", "connect", dev]);
        netRefresh.restart();
    }
    function disconnectDevice(dev) {
        if (!dev) return;
        Quickshell.execDetached(["nmcli", "device", "disconnect", dev]);
        netRefresh.restart();
    }
    function activateProfile(name) {
        if (!name) return;
        Quickshell.execDetached(["nmcli", "con", "up", "id", name]);
        netRefresh.restart(); conRefresh.restart();
    }
    // Same safety net as netProc's, off on battery for the same reason.
    Timer {
        interval: Math.max(1, Power.netPollMs); running: Power.netPollMs > 0
        repeat: true; triggeredOnStart: true
        onTriggered: conProc.running = true
    }
    function vpnUp(name) {
        root.vpnList = root.vpnList.map(v => ({ name: v.name, active: v.name === name }));
        root.vpnActiveName = name; root.vpnActive = true;
        Quickshell.execDetached(["nmcli", "con", "up", name]); conRefresh.restart();
    }
    function vpnDown(name) {
        root.vpnList = root.vpnList.map(v => ({ name: v.name, active: v.name === name ? false : v.active }));
        root.vpnActiveName = root.vpnList.find(v => v.active)?.name ?? "";
        root.vpnActive = root.vpnActiveName !== "";
        Quickshell.execDetached(["nmcli", "con", "down", name]); conRefresh.restart();
    }
    Timer { id: conRefresh; interval: 1200; onTriggered: conProc.running = true }

    // Live change stream (debounced).
    Process {
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: nmDebounce.restart() }
    }
    Timer { id: nmDebounce; interval: 250; onTriggered: { netProc.running = true; conProc.running = true; } }
}
