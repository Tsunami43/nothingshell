pragma Singleton

// Power policy: what the shell stops paying for while it runs off the battery.
// GameMode turned around — that one trades power for frames, this one for runtime.
import QtQuick
import Quickshell
import qs

Singleton {
    id: root

    // Config.batterySaver is the switch; the battery decides when it applies.
    readonly property bool saving: Config.batterySaver && Bat.onBattery

    // --- Decoding ---
    readonly property bool videoWallpaper: !root.saving
    readonly property bool windowThumbs: Config.overviewThumbs && !root.saving

    // --- Drawing ---
    // Off, the frame draws as plain rectangles instead of a full-screen shader pass.
    readonly property bool frameShader: !root.saving
    // Pushed, not pulled: Motion has no business knowing about batteries.
    Binding {
        target: Motion
        property: "scale"
        value: Config.motionScale * (root.saving ? 0.6 : 1.0)
    }

    // --- Waking up ---
    // Milliseconds, 0 = don't poll. Each has a live event source that keeps working without it.
    readonly property int netPollMs: root.saving ? 0 : 30000
    readonly property int kbDevicePollMs: root.saving ? 0 : 30000
    // Throttled, not stopped: it reads one sysfs file and nothing else watches the tunnel.
    readonly property int vpnPollMs: root.saving ? 30000 : 5000
}
