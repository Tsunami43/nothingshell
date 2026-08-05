pragma Singleton

// Audio spectrum via `cava` (raw ASCII frames). The process runs only while at least one
// consumer requests it (wantMedia / wantDesktop), so it costs nothing when nothing shows it.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int bars: 44
    property var values: new Array(44).fill(0)   // 0..1 per bar

    // Set by a consumer (e.g. the dashboard media tab) to request the process.
    property bool wantMedia: false
    readonly property bool active: wantMedia

    // Resolved from this file so the path holds wherever the config tree is checked out.
    readonly property string configPath: Qt.resolvedUrl("../assets/cava.conf").toString().replace("file://", "")

    Process {
        id: proc
        running: root.active
        command: ["cava", "-p", root.configPath]
        stdout: SplitParser {
            // Each line is one frame: "b0;b1;...;b43;" with values 0..100.
            onRead: line => {
                const parts = line.split(";");
                const out = new Array(root.bars);
                for (let i = 0; i < root.bars; i++) {
                    const v = parseInt(parts[i]);
                    out[i] = isNaN(v) ? 0 : v / 100;
                }
                root.values = out;
            }
        }
    }
    // Zero the bars when stopped so a stale frame doesn't freeze on screen.
    onActiveChanged: if (!active) values = new Array(bars).fill(0)
}
