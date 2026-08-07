pragma Singleton

// Monitors: read from `hyprctl -j monitors all`, changed through `hyprctl keyword monitor`.
//
// Applying a change is two steps: the keyword takes effect at once but is forgotten on reload, so
// once the compositor reports the new state back the whole set is re-rendered into
// Paths.monitorsConf. Persisting the *reported* state keeps a request Hyprland clamped or
// ignored from landing in the file as if it had worked.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

Singleton {
    id: root

    // Sourced from hyprland.conf; see the header written by persist().
    readonly property string confPath: Paths.monitorsConf

    // Set by the Displays page while it is on screen: nothing else needs a 5 s poll.
    property bool active: false
    property var monitors: []
    property bool pendingPersist: false

    function byName(name) { return root.monitors.find(m => m.name === name) ?? null; }
    readonly property var focused: root.monitors.find(m => m.focused) ?? root.monitors[0] ?? null

    // --- Reading ---
    function refresh() { if (!listProc.running) listProc.running = true; }
    Process {
        id: listProc
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.monitors = JSON.parse(text); } catch (e) { root.monitors = []; }
                if (root.pendingPersist) { root.pendingPersist = false; root.persist(); }
            }
        }
    }
    Component.onCompleted: root.refresh()
    Timer {
        interval: 5000; repeat: true; running: root.active; triggeredOnStart: true
        onTriggered: root.refresh()
    }
    // Hotplug and layout changes arrive as events; the poll above is only a safety net for
    // changes made behind our back (another hyprctl call, a config reload).
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "monitoradded" || n === "monitorremoved" || n === "configreloaded")
                debounce.restart();
        }
    }
    Timer { id: debounce; interval: 200; onTriggered: root.refresh() }

    // --- Formatting ---
    // Hyprland wants a bare 60, not 60.00, when the rate is whole; and 1.5, not 1.500000.
    function trim(n, digits) {
        return parseFloat(Number(n).toFixed(digits === undefined ? 2 : digits)).toString();
    }
    // The argument half of `monitor = <this>`.
    function monitorArg(m) {
        if (m.disabled) return m.name + ",disable";
        let s = m.name + "," + m.width + "x" + m.height + "@" + root.trim(m.refreshRate, 2)
              + "," + Math.round(m.x) + "x" + Math.round(m.y) + "," + root.trim(m.scale, 6);
        if (m.transform) s += ",transform," + m.transform;
        if (m.vrr) s += ",vrr,1";
        if (m.mirrorOf && m.mirrorOf !== "none") s += ",mirror," + m.mirrorOf;
        return s;
    }
    // Human-readable "3840×2160 @ 60 Hz".
    function modeText(m) {
        if (!m) return "";
        return m.width + "×" + m.height + " @ " + root.trim(m.refreshRate, 2) + " Hz";
    }
    // "3840x2160@60.00Hz" (from availableModes) -> { w, h, hz }.
    function parseMode(s) {
        const m = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(s);
        return m ? { w: parseInt(m[1]), h: parseInt(m[2]), hz: parseFloat(m[3]) } : null;
    }
    // Distinct "WxH" strings for a monitor, widest first.
    function resolutions(m) {
        const seen = {}, out = [];
        for (const s of (m?.availableModes ?? [])) {
            const p = root.parseMode(s);
            if (!p) continue;
            const k = p.w + "x" + p.h;
            if (!seen[k]) { seen[k] = true; out.push({ key: k, w: p.w, h: p.h }); }
        }
        return out.sort((a, b) => (b.w * b.h) - (a.w * a.h));
    }
    // Refresh rates offered at a given "WxH", highest first.
    function rates(m, resKey) {
        const seen = {}, out = [];
        for (const s of (m?.availableModes ?? [])) {
            const p = root.parseMode(s);
            if (!p || p.w + "x" + p.h !== resKey) continue;
            const k = root.trim(p.hz, 2);
            if (!seen[k]) { seen[k] = true; out.push(p.hz); }
        }
        return out.sort((a, b) => b - a);
    }

    // --- Writing ---
    // `patch` carries only what changed: { width, height, refreshRate, x, y, scale, transform,
    // vrr, mirrorOf, disabled }.
    function apply(name, patch) {
        const m = root.byName(name);
        if (!m) return;
        const next = Object.assign({}, m, patch ?? {});
        Quickshell.execDetached(["hyprctl", "keyword", "monitor", root.monitorArg(next)]);
        // Re-read (and only then persist) so the file records what actually took effect.
        root.pendingPersist = true;
        debounce.restart();
    }
    function setDisabled(name, off) { root.apply(name, { disabled: !!off }); }
    // Blanking is a dispatch, not a keyword: it is a runtime state, not a configuration.
    function setDpms(name, on) {
        Quickshell.execDetached(["hyprctl", "dispatch", "dpms", on ? "on" : "off", name]);
        debounce.restart();
    }

    function persist() {
        if (root.monitors.length === 0) return;
        const body = "# Generated by quickshell — Settings > Displays.\n"
                   + "# Rewritten in full whenever a display setting changes there, so hand edits\n"
                   + "# will not survive. Sourced from hyprland.conf.\n"
                   + root.monitors.map(m => "monitor = " + root.monitorArg(m)).join("\n") + "\n";
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$2" > "$1"', "sh", root.confPath, body]);
    }
}
