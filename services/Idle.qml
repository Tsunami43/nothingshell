pragma Singleton

// Idle policy: auto-lock, display blanking, and the displaysOff flag heavy layers gate on.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

Singleton {
    id: root

    // True while the outputs are blanked — nothing on screen has a viewer.
    property bool displaysOff: false

    // Lock after Config.autoLockTimeout idle; keep-awake and game mode suppress it.
    IdleMonitor {
        enabled: Config.autoLock && !Lock.locked && !GameMode.enabled
        timeout: Config.autoLockTimeout
        respectInhibitors: true
        onIsIdleChanged: if (isIdle && Config.autoLock) Lock.locked = true
    }

    // Blank the displays after Config.dpmsTimeout idle (0 = never), tuned apart from the lock.
    IdleMonitor {
        id: dpms
        enabled: Config.dpmsTimeout > 0 && !GameMode.enabled
        timeout: Math.max(1, Config.dpmsTimeout)
        respectInhibitors: true
        onIsIdleChanged: root.setDisplays(!isIdle)
        // Turning the feature off must not strand a blanked screen.
        onEnabledChanged: if (!enabled && root.displaysOff) root.setDisplays(true)
    }

    // Guarded: re-issuing the state the outputs are already in wakes the compositor for nothing.
    function setDisplays(on) {
        if (root.displaysOff === !on) return;
        root.displaysOff = !on;
        Quickshell.execDetached(["hyprctl", "dispatch", "dpms", on ? "on" : "off"]);
    }
}
