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
        Quickshell.execDetached(["hyprctl", "--batch",
            "keyword animations:enabled 0 ; " +
            "keyword decoration:blur:enabled 0 ; " +
            "keyword decoration:shadow:enabled 0 ; " +
            "keyword general:gaps_in 0 ; " +
            "keyword general:gaps_out 0 ; " +
            "keyword decoration:rounding 0 ; " +
            "keyword general:allow_tearing 1"]);
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
