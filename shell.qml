//@ pragma UseQApplication
// Custom shell (v2) — vertical left bar + hover dashboard, launcher and panels.
// Target: quickshell 0.3.0 (stable), Hyprland. Run: qs -c nothingshell
// UseQApplication is required for native system-tray context menus.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules

ShellRoot {
    id: root

    // Palette/font aliases onto Config, so the older `root.<x>` references keep working.
    readonly property color bg:        Config.bg
    readonly property color surface:   Config.surface
    readonly property color container: Config.container
    readonly property color outline:   Config.outline
    readonly property color dim:       Config.dim
    readonly property color fg:        Config.fg
    readonly property color accent:    Config.accent
    readonly property color tertiary:  Config.tertiary
    readonly property color error:     Config.error
    readonly property string textFont: Config.textFont
    readonly property real popFillet:  Config.popFillet
    readonly property real popCorner:  Config.popCorner

    // HyprColors is a singleton: touching it here is what instantiates it, and the call
    // pushes the current palette into Hyprland's borders/background right away.
    Component.onCompleted: { Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces(); HyprColors.apply(); }
    // Lazy singletons with no other reference in the tree: touching them here is what starts
    // the clipboard watcher, the idle monitors and Power's Motion binding.
    readonly property var eagerServices: [Clip, Idle, Power]

    // Lets a Hyprland keybind toggle the launcher: `qs -c nothingshell ipc call launcher toggle`.
    IpcHandler {
        target: "launcher"
        function toggle(): void { Shell.launcherVisible = !Shell.launcherVisible }
        // `... launcher open '>theme'` opens with the field pre-filled, so a keybind can land
        // directly in the command palette or a preview carousel.
        function open(query: string): void { Shell.openLauncher(query) }
    }
    IpcHandler {
        target: "session"
        function toggle(): void { Shell.sessionVisible = !Shell.sessionVisible }
    }
    // The hover-opened surfaces, reachable without a pointer (see hypr/nothingshell.conf).
    IpcHandler {
        target: "dashboard"
        function toggle(): void { Shell.dashboardVisible = !Shell.dashboardVisible }
        function open(): void { Shell.dashboardVisible = true }
        function close(): void { Shell.dashboardVisible = false }
    }
    IpcHandler {
        target: "overview"
        function toggle(): void { Shell.overviewVisible = !Shell.overviewVisible }
        function open(): void { Shell.overviewVisible = true }
        function close(): void { Shell.overviewVisible = false }
    }
    // Names as the bar uses them: volume, rec, brightness, network, bluetooth, vpn, traymenu, power.
    IpcHandler {
        target: "bar"
        function popout(name: string): void { Shell.barPopout = name ?? "" }
        function close(): void { Shell.barPopout = "" }
    }
    // `qs -c nothingshell ipc call settings toggle`, or `... settings open appearance` to land on a page
    // (ids come from modules/settings/PageRegistry.qml).
    IpcHandler {
        target: "settings"
        function toggle(): void { Shell.settingsVisible = !Shell.settingsVisible }
        function open(page: string): void { Shell.openSettings(page) }
    }
    // `qs -c nothingshell ipc call clipboard clear` — handy for a "panic" keybind.
    IpcHandler {
        target: "clipboard"
        function count(): int { return Clip.entries.length }
        function clear(): void { Clip.clear() }
        // The recorder already skips anything a password manager marks as a secret, but nothing
        // marks a password typed by hand into a form and copied out again. These bind the same
        // switch Settings > Shell offers, so a keybind can stop the history for a moment without
        // discarding what is already in it.
        function pause(): void { Config.clipboardEnabled = false }
        function resume(): void { Config.clipboardEnabled = true }
        function toggle(): bool { Config.clipboardEnabled = !Config.clipboardEnabled; return Config.clipboardEnabled }
    }
    IpcHandler {
        target: "media"
        function playpause(): void { Media.playPause(); }
        function next(): void { Media.next(); }
        function previous(): void { Media.previous(); }
    }

    // Lock via keybind: `qs -c nothingshell ipc call lock lock`.
    IpcHandler {
        target: "lock"
        function lock(): void { Lock.locked = true }
    }

    // Notifications (server + toast queue) live in the Notifs service; both suppression rules are
    // configurable from Settings > Notifications.
    Binding {
        target: Notifs
        property: "suppress"
        value: (Config.notifSuppressFullscreen && Hypr.fullscreenActive) || (Config.notifSuppressGame && GameMode.enabled)
    }

    // Auto-lock and blanking live in services/Idle.qml, which publishes displaysOff.

    // The windows. Everything below is per-screen except the lock screen (one session-wide
    // surface) and Settings (a normal application window the compositor places itself).
    //
    // A layer-shell window whose size binding throws once (a ReferenceError in a `height:` is
    // enough) can stay unmapped for the rest of the process: it vanishes from `hyprctl layers`
    // and no amount of hot-reloading brings it back, while its QML keeps running — so a popout's
    // bulge still draws and only the content is missing. Fix the binding, then restart the shell;
    // hot-reload alone will look like the fix did nothing.
    Variants {
        model: Quickshell.screens
        // The wallpaper path is persisted in Config; setWallpaper writes Config.wallpaper.
        Background {}
    }
    Variants {
        model: Quickshell.screens
        // Per output: a fullscreen window on one screen must not strip the frame off the other.
        Frame { suppressed: Hypr.fullscreenOn(modelData?.name ?? "") }
    }
    Variants { model: Quickshell.screens; Toasts {} }
    Variants { model: Quickshell.screens; VolumeOsd {} }
    Variants { model: Quickshell.screens; MediaOsd {} }
    // Dashboard hangs off the top edge and is revealed by hovering it.
    Variants { model: Quickshell.screens; Dashboard {} }
    // Workspace overview does the same off the right edge.
    Variants { model: Quickshell.screens; Overview {} }
    Variants { model: Quickshell.screens; Bar {} }
    LockScreen {}
    Variants { model: Quickshell.screens; Launcher {} }
    Variants { model: Quickshell.screens; CapturePanel {} }
    // Session/power lives in the bar's own popout (modules/Bar.qml), not a separate window.
    Settings {}

}
