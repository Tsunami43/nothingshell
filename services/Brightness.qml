pragma Singleton

// Screen brightness: /sys/class/backlight for a laptop panel, ddcutil for a monitor.
// The panel wins where both exist — it is what costs battery and what the Fn keys move.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // --- Internal panel ---
    property string blPath: ""        // /sys/class/backlight/<device>
    property string blDevice: ""      // the <device>, which is what brightnessctl wants
    property bool hasBrightnessctl: false
    property int blRaw: -1
    property int blMax: 0
    readonly property bool hasInternal: root.blPath !== "" && root.blMax > 0

    // --- External monitor ---
    property int ddcBus: -1
    property int ddcPercent: -1
    readonly property bool hasDdc: root.ddcBus >= 0 && root.ddcPercent >= 0

    readonly property bool available: root.hasInternal || root.hasDdc
    // Percent of whichever backend is in play, which is all any caller wants.
    readonly property int brightness: root.hasInternal
        ? (root.blMax > 0 ? Math.round(root.blRaw * 100 / root.blMax) : 0)
        : Math.max(0, root.ddcPercent)

    property int briPending: 0

    Component.onCompleted: blFind.running = true

    // One scan: the panel, and whether brightnessctl is around to write it.
    Process {
        id: blFind
        command: ["sh", "-c",
            'for d in /sys/class/backlight/*; do [ -r "$d/brightness" ] && { echo "dev:$d"; break; }; done; '
            + 'command -v brightnessctl >/dev/null 2>&1 && echo "ctl:1"']
        stdout: StdioCollector {
            id: blFindOut
            onStreamFinished: {
                for (const line of blFindOut.text.split("\n")) {
                    if (line.startsWith("dev:")) {
                        root.blPath = line.slice(4);
                        root.blDevice = root.blPath.split("/").pop();
                    } else if (line.startsWith("ctl:")) {
                        root.hasBrightnessctl = true;
                    }
                }
                // Only probe i2c when there is no panel: `ddcutil detect` takes seconds.
                if (root.blPath === "") ddcDetect.running = true;
            }
        }
    }

    // Watched, not polled: the kernel rewrites this whenever anything moves the backlight.
    FileView {
        id: blFile
        path: root.blPath ? root.blPath + "/brightness" : ""
        blockLoading: true; watchChanges: true; printErrors: false
        onFileChanged: blFile.reload()
        onLoaded: {
            const v = parseInt(blFile.text().trim());
            if (Number.isFinite(v)) root.blRaw = v;
        }
    }
    // Fixed for the life of the machine, so read once.
    FileView {
        id: blMaxFile
        path: root.blPath ? root.blPath + "/max_brightness" : ""
        blockLoading: true; watchChanges: false; printErrors: false
        onLoaded: {
            const v = parseInt(blMaxFile.text().trim());
            if (Number.isFinite(v) && v > 0) root.blMax = v;
        }
    }

    Process {
        id: ddcDetect
        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            id: ddcDetectOut
            onStreamFinished: {
                const m = ddcDetectOut.text.match(/i2c-(\d+)/);
                if (m) { root.ddcBus = parseInt(m[1]); ddcRead.running = true; }
            }
        }
    }
    Process {
        id: ddcRead
        command: ["ddcutil", "--bus", root.ddcBus + "", "getvcp", "10", "--brief"]
        stdout: StdioCollector {
            id: ddcReadOut
            onStreamFinished: {
                // "VCP 10 C <current> <max>"
                const p = ddcReadOut.text.trim().split(/\s+/);
                if (p.length >= 4) root.ddcPercent = parseInt(p[3]);
            }
        }
    }

    function set(v) {
        // Floored at 1: the way back from a black panel is the widget that went dark with it.
        const p = Math.max(1, Math.min(100, Math.round(v)));
        if (root.hasInternal) {
            root.blRaw = Math.max(1, Math.round(p * root.blMax / 100));   // optimistic; sysfs confirms
        } else if (root.ddcBus >= 0) {
            root.ddcPercent = p;
        } else {
            return;
        }
        root.briPending = p;
        briDebounce.restart();
        Osd.show("brightness");
    }

    // Debounced so a scroll or drag doesn't queue writes. ddcutil is the slow one (~200ms).
    Timer {
        id: briDebounce
        interval: root.hasInternal ? 40 : 140
        onTriggered: {
            if (!root.hasInternal) {
                Quickshell.execDetached(["ddcutil", "--bus", root.ddcBus + "", "setvcp", "10", root.briPending + ""]);
                return;
            }
            if (root.hasBrightnessctl) {
                Quickshell.execDetached(["brightnessctl", "-d", root.blDevice, "-q", "set", root.briPending + "%"]);
                return;
            }
            // No brightnessctl: write the file, which works under the usual `video` group rule.
            const raw = Math.max(1, Math.round(root.briPending * root.blMax / 100));
            Quickshell.execDetached(["sh", "-c", 'printf %s "$1" > "$2"',
                                     "sh", raw + "", root.blPath + "/brightness"]);
        }
    }
}
