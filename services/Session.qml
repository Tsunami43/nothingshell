pragma Singleton

// Session verbs — the one place that knows how to end, suspend or restart the session.
// greeter.qml keeps its own pair: it runs before a session exists, under another user.
import Quickshell

Singleton {
    id: root

    function lock()     { Lock.locked = true; }
    function logout()   { Quickshell.execDetached(["hyprctl", "dispatch", "exit"]); }
    function suspend()  { Quickshell.execDetached(["systemctl", "suspend"]); }
    function reboot()   { Quickshell.execDetached(["systemctl", "reboot"]); }
    function poweroff() { Quickshell.execDetached(["systemctl", "poweroff"]); }

    // Menu order, with the glyph and label every caller was repeating. Same shape as Actions.qml.
    readonly property var actions: [
        { id: "lock",     icon: "lock",               label: "Lock",      destructive: false, run: () => root.lock() },
        { id: "logout",   icon: "logout",             label: "Log out",   destructive: true,  run: () => root.logout() },
        { id: "suspend",  icon: "bedtime",            label: "Suspend",   destructive: true,  run: () => root.suspend() },
        { id: "reboot",   icon: "restart_alt",        label: "Reboot",    destructive: true,  run: () => root.reboot() },
        { id: "poweroff", icon: "power_settings_new", label: "Shut down", destructive: true,  run: () => root.poweroff() }
    ]

    function find(id) { return root.actions.find(a => a.id === id) ?? null; }
    // A menu names the ids it offers, in the order it wants them.
    function pick(ids) { return ids.map(i => root.find(i)).filter(a => a !== null); }
    function run(id) { const a = root.find(id); if (a) a.run(); return a !== null; }
}
