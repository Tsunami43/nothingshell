pragma Singleton

// Hyprland-derived state: workspaces, urgency, active window, keyboard layout, fullscreen.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshMonitors();
        fsSettle.restart();
        kbProc.running = true;   // layout and device, before any event fires
    }

    readonly property var wsList:   Hyprland.workspaces?.values ?? []
    readonly property int activeWs: Hyprland.focusedWorkspace?.id ?? (wsList.find(w => w.active)?.id ?? 1)
    onActiveWsChanged: clearUrgent(activeWs)

    // Workspaces with a window requesting attention (Hyprland "urgent" event).
    property var urgentWs: ({})
    function markUrgent(addr) {
        const tl = (Hyprland.toplevels?.values ?? []).find(t => {
            const a = t.lastIpcObject?.address ?? "";
            return a === addr || a === "0x" + addr || "0x" + a === addr;
        });
        const ws = tl?.lastIpcObject?.workspace?.id ?? tl?.workspace?.id ?? 0;
        if (ws && ws !== root.activeWs) { const u = Object.assign({}, root.urgentWs); u[ws] = true; root.urgentWs = u; }
    }
    function clearUrgent(ws) {
        if (root.urgentWs[ws]) { const u = Object.assign({}, root.urgentWs); delete u[ws]; root.urgentWs = u; }
    }
    readonly property int maxWs: {
        let m = 5;
        for (const w of wsList) m = Math.max(m, w.id);
        return Math.max(m, activeWs);
    }
    function wsOccupied(id) { return wsList.some(w => w.id === id); }
    // Windows on a workspace (for the app-icon indicators).
    function wsWindows(id) { return (Hyprland.toplevels?.values ?? []).filter(t => (t.lastIpcObject?.workspace?.id ?? t.workspace?.id ?? -1) === id); }

    // --- Window verbs (the overview panel drives these) ---
    // Dispatch selectors want `address:0x…`, but the two sources disagree: HyprlandToplevel.address
    // is bare hex while lastIpcObject.address carries the prefix. Normalise in one place — a
    // malformed selector is a silent no-op, not an error.
    function addrOf(tl) {
        const a = tl?.address ? String(tl.address) : (tl?.lastIpcObject?.address ?? "");
        if (!a) return "";
        return a.startsWith("0x") ? a : "0x" + a;
    }
    function moveWindow(addr, ws) {
        if (!addr || !ws) return;
        // Silent: moving a window from the overview must not drag the view along with it.
        Hyprland.dispatch("movetoworkspacesilent " + ws + ",address:" + addr);
    }
    function focusWindow(addr) { if (addr) Hyprland.dispatch("focuswindow address:" + addr); }
    function closeWindow(addr) { if (addr) Hyprland.dispatch("closewindow address:" + addr); }

    // A workspace id mid-swap (0 = idle), so its row can refuse a second drag while it settles.
    property int wsBusy: 0

    // Hyprland has no single-monitor workspace swap — `swapactiveworkspaces` takes two MONITORS.
    // Address every window instead, with both lists snapshotted before anything is sent.
    //
    // One `hyprctl --batch`, not a loop of dispatch(): quickshell opens a socket per dispatch and
    // writes on connect, so back-to-back calls have no guaranteed order — and here order decides
    // which workspace a window ends up on.
    function swapWorkspaces(a, b) {
        if (!a || !b || a === b) return;
        const wa = wsWindows(a).map(t => addrOf(t)).filter(x => x);
        const wb = wsWindows(b).map(t => addrOf(t)).filter(x => x);
        if (wa.length === 0 && wb.length === 0) return;
        const cmds = wa.map(x => "dispatch movetoworkspacesilent " + b + ",address:" + x)
                       .concat(wb.map(x => "dispatch movetoworkspacesilent " + a + ",address:" + x));
        // Emptying a workspace makes Hyprland reap it, which can take focus with it.
        cmds.push("dispatch workspace " + root.activeWs);
        Quickshell.execDetached(["hyprctl", "--batch", cmds.join(" ; ")]);
    }

    // App class → Material Symbol by desktop-entry category.
    readonly property var categoryIcons: ({
        WebBrowser: "web", Printing: "print", Security: "security", Network: "chat",
        Archiving: "archive", Compression: "archive", Development: "code", IDE: "code",
        TextEditor: "edit_note", Audio: "music_note", Music: "music_note", Player: "music_note",
        Recorder: "mic", Game: "sports_esports", FileTools: "files", FileManager: "files",
        Filesystem: "files", FileTransfer: "files", Settings: "settings", DesktopSettings: "settings",
        HardwareSettings: "settings", TerminalEmulator: "terminal", ConsoleOnly: "terminal",
        Utility: "build", Monitor: "monitor_heart", Midi: "graphic_eq", Mixer: "graphic_eq",
        AudioVideoEditing: "video_settings", AudioVideo: "music_video", Video: "videocam",
        Building: "construction", Graphics: "photo_library", "2DGraphics": "photo_library",
        RasterGraphics: "photo_library", TV: "tv", System: "host", Office: "content_paste"
    })
    function appCategoryIcon(cls, fallback) {
        if (!cls) return fallback;
        const cats = DesktopEntries.heuristicLookup(cls)?.categories;
        if (cats) for (const k in categoryIcons) if (cats.includes(k)) return categoryIcons[k];
        return fallback;
    }

    // Keyboard layout — live via Hyprland's "activelayout" event (see onRawEvent below).
    // hyprctl is used only for the device name (needed to switch) and the initial value.
    property string kbLayout: "—"
    property string kbDevice: ""
    function setKbLayout(km) {
        if (!km) return;
        if (km.includes("Russian")) root.kbLayout = "RU";
        else {
            const m = km.match(/\(([A-Za-z]+)\)/);
            root.kbLayout = (m ? m[1] : km).slice(0, 2).toUpperCase();
        }
    }
    Process {
        id: kbProc
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            id: kbOut
            onStreamFinished: {
                try {
                    const d = JSON.parse(kbOut.text);
                    const kbs = d.keyboards || [];
                    const kb = kbs.find(k => k.main) || kbs[0];
                    if (kb) {
                        root.kbDevice = kb.name || "";
                        root.setKbLayout(kb.active_keymap || "");
                    }
                } catch (e) {}
            }
        }
    }
    // Slow fallback: the event keeps the layout live, this only refreshes the device name.
    // Off on battery, where start-up is the only read.
    Timer {
        interval: Math.max(1, Power.kbDevicePollMs); running: Power.kbDevicePollMs > 0
        repeat: true; triggeredOnStart: true
        onTriggered: kbProc.running = true
    }

    // --- Fullscreen, per monitor ---
    // Hyprland's `fullscreen` event names no window and carries only 1/0, so one global flag meant
    // a window going fullscreen ANYWHERE — a video on a workspace nobody was looking at, on any
    // output — hid the bar and dropped its exclusive zone on every screen at once. The
    // authoritative reading is per workspace (`hasfullscreen` in its ipc object), taken for
    // whichever workspace each monitor is currently showing.
    //
    // Recomputed rather than bound: lastIpcObject carries no change notification, so a binding on
    // it would keep reporting whatever was true when the monitors first loaded.
    property var fsByMonitor: ({})
    function recomputeFullscreen() {
        const m = {};
        for (const mon of (Hyprland.monitors?.values ?? []))
            m[mon.name] = mon.activeWorkspace?.lastIpcObject?.hasfullscreen === true;
        root.fsByMonitor = m;
    }
    function fullscreenOn(name) { return root.fsByMonitor[name] === true; }

    // The event lands a few hundred milliseconds before the refresh it triggers, and the bar must
    // not lag behind the window it is getting out of the way of — so the focused monitor is set
    // from the event at once and the recompute below confirms or corrects it.
    function setFullscreenNow(on) {
        const name = Hyprland.focusedMonitor?.name ?? "";
        if (!name || root.fsByMonitor[name] === on) return;
        const m = Object.assign({}, root.fsByMonitor);
        m[name] = on;
        root.fsByMonitor = m;
    }

    // What a global consumer (notification suppression) asks: is the screen being looked at
    // showing a fullscreen window. Per-screen consumers call fullscreenOn() with their own output.
    readonly property bool fullscreenActive: root.fullscreenOn(Hyprland.focusedMonitor?.name ?? "")

    // Active (focused) window — instant, via Hyprland's raw event stream ("activewindow>>class,title").
    property string activeClass: ""
    property string activeTitle: ""
    readonly property var activeEntry: activeClass ? DesktopEntries.byId(activeClass) : null
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindow") {
                const p = event.parse(2);       // [class, title]
                root.activeClass = p[0] ?? "";
                root.activeTitle = p[1] ?? "";
            } else if (event.name === "activelayout") {
                const p = event.parse(2);       // [keyboardName, layoutName]
                if (!root.kbDevice || p[0] === root.kbDevice) root.setKbLayout(p[1] ?? "");
            } else if (event.name === "fullscreen") {
                root.setFullscreenNow(event.parse(1)[0] === "1");
                refreshDebounce.restart();
            } else if (event.name === "urgent") {
                root.markUrgent(event.parse(1)[0]);
            } else if (event.name.includes("workspace") || event.name === "focusedmon") {
                // Safe default until the refresh lands: showing the bar over a fullscreen window
                // for 300ms is a smaller sin than hiding it over a workspace that has none.
                root.setFullscreenNow(false);
                refreshDebounce.restart();
            } else if (event.name.includes("window") || event.name === "movewindow") {
                // Keep the per-workspace window list (used for the app-icon indicators) current.
                refreshDebounce.restart();
            }
        }
    }
    // Moving a batch of windows fires an event per window, each asking for the same two refreshes.
    // Coalesce them: quickshell already drops re-entrant refreshes, but every event landing after
    // one completes still starts a fresh round-trip.
    Timer {
        id: refreshDebounce
        interval: 40
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshMonitors();   // activeWorkspace per output, which fullscreen state keys off
            fsSettle.restart();
        }
    }
    // The three refreshes above are IPC round-trips and nothing signals their completion, so the
    // recompute waits them out. Measured at ~250ms of headroom on this machine; the event-driven
    // path above already covers the common case instantly, this only reconciles it.
    Timer { id: fsSettle; interval: 250; onTriggered: root.recomputeFullscreen() }

    // Initial state (raw events only fire on a subsequent focus change).
    Process {
        running: true
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector {
            id: awInit
            onStreamFinished: {
                try { const d = JSON.parse(awInit.text); root.activeClass = d.class || ""; root.activeTitle = d.title || ""; } catch (e) {}
            }
        }
    }
}
