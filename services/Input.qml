pragma Singleton

// Keyboard input: the xkb layout list, its variants and options, and which layout is live.
//
// Reads `hyprctl -j devices` (plus getoption for the non-per-device toggles); writes through
// `hyprctl keyword` plus a regenerated input.conf under the shell's own config directory
// (Paths.inputConf), mirroring services/Display.qml.
//
// services/Hypr.qml also tracks the active layout, off the `activelayout` event, so the bar
// updates without polling. This service is the wider, on-demand view the settings page needs.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

Singleton {
    id: root

    readonly property string confPath: Paths.inputConf

    // Set by the Language & input page while it is on screen.
    property bool active: false

    property var keyboards: []
    // The keyboard Hyprland treats as primary; its layout list is the system's.
    readonly property var main: root.keyboards.find(k => k.main) ?? root.keyboards[0] ?? null

    readonly property var layouts: {
        const s = root.main?.layout ?? "";
        return s ? s.split(",") : [];
    }
    readonly property var variants: {
        const s = root.main?.variant ?? "";
        // A trailing empty variant is meaningful (layout 2 has none), so do not filter.
        return s ? s.split(",") : root.layouts.map(() => "");
    }
    readonly property string options: root.main?.options ?? ""
    readonly property int activeIndex: root.main?.active_layout_index ?? 0
    readonly property string activeKeymap: root.main?.active_keymap ?? ""

    property bool numlock: false
    // Every layout xkb knows about, for the "add a layout" picker.
    property var catalog: []

    // --- Reading ---
    function refresh() { if (!devProc.running) devProc.running = true; }
    Process {
        id: devProc
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.keyboards = (JSON.parse(text).keyboards ?? []); }
                catch (e) { root.keyboards = []; }
            }
        }
    }
    Process {
        id: numlockProc
        command: ["hyprctl", "-j", "getoption", "input:numlock_by_default"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.numlock = JSON.parse(text).int === 1; } catch (e) {}
            }
        }
    }
    Process {
        id: catalogProc
        command: ["localectl", "list-x11-keymap-layouts"]
        stdout: StdioCollector {
            onStreamFinished: root.catalog = text.trim().split("\n").filter(l => l.length > 0)
        }
    }

    Component.onCompleted: { root.refresh(); numlockProc.running = true; }
    onActiveChanged: if (root.active && root.catalog.length === 0) catalogProc.running = true
    Timer {
        interval: 4000; repeat: true; running: root.active
        onTriggered: root.refresh()
    }
    // The layout can also change from a keybind (Caps here), so follow the event too.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout" || event.name === "configreloaded") debounce.restart();
        }
    }
    Timer { id: debounce; interval: 150; onTriggered: root.refresh() }

    // --- Switching the live layout ---
    function device() { return root.main?.name ?? "all"; }
    function next() {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", root.device(), "next"]);
        debounce.restart();
    }
    function setLayout(i) {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", root.device(), "" + i]);
        debounce.restart();
    }

    // --- Editing the layout list ---
    // Hyprland re-creates every keyboard when kb_layout changes, so all four keywords go together
    // and the file is rewritten from the same values — nothing to read back.
    // `hyprctl --batch` separates commands with ';', so anything spliced into one of these values
    // can start a command of its own — and kb_options is a free-text field in Settings. Keep the
    // values to what xkb names actually look like.
    function clean(s) { return String(s ?? "").replace(/[^A-Za-z0-9_,:+\-]/g, ""); }

    function applyLayouts(list, vars, opts, numlockOn) {
        const layout = root.clean(list.join(","));
        const variant = root.clean((vars ?? list.map(() => "")).join(","));
        const options = root.clean(opts === undefined ? root.options : opts);
        const nl = numlockOn === undefined ? root.numlock : !!numlockOn;
        Quickshell.execDetached(["hyprctl", "--batch",
            `keyword input:kb_layout ${layout} ; ` +
            `keyword input:kb_variant ${variant} ; ` +
            `keyword input:kb_options ${options} ; ` +
            `keyword input:numlock_by_default ${nl ? 1 : 0}`]);
        root.numlock = nl;
        root.persist(layout, variant, options, nl);
        debounce.restart();
    }
    function addLayout(name) {
        if (!name || root.layouts.indexOf(name) >= 0) return;
        const l = root.layouts.concat([name]);
        root.applyLayouts(l, root.variants.concat([""]));
    }
    function removeLayout(i) {
        // One layout has to remain: an empty kb_layout leaves the keyboard with no keymap at all.
        if (root.layouts.length <= 1 || i < 0 || i >= root.layouts.length) return;
        const l = root.layouts.slice(), v = root.variants.slice();
        l.splice(i, 1); v.splice(i, 1);
        root.applyLayouts(l, v);
    }
    function moveLayout(i, delta) {
        const j = i + delta;
        if (i < 0 || j < 0 || i >= root.layouts.length || j >= root.layouts.length) return;
        const l = root.layouts.slice(), v = root.variants.slice();
        [l[i], l[j]] = [l[j], l[i]];
        [v[i], v[j]] = [v[j], v[i]];
        root.applyLayouts(l, v);
    }
    function setOptions(opts) { root.applyLayouts(root.layouts, root.variants, opts); }
    function setNumlock(on) { root.applyLayouts(root.layouts, root.variants, undefined, on); }

    function persist(layout, variant, options, numlockOn) {
        const body = "# Generated by quickshell — Settings > Language & input.\n"
                   + "# Rewritten in full whenever a keyboard setting changes there, so hand edits\n"
                   + "# will not survive. Sourced from hyprland.conf, after the inline input block.\n"
                   + "input {\n"
                   + "    kb_layout = " + layout + "\n"
                   + "    kb_variant = " + variant + "\n"
                   + "    kb_options = " + options + "\n"
                   + "    numlock_by_default = " + (numlockOn ? "true" : "false") + "\n"
                   + "}\n";
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$2" > "$1"', "sh", root.confPath, body]);
    }
}
