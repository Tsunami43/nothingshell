pragma Singleton

// The launcher's ">" command palette, kept out of Launcher.qml because it is pure data: an entry
// is { name, desc, icon, keywords, kind, arg } and `run` is the only place that knows the kinds.
//
// Kinds:
//   settings  — open the settings window on a page id (see modules/settings/PageRegistry.qml)
//   mode      — switch the launcher into a live-preview carousel; the launcher stays open
//   prefix    — rewrite the query as a plain prefix mode ("#"…); the launcher stays open
//   toggle    — flip a shell/system switch; the launcher stays open so the row updates in place
//   exec      — do something and get out of the way
import QtQuick
import Quickshell
import qs

Singleton {
    id: root

    // Rebuilt whenever anything it reads changes, so toggle rows can name their own state.
    readonly property var list: {
        const out = [
            // --- Live-preview modes ---
            { name: "Theme", desc: "Browse the curated colour themes", icon: "palette",
              keywords: "colour color scheme preset", kind: "mode", arg: "theme" },
            { name: "Wallpaper", desc: "Browse wallpapers and regenerate the palette", icon: "wallpaper",
              keywords: "background image picture", kind: "mode", arg: "wallpaper" },
            { name: "Font", desc: "Browse the bundled text faces", icon: "text_fields",
              keywords: "typeface text typography", kind: "mode", arg: "font" },
            // No live entry count here: the whole array is one binding, so reading Clip.entries
            // would rebuild ~35 objects per copy. "#" itself shows the count for free.
            { name: "Clipboard history", desc: "Search and re-copy what you copied — Enter copies, Delete drops",
              icon: "content_paste", keywords: "paste copy buffer история буфер",
              kind: "prefix", arg: "#" },

            // --- Settings pages ---
            { name: "Appearance settings", desc: "Theme, colours, wallpaper, font", icon: "format_paint",
              keywords: "look style", kind: "settings", arg: "appearance" },
            { name: "Display settings", desc: "Resolution, refresh rate, scale", icon: "monitor",
              keywords: "monitor screen resolution hz scale", kind: "settings", arg: "displays" },
            { name: "Audio settings", desc: "Output, input, app volumes", icon: "volume_up",
              keywords: "sound volume speaker microphone", kind: "settings", arg: "audio" },
            { name: "Network settings", desc: "Wi-Fi and ethernet", icon: "wifi",
              keywords: "wifi wlan internet ethernet", kind: "settings", arg: "network" },
            { name: "VPN settings", desc: "Profiles and providers", icon: "vpn_key",
              keywords: "tunnel wireguard openvpn", kind: "settings", arg: "vpn" },
            { name: "Bluetooth settings", desc: "Connected devices and pairing", icon: "bluetooth",
              keywords: "device pair headphones", kind: "settings", arg: "bluetooth" },
            { name: "Language & input", desc: "Locale, timezone, keyboard layouts", icon: "globe",
              keywords: "keyboard layout xkb locale region timezone", kind: "settings", arg: "language" },
            { name: "Power & lock", desc: "Idle, auto-lock, session actions", icon: "power_settings_new",
              keywords: "sleep suspend idle battery", kind: "settings", arg: "power" },
            { name: "Notification settings", desc: "Do not disturb, toasts", icon: "notifications",
              keywords: "toast popup dnd", kind: "settings", arg: "notifs" },
            { name: "Capture settings", desc: "Screenshot and recording defaults", icon: "screenshot_region",
              keywords: "screenshot record video", kind: "settings", arg: "capture" },
            { name: "Shell settings", desc: "Bar, dashboard, launcher", icon: "dock_to_bottom",
              keywords: "bar panel dashboard widget", kind: "settings", arg: "shell" },
            { name: "About this system", desc: "Kernel, hardware, versions", icon: "info",
              keywords: "version system info", kind: "settings", arg: "about" },

            // --- Toggles ---
            { name: Config.autoColors ? "Auto colours — on" : "Auto colours — off",
              desc: "Derive the palette from the wallpaper", icon: "auto_awesome",
              keywords: "material you dynamic", kind: "toggle", arg: "autoColors" },
            { name: Config.lightMode ? "Light mode — on" : "Light mode — off",
              desc: Config.autoColors ? "Light or dark generated palette"
                                      : "Only available with auto colours",
              icon: Config.lightMode ? "light_mode" : "dark_mode",
              keywords: "dark theme brightness", kind: "toggle", arg: "light" },
            { name: Net.wifiOn ? "Wi-Fi — on" : "Wi-Fi — off",
              desc: Net.wifiOn ? (Net.wifiSsid || "Not connected") : "Radio off", icon: "wifi",
              keywords: "wireless wlan network", kind: "toggle", arg: "wifi" },
            { name: Bt.enabled ? "Bluetooth — on" : "Bluetooth — off",
              desc: "Bluetooth adapter power", icon: "bluetooth",
              keywords: "device pair", kind: "toggle", arg: "bt" },
            { name: Config.dnd ? "Do not disturb — on" : "Do not disturb — off",
              desc: "Silence notification toasts", icon: "notifications_off",
              keywords: "silence mute notification", kind: "toggle", arg: "dnd" },
            { name: Shell.keepAwake ? "Keep awake — on" : "Keep awake — off",
              desc: "Inhibit idling and the screen lock", icon: "local_cafe",
              keywords: "caffeine idle inhibit sleep", kind: "toggle", arg: "keepAwake" },
            { name: GameMode.enabled ? "Game mode — on" : "Game mode — off",
              desc: "Drop animations, blur and rounding", icon: "sports_esports",
              keywords: "performance fps gaming", kind: "toggle", arg: "gameMode" },
            { name: Config.autoLock ? "Auto-lock — on" : "Auto-lock — off",
              desc: "Lock the screen after idling", icon: "lock_clock",
              keywords: "idle security", kind: "toggle", arg: "autoLock" },

            // --- Actions ---
            { name: "Screenshot a region", desc: "Pick an area with slurp", icon: "screenshot_region",
              keywords: "capture grab crop", kind: "exec", arg: "shotRegion" },
            { name: "Screenshot the screen", desc: "Grab the focused output", icon: "fullscreen",
              keywords: "capture grab", kind: "exec", arg: "shotScreen" },
            // No elapsed time here, for the same reason Clip.entries is kept out above: the whole
            // array is one binding, and elapsedText ticks twice a second, so a running recording
            // rebuilt ~40 objects every 500ms whether or not the launcher was even open.
            { name: Capture.active ? "Stop recording" : "Record the screen",
              desc: Capture.active ? "Recording — Enter stops it" : "Open the capture panel",
              icon: "screen_record",
              keywords: "video capture gsr", kind: "exec", arg: "record" },
            { name: "Switch keyboard layout", desc: Input.activeKeymap || "Cycle to the next layout",
              icon: "keyboard", keywords: "xkb language input", kind: "exec", arg: "kbNext" },
            { name: "Regenerate palette", desc: "Re-run matugen on the current wallpaper",
              icon: "auto_fix_high", keywords: "matugen colours material", kind: "exec", arg: "regenTheme" },
            { name: "Reload the shell", desc: "Re-read every QML file", icon: "refresh",
              keywords: "restart quickshell", kind: "exec", arg: "reload" },
            { name: "Lock the screen", desc: "", icon: "lock",
              keywords: "security away", kind: "exec", arg: "lock" },
            { name: "Clear clipboard history",
              desc: "Drop every stored entry and empty the clipboard",
              icon: "content_paste_off", keywords: "paste copy buffer wipe",
              kind: "exec", arg: "clipClear" },

            // --- Session (hidden when Config.launcherDangerous is off) ---
            { name: "Log out", desc: "End the Hyprland session", icon: "logout",
              keywords: "exit quit session", kind: "exec", arg: "logout", dangerous: true },
            { name: "Suspend", desc: "Sleep to RAM", icon: "bedtime",
              keywords: "sleep standby", kind: "exec", arg: "suspend", dangerous: true },
            { name: "Reboot", desc: "Restart the machine", icon: "restart_alt",
              keywords: "restart", kind: "exec", arg: "reboot", dangerous: true },
            { name: "Shut down", desc: "Power off the machine", icon: "power_settings_new",
              keywords: "poweroff halt", kind: "exec", arg: "poweroff", dangerous: true }
        ];
        return Config.launcherDangerous ? out : out.filter(a => !a.dangerous);
    }

    // Substring match across every field, so ">wifi", ">wireless" and ">wlan" reach one row.
    function search(query) {
        const q = (query ?? "").trim().toLowerCase();
        if (!q) return root.list;
        return root.list.filter(a =>
            (a.name + " " + (a.desc ?? "") + " " + (a.keywords ?? "")).toLowerCase().includes(q));
    }

    // Returns true when the launcher should close.
    function run(a, launcher) {
        if (!a) return true;
        switch (a.kind) {
        case "settings":
            Shell.launcherVisible = false;
            Shell.openSettings(a.arg);
            return true;
        case "mode":
            // Handled by the launcher itself: it rewrites the query and shows the carousel.
            if (launcher) launcher.enterMode(a.arg);
            return false;
        case "prefix":
            // Same idea, but hands off to a plain prefix mode ("#", ":"…) rather than a carousel.
            if (launcher) launcher.enterPrefix(a.arg);
            return false;
        case "toggle":
            root.toggle(a.arg);
            // Stay open: the row renames itself, which is the confirmation.
            return false;
        case "exec":
            return root.exec(a.arg);
        }
        return true;
    }

    function toggle(what) {
        switch (what) {
        case "autoColors": Config.autoColors = !Config.autoColors; break;
        // Only auto mode has a light/dark switch — a curated preset carries its own.
        case "light": if (Config.autoColors) Config.autoLight = !Config.autoLight; break;
        case "wifi": Net.toggleWifi(); break;
        case "bt": Bt.toggle(); break;
        case "dnd": Config.dnd = !Config.dnd; break;
        case "keepAwake": Shell.keepAwake = !Shell.keepAwake; break;
        case "gameMode": GameMode.toggle(); break;
        case "autoLock": Config.autoLock = !Config.autoLock; break;
        }
    }

    function exec(what) {
        switch (what) {
        case "shotRegion": Shell.launcherVisible = false; Capture.screenshot("region"); return true;
        case "shotScreen": Shell.launcherVisible = false; Capture.screenshot("screen"); return true;
        case "record":
            Shell.launcherVisible = false;
            // Stop outright while recording; otherwise hand off to the capture panel, which owns
            // the source and format choice.
            if (Capture.active) Capture.stop();
            else { Shell.captureScreen = Capture.monitor(); Shell.captureVisible = true; }
            return true;
        case "kbNext": Input.next(); return true;
        case "clipClear": Clip.clear(); return false;
        case "regenTheme": Wallpaper.regenTheme(); return true;
        case "reload": Quickshell.reload(false); return true;
        case "lock": Shell.launcherVisible = false; Lock.locked = true; return true;
        case "logout": Quickshell.execDetached(["hyprctl", "dispatch", "exit"]); return true;
        case "suspend": Quickshell.execDetached(["systemctl", "suspend"]); return true;
        case "reboot": Quickshell.execDetached(["systemctl", "reboot"]); return true;
        case "poweroff": Quickshell.execDetached(["systemctl", "poweroff"]); return true;
        }
        return true;
    }
}
