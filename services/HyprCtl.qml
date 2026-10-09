pragma Singleton

// Every write into Hyprland — options, monitor rules, dispatches — goes through here, spelt for
// whichever config parser the compositor runs. Under a hyprland.lua (0.55+) `hyprctl keyword` is
// refused and `dispatch` takes a Lua expression, so the hyprlang spelling silently does nothing.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    // `hyprctl status` names the parser; a build without that command predates Lua.
    property bool lua: false
    property bool ready: false
    property var pending: []

    Process {
        running: true
        command: ["hyprctl", "-j", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.lua = JSON.parse(text).configProvider === "lua"; } catch (e) {}
                root.ready = true;
                const q = root.pending;
                root.pending = [];
                for (const f of q) f();
            }
        }
    }
    // Writes issued at startup wait for the answer instead of guessing the spelling.
    function whenReady(f) { if (root.ready) f(); else root.pending.push(f); }

    // --- Lua literals ---
    function luaValue(v) {
        if (typeof v === "boolean" || typeof v === "number") return String(v);
        return '"' + String(v).replace(/[\\"]/g, "\\$&").replace(/\n/g, "\\n") + '"';
    }
    function luaTable(o) {
        return "{ " + Object.keys(o).map(k => k + " = " + root.luaValue(o[k])).join(", ") + " }";
    }
    // "general:col.active_border" -> "general.col.active_border", the name hl.config knows it by.
    function luaKey(k) { return k.replace(/:/g, ".").replace(/-/g, "_"); }

    // --- Options ---
    // `opts` is keyed by hyprlang names; booleans go out as 1/0, which both parsers accept.
    function setOptions(opts) {
        root.whenReady(() => {
            const keys = Object.keys(opts);
            const val = v => typeof v === "boolean" ? (v ? 1 : 0) : v;
            if (root.lua)
                Quickshell.execDetached(["hyprctl", "eval", "hl.config({ "
                    + keys.map(k => `["${root.luaKey(k)}"] = ${root.luaValue(val(opts[k]))}`).join(", ") + " })"]);
            else
                Quickshell.execDetached(["hyprctl", "--batch",
                    keys.map(k => `keyword ${k} ${val(opts[k])}`).join(" ; ")]);
        });
    }
    // The option's name as `hyprctl getoption` takes it under the running parser.
    function optionName(k) { return root.lua ? root.luaKey(k) : k; }

    // --- Monitors ---
    // `legacy` is the argument half of `monitor = …`; `spec` the hl.monitor table.
    function setMonitor(legacy, spec) {
        root.whenReady(() => {
            if (!root.lua) {
                Quickshell.execDetached(["hyprctl", "keyword", "monitor", legacy]);
                return;
            }
            // Sent twice, a tick apart: Hyprland 0.56 ignores the first live rule for an output
            // that had none of its own (only a wildcard), and applies the second.
            Quickshell.execDetached(["hyprctl", "eval",
                "local s = " + root.luaTable(spec) + "\n"
                + "hl.monitor(s)\n"
                + 'hl.timer(function() hl.monitor(s) end, { timeout = 50, type = "oneshot" })']);
        });
    }

    // --- Dispatches ---
    // Each call carries both spellings: the hyprlang one, and the hl.dsp expression.
    function dispatch(legacy, lua) {
        root.whenReady(() => Hyprland.dispatch(root.lua ? lua : legacy));
    }
    // In order, in one request: quickshell opens a socket per dispatch() and writes on connect, so
    // back-to-back calls have no guaranteed order. `list` holds [legacy, lua] pairs.
    function dispatchAll(list) {
        if (list.length === 0) return;
        root.whenReady(() => {
            if (root.lua)
                Quickshell.execDetached(["hyprctl", "eval", list.map(p => "hl.dispatch(" + p[1] + ")").join("\n")]);
            else
                Quickshell.execDetached(["hyprctl", "--batch", list.map(p => "dispatch " + p[0]).join(" ; ")]);
        });
    }

    // `ws` is an id or a relative selector such as "e+1".
    function workspace(ws) {
        root.dispatch("workspace " + ws, "hl.dsp.focus(" + root.luaTable({ workspace: ws }) + ")");
    }
    function dpms(on, monitor) {
        const act = on ? "on" : "off";
        root.dispatch("dpms " + act + (monitor ? " " + monitor : ""),
            "hl.dsp.dpms(" + root.luaTable(monitor ? { action: act, monitor: monitor } : { action: act }) + ")");
    }
    function exit() { root.dispatch("exit", "hl.dsp.exit()"); }
}
