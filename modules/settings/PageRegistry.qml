pragma Singleton

// The settings window's table of contents: one entry per page, in nav order, grouped by category.
// Settings.qml holds page Components index-aligned with `pages`, so adding a page is an entry here
// plus a Component there. The nav pane, deep-link ids and search all fall out of this list.
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var pages: [
        // --- Appearance ---
        { id: "appearance", icon: "palette", label: "Appearance",
          desc: "Theme, colours, wallpaper, font", category: "Appearance" },

        // --- Hardware ---
        { id: "displays", icon: "monitor", label: "Displays",
          desc: "Resolution, scale, arrangement", category: "Hardware" },
        { id: "audio", icon: "volume_up", label: "Audio",
          desc: "Output, input, app volumes", category: "Hardware" },
        { id: "bluetooth", icon: "devices_other", label: "Connected devices",
          desc: "Bluetooth, pairing", category: "Hardware" },

        // --- Network ---
        { id: "network", icon: "wifi", label: "Network",
          desc: "Wi-Fi, ethernet", category: "Network" },
        { id: "vpn", icon: "vpn_key", label: "VPN",
          desc: "Profiles and providers", category: "Network" },

        // --- System ---
        { id: "language", icon: "globe", label: "Language & input",
          desc: "Locale, keyboard layouts", category: "System" },
        { id: "power", icon: "power_settings_new", label: "Power & lock",
          desc: "Idle, auto-lock, session actions", category: "System" },

        // --- Shell ---
        { id: "shell", icon: "dock_to_bottom", label: "Shell",
          desc: "Bar, dashboard, launcher", category: "Shell" },
        { id: "notifs", icon: "notifications", label: "Notifications",
          desc: "Do not disturb, toasts", category: "Shell" },
        { id: "capture", icon: "screenshot_region", label: "Capture",
          desc: "Screenshot and recording defaults", category: "Shell" },

        // --- About ---
        { id: "about", icon: "info", label: "About",
          desc: "System information", category: "About" }
    ]

    // -1 when the id is unknown, so callers can fall back to whatever page is open.
    function indexOf(id) {
        if (!id) return -1;
        return root.pages.findIndex(p => p.id === id);
    }
}
