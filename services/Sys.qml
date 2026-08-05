pragma Singleton

// System stats (CPU/RAM/disk/temp/net/uptime). Only samples while `active` is true
// (the dashboard Performance tab sets it) — no background polling otherwise.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    property real cpu: 0
    property real mem: 0
    property int  temp: 0
    property real memTotalGb: 0
    property real memUsedGb: 0
    property real disk: 0
    property real diskUsedGb: 0
    property real diskTotalGb: 0
    property real load: 0       // 1-minute load average
    property int  cores: 0      // logical CPUs, for the "load / cores" readout
    property real gpu: 0        // 0..1 (amdgpu/other via sysfs)
    property int  gpuTemp: 0
    property real vramUsedGb: 0
    property real vramTotalGb: 0
    property bool hasGpu: false
    property real down: 0
    property real up: 0
    property string uptime: ""
    property var _prev: null
    property var _prevNet: null
    property int _tick: 0

    // Drop stale deltas when it stops, so CPU/net readings are correct on reactivation.
    onActiveChanged: if (!active) { _prev = null; _prevNet = null; }

    FileView { id: statFile; path: "/proc/stat"; blockLoading: true; watchChanges: false; printErrors: false }
    FileView { id: memFile;  path: "/proc/meminfo"; blockLoading: true; watchChanges: false; printErrors: false }
    FileView { id: tempFile; path: "/sys/class/thermal/thermal_zone0/temp"; blockLoading: true; watchChanges: false; printErrors: false }
    FileView { id: netDevFile; path: "/proc/net/dev"; blockLoading: true; watchChanges: false; printErrors: false }
    FileView { id: uptimeFile; path: "/proc/uptime"; blockLoading: true; watchChanges: false; printErrors: false }
    FileView { id: loadFile; path: "/proc/loadavg"; blockLoading: true; watchChanges: false; printErrors: false }
    // Logical CPU count, read once: "0-23" (or a comma list) → 24. Sourced from sysfs rather than
    // nproc so it costs no process spawn.
    FileView {
        id: cpuPresentFile
        path: "/sys/devices/system/cpu/present"
        blockLoading: true; watchChanges: false; printErrors: false
        onLoaded: {
            let n = 0;
            for (const part of cpuPresentFile.text().trim().split(",")) {
                const r = part.split("-");
                n += r.length > 1 ? (Number(r[1]) - Number(r[0]) + 1) : 1;
            }
            if (n > 0) root.cores = n;
        }
    }

    Timer {
        interval: 2000; running: root.active; repeat: true; triggeredOnStart: true
        onTriggered: {
            statFile.reload(); memFile.reload(); tempFile.reload();

            const parts = statFile.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            if (parts.length >= 4) {
                const idle = parts[3] + (parts[4] || 0);
                const total = parts.reduce((a, b) => a + b, 0);
                if (root._prev) {
                    const dt = total - root._prev.total;
                    const di = idle - root._prev.idle;
                    root.cpu = dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : 0;
                }
                root._prev = { total: total, idle: idle };
            }

            const memText = memFile.text();   // one read, two lookups
            const mt = /MemTotal:\s+(\d+)/.exec(memText);
            const ma = /MemAvailable:\s+(\d+)/.exec(memText);
            if (mt && ma) {
                const totalKb = Number(mt[1]), availKb = Number(ma[1]);
                root.mem = 1 - availKb / totalKb;
                root.memTotalGb = totalKb / 1048576;
                root.memUsedGb = (totalKb - availKb) / 1048576;
            }

            const t = Number(tempFile.text().trim());
            if (!isNaN(t)) root.temp = Math.round(t / 1000);

            netDevFile.reload();
            let rx = 0, tx = 0;
            for (const line of netDevFile.text().split("\n")) {
                const m = line.match(/^\s*([\w-]+):\s+(.*)$/);
                if (!m || m[1] === "lo") continue;
                const f = m[2].trim().split(/\s+/).map(Number);
                rx += f[0] || 0;
                tx += f[8] || 0;
            }
            if (root._prevNet) {
                const dt = 2;
                root.down = Math.max(0, (rx - root._prevNet.rx) / dt);
                root.up   = Math.max(0, (tx - root._prevNet.tx) / dt);
            }
            root._prevNet = { rx: rx, tx: tx };

            // Every 15th tick — 30s. df is the one figure here that still needs a process, and
            // free space does not move in jumps worth a spawn every 10s.
            if (root._tick % 15 === 0) diskProc.running = true;
            root.readGpu();
            root._tick++;

            loadFile.reload();
            const la = parseFloat(loadFile.text().trim().split(/\s+/)[0]);
            if (!isNaN(la)) root.load = la;

            uptimeFile.reload();
            const up = parseFloat(uptimeFile.text().trim().split(/\s+/)[0]);
            if (!isNaN(up)) {
                const d = Math.floor(up / 86400), h = Math.floor((up % 86400) / 3600), m = Math.floor((up % 3600) / 60);
                root.uptime = (d > 0 ? d + "d " : "") + h + "h " + m + "m";
            }
        }
    }

    // Percentage plus the absolute used/total (1K blocks), so the gauge can show both.
    // Reports the filesystem holding $HOME, not /: on a split layout the root volume is a small
    // system partition whose fill level says nothing about the user's actual free space.
    Process {
        id: diskProc
        command: ["sh", "-c", "df -P \"$HOME\" | tail -1 | awk '{print $5+0, $3, $2}'"]
        stdout: StdioCollector {
            id: diskOut
            onStreamFinished: {
                const f = diskOut.text.trim().split(/\s+/).map(Number);
                if (f.length >= 3 && !isNaN(f[0])) {
                    root.disk = f[0] / 100;
                    root.diskUsedGb = f[1] / 1048576;
                    root.diskTotalGb = f[2] / 1048576;
                }
            }
        }
    }

    // GPU busy%/temp/VRAM from sysfs. The paths carry glob'd card/hwmon numbers, so a shell resolves
    // them — but ONCE, at first sample, not on every tick: the old version spawned `sh` plus four
    // `cat`s every 2 seconds for four files that never move. After this the sampling itself is
    // plain FileView reads, like the /proc ones above.
    property var gpuPaths: null
    Process {
        id: gpuFind
        command: ["sh", "-c",
            'for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r "$f" ] && { echo "b:$f"; break; }; done; ' +
            'for f in /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input; do [ -r "$f" ] && { echo "t:$f"; break; }; done; ' +
            'for f in /sys/class/drm/card*/device/mem_info_vram_used; do [ -r "$f" ] && { echo "vu:$f"; break; }; done; ' +
            'for f in /sys/class/drm/card*/device/mem_info_vram_total; do [ -r "$f" ] && { echo "vt:$f"; break; }; done']
        stdout: StdioCollector {
            id: gpuFindOut
            onStreamFinished: {
                const p = {};
                for (const line of gpuFindOut.text.split("\n")) {
                    const i = line.indexOf(":");
                    if (i > 0) p[line.slice(0, i)] = line.slice(i + 1);
                }
                root.gpuPaths = p;    // {} when there is no such GPU — still "resolved", so no re-scan
                root.readGpu();
            }
        }
    }

    // One FileView per figure, path bound to what the scan found. An empty path never loads, which
    // is exactly what a machine without amdgpu should do.
    FileView { id: gpuBusyFile; path: root.gpuPaths?.b ?? ""; blockLoading: true; watchChanges: false; printErrors: false }
    FileView { id: gpuTempFile; path: root.gpuPaths?.t ?? ""; blockLoading: true; watchChanges: false; printErrors: false }
    FileView { id: vramUsedFile; path: root.gpuPaths?.vu ?? ""; blockLoading: true; watchChanges: false; printErrors: false }
    FileView { id: vramTotalFile; path: root.gpuPaths?.vt ?? ""; blockLoading: true; watchChanges: false; printErrors: false }

    function readGpu() {
        if (root.gpuPaths === null) { gpuFind.running = true; return; }   // first sample: resolve
        if (root.gpuPaths.b) {
            gpuBusyFile.reload();
            const b = parseInt(gpuBusyFile.text().trim());
            if (Number.isFinite(b)) { root.gpu = Math.max(0, Math.min(1, b / 100)); root.hasGpu = true; }
        }
        if (root.gpuPaths.t) {
            gpuTempFile.reload();
            const t = parseInt(gpuTempFile.text().trim());
            if (Number.isFinite(t)) root.gpuTemp = Math.round(t / 1000);
        }
        if (root.gpuPaths.vu) {
            vramUsedFile.reload();
            const vu = parseInt(vramUsedFile.text().trim());
            if (Number.isFinite(vu)) root.vramUsedGb = vu / 1073741824;
        }
        if (root.gpuPaths.vt) {
            vramTotalFile.reload();
            const vt = parseInt(vramTotalFile.text().trim());
            if (Number.isFinite(vt)) root.vramTotalGb = vt / 1073741824;
        }
    }
}
