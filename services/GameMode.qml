pragma Singleton

// Game mode: strips Hyprland eye-candy (animations/blur/shadows/gaps/rounding) for
// performance, and tells the shell to suppress notification popups + auto-lock.
// Toggle via IPC (`qs -c nothingshell ipc call gamemode toggle`) or the sidebar tile.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool enabled: false

    function apply() {
        HyprCtl.setOptions({
            "animations:enabled": false,
            "decoration:blur:enabled": false,
            "decoration:shadow:enabled": false,
            "general:gaps_in": 0,
            "general:gaps_out": 0,
            "decoration:rounding": 0,
            "general:allow_tearing": true
        });
    }

    function toggle() {
        root.enabled = !root.enabled;
        if (root.enabled) apply();
        else Quickshell.execDetached(["hyprctl", "reload"]);   // restore user's config
    }

    IpcHandler {
        target: "gamemode"
        function toggle(): void { root.toggle(); }
        function isEnabled(): bool { return root.enabled; }
    }
}
