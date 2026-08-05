pragma Singleton

// System locale and time zone. Read-only by design: `localectl set-locale` and
// `timedatectl set-timezone` both go through polkit and would pop an authentication dialog on
// every change. The settings page shows the current values and hands over the exact command
// instead, which is honest about who owns this setting.
//
// The name dodges two collisions: `Locale` is a built-in QML value type (what Qt.locale()
// returns) and `Region` is Quickshell's window-mask type. A singleton named after either shadows
// it — `Locale` silently reads back undefined everywhere, `Region` breaks every `mask:` in the
// shell.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false

    property string lang: ""          // LANG=…
    property string vcKeymap: ""
    property string x11Layout: ""
    property string timezone: ""
    property bool ntp: false
    property var localeCatalog: []    // every locale the system can be switched to
    property var timezones: []

    // The language as a human would name it, e.g. "English (United States)".
    readonly property string langName: {
        if (!root.lang) return "";
        const l = Qt.locale(root.lang.replace(/\..*$/, ""));
        const name = l.nativeLanguageName || l.name;
        const terr = l.nativeTerritoryName;
        return terr ? name + " (" + terr + ")" : name;
    }

    function refresh() { if (!statusProc.running) statusProc.running = true; }
    Process {
        id: statusProc
        // localectl and timedatectl in one pass; both print "Key: value" lines.
        command: ["sh", "-c", "localectl status; timedatectl show -p Timezone -p NTP"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const t = line.trim();
                    let m;
                    if ((m = /^System Locale:\s*LANG=(\S+)/.exec(t))) root.lang = m[1];
                    else if ((m = /^VC Keymap:\s*(\S+)/.exec(t))) root.vcKeymap = m[1];
                    else if ((m = /^X11 Layout:\s*(\S+)/.exec(t))) root.x11Layout = m[1];
                    else if ((m = /^Timezone=(\S+)/.exec(t))) root.timezone = m[1];
                    else if ((m = /^NTP=(\S+)/.exec(t))) root.ntp = m[1] === "yes";
                }
            }
        }
    }
    Process {
        id: catalogProc
        command: ["sh", "-c", "localectl list-locales; echo '--'; timedatectl list-timezones"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n--\n");
                root.localeCatalog = (parts[0] ?? "").trim().split("\n").filter(l => l.length > 0);
                root.timezones = (parts[1] ?? "").trim().split("\n").filter(l => l.length > 0);
            }
        }
    }

    Component.onCompleted: root.refresh()
    onActiveChanged: if (root.active && root.localeCatalog.length === 0) catalogProc.running = true

    // Put the privileged command on the clipboard rather than running it.
    function copyLocaleCommand(locale) {
        Quickshell.execDetached(["wl-copy", "sudo localectl set-locale LANG=" + locale]);
    }
    function copyTimezoneCommand(tz) {
        Quickshell.execDetached(["wl-copy", "sudo timedatectl set-timezone " + tz]);
    }
}
