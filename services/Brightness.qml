pragma Singleton

// Screen brightness via DDC/CI (external monitor; no laptop backlight here).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int brightness: -1
    property int ddcBus: -1
    property int briPending: 0
    readonly property bool available: ddcBus >= 0 && brightness >= 0

    Process {
        running: true
        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            id: ddcDetectOut
            onStreamFinished: {
                const m = ddcDetectOut.text.match(/i2c-(\d+)/);
                if (m) { root.ddcBus = parseInt(m[1]); briRead.running = true; }
            }
        }
    }
    Process {
        id: briRead
        command: ["ddcutil", "--bus", root.ddcBus + "", "getvcp", "10", "--brief"]
        stdout: StdioCollector {
            id: briReadOut
            onStreamFinished: {
                // "VCP 10 C <current> <max>"
                const p = briReadOut.text.trim().split(/\s+/);
                if (p.length >= 4) root.brightness = parseInt(p[3]);
            }
        }
    }
    function set(v) {
        if (root.ddcBus < 0) return;
        root.brightness = Math.max(0, Math.min(100, Math.round(v)));   // optimistic
        root.briPending = root.brightness;
        briDebounce.restart();
        Osd.show("brightness");
    }
    // ddcutil writes are slow (~200ms); debounce so a scroll/drag doesn't queue dozens of calls.
    Timer {
        id: briDebounce
        interval: 140
        onTriggered: Quickshell.execDetached(["ddcutil", "--bus", root.ddcBus + "", "setvcp", "10", root.briPending + ""])
    }
}
