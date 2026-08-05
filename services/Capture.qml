pragma Singleton

// Screenshots (grim) and screen recording (gpu-screen-recorder), with one shared region picker
// (slurp) and one shared "get the shell out of the frame first" step.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

Singleton {
    id: root

    // --- Observable state ---
    property string state: "idle"          // idle | recording | paused
    readonly property bool active: root.state !== "idle"
    // Stop has been asked for, but the recorder is still muxing. Separate from `state`, which may
    // only go idle once the process is really gone.
    property bool stopping: false
    readonly property bool paused: root.state === "paused"
    property int elapsed: 0                // seconds, frozen while paused
    property string source: ""             // what the running recording captures: screen | region
    property string lastFile: ""
    property string lastError: ""
    property bool busy: false              // a screenshot is in flight (guards a held keybind)

    // True while the capture panel must not paint. Set just before a capture fires and cleared
    // once the external tool has been launched.
    property bool hidingForCapture: false

    // PID of the recorder. Read back after launching so pause/stop can signal that exact process
    // instead of pkill-ing every gpu-screen-recorder on the system. When debugging by hand, note
    // that `pkill -x gpu-screen-recorder` never matches either — the kernel truncates the process
    // name at 15 characters. Use `kill -INT $(pidof -x gpu-screen-recorder)`.
    property int recPid: 0

    readonly property string elapsedText: {
        const s = root.elapsed, h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
        const pad = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : m + ":" + pad(sec);
    }

    // A live summary of the current settings, for the panel's chip and the bar popout.
    readonly property string recSummary: [Config.recFormat, Config.recFps + " fps",
        ({ none: "no audio", desktop: "system", mic: "mic", both: "system+mic" })[Config.recAudio]].join(" · ")
    readonly property string shotSummary: [Config.shotSave ? "png" : "clipboard only",
        Config.shotCopy ? "copy" : "no copy", Config.shotCursor ? "cursor" : "no cursor"].join(" · ")

    // --- Elapsed time ---
    // Wall-clock arithmetic, not tick counting: a throttled shell drops timer ticks and would
    // undercount a long recording by minutes.
    property double startedAt: 0
    property double pausedMs: 0
    property double pausedAt: 0
    function tick() { root.elapsed = Math.max(0, Math.floor((Date.now() - root.startedAt - root.pausedMs) / 1000)); }
    // 500ms so the displayed second never visibly lags a whole tick behind.
    Timer { interval: 500; repeat: true; running: root.state === "recording"; onTriggered: root.tick() }

    // Where captures land: what Settings holds, or the XDG media directory when it holds nothing.
    readonly property string recTarget: Config.recDir || (Paths.videos + "/Recordings")
    readonly property string shotTarget: Config.shotDir || (Paths.pictures + "/Screenshots")

    function stamp() { return Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss"); }
    function monitor() { return Hyprland.focusedMonitor?.name ?? ""; }
    // slurp wants #rrggbbaa; QML colors stringify as #aarrggbb, so build it by component.
    function hexa(c, a) {
        const f = x => ("0" + Math.round(x * 255).toString(16)).slice(-2);
        return "#" + f(c.r) + f(c.g) + f(c.b) + f(a === undefined ? c.a : a);
    }

    // --- Region picking (slurp) ---
    // slurp knows the geometry, so both capture paths funnel through here. Cancelling leaves no
    // output — hand back null and give up silently, where the old `grim -g "$(slurp)"` ran
    // `grim -g ""`. Validating the four numbers avoids racing the exit code against stdout.
    property var regionCb: null
    readonly property bool picking: slurpProc.running
    function pickRegion(cb) {
        root.regionCb = cb;
        // The dim has to be heavy: Config.scrim (near-black at 38%) is tuned for a panel backdrop
        // and vanishes over an already dark desktop, so the picker looked like nothing happened.
        //
        // stdin MUST be /dev/null. slurp reads predefined rectangles from stdin whenever it is not
        // a TTY, so the pipe a Process hands it blocked the read forever and the layer surface
        // never mapped. stdinEnabled: false doesn't help — the pipe is still there. exec keeps the
        // shell from lingering, so `picking` still tracks slurp itself.
        slurpProc.command = ["sh", "-c", 'exec "$@" </dev/null', "sh", "slurp", "-d", "-w", "3",
            "-b", root.hexa(Config.shadow, Config.lightMode ? 0.5 : 0.6),
            "-c", root.hexa(Config.accent, 1),
            "-s", root.hexa(Config.accent, 0.2),
            "-B", root.hexa(Config.container, 1),
            "-f", "%x %y %w %h"];
        slurpProc.running = true;
    }
    // SIGTERM rather than clearing `running`: the collector still fires with no output, so the
    // pending callback is told the pick was cancelled and nothing is left half-started.
    function cancelPick() { if (slurpProc.running) slurpProc.signal(15); }
    Process {
        id: slurpProc
        stdout: StdioCollector {
            id: slurpOut
            onStreamFinished: {
                const p = slurpOut.text.trim().split(/\s+/).map(Number);
                const ok = p.length === 4 && p.every(n => Number.isFinite(n)) && p[2] > 0 && p[3] > 0;
                const cb = root.regionCb;
                root.regionCb = null;
                root.hidingForCapture = false;
                if (cb) cb(ok ? { x: p[0], y: p[1], w: p[2], h: p[3] } : null);
            }
        }
    }

    // --- Getting the shell out of the shot ---
    // The panel would land in the shot, and a normal close (460ms) would be caught mid-slide, so
    // the capture path unpaints it and collapses the bulge in the same frame (anim=false).
    property var settleCb: null
    // One slot, so a second capture asked for inside the settle window would overwrite the first
    // callback and the original capture would simply never fire. `busy` covers screenshot-over-
    // screenshot; this covers the mixed case (start a recording, hit the screenshot key 100ms later).
    function hideThenRun(cb, delayMs) {
        if (root.settleCb !== null) return false;
        root.settleCb = cb;
        root.hidingForCapture = true;
        Shell.captureVisible = false;
        PopoutState.setBox(0, 0, 0, 0, "capture", false, 0.5, 1.0);
        PopoutState.clear("capture");
        settleTimer.interval = delayMs;
        settleTimer.restart();
        return true;
    }
    // A layer-surface commit, the compositor's repaint and the next scanout are not synchronous
    // with a QML property write; below ~100ms the panel starts showing up in full-screen shots.
    Timer {
        id: settleTimer
        onTriggered: { const cb = root.settleCb; root.settleCb = null; if (cb) cb(); }
    }

    // --- Screenshots (grim) ---
    function screenshot(src) {
        // `picking` too: slurp is already asking the user for a rectangle, and a second picker
        // would sit invisibly behind the first with no way to reach it.
        if (root.busy || root.picking) return;
        root.busy = true;
        // 60ms is enough before slurp (the drag itself buys seconds); a bare grim needs the full
        // settle because nothing else stands between the hide and the capture.
        // Hand `busy` back if the settle slot is taken, or the shot key would be dead until restart.
        if (!root.hideThenRun(() => {
            if (src !== "region") { root.grab(null); return; }
            root.pickRegion(r => {
                if (r) root.grab(r);
                else root.busy = false;
            });
        }, src === "region" ? 60 : 150))
            root.busy = false;
    }

    property string shotFile: ""
    function grab(region) {
        root.hidingForCapture = false;
        const dir = Config.shotSave ? root.absDir(root.shotTarget) : "/tmp";
        root.shotFile = dir + "/shot_" + root.stamp() + ".png";
        const args = ["grim"];
        if (Config.shotCursor) args.push("-c");
        if (region) args.push("-g", region.x + "," + region.y + " " + region.w + "x" + region.h);
        else if (root.monitor()) args.push("-o", root.monitor());   // bare grim stitches ALL outputs together
        args.push(root.shotFile);
        root.mkdirThen(dir, () => { grimProc.command = args; grimProc.running = true; });
    }
    Process {
        id: grimProc
        stderr: StdioCollector { id: grimErr }
        onExited: code => {
            root.busy = false;
            if (code !== 0) { root.fail("Screenshot failed", grimErr.text.trim() || "grim exited " + code); return; }
            root.lastFile = root.shotFile;
            // The path goes in as $1 and is never interpolated into the script; a shell is only
            // needed for the stdin redirect (same idiom as Wallpaper.qml).
            if (Config.shotCopy)
                Quickshell.execDetached(["sh", "-c",
                    'wl-copy -t image/png < "$1"' + (Config.shotSave ? "" : '; rm -f "$1"'), "sh", root.shotFile]);
            // image-path (not -i, which is the app icon) is what Notifs exposes as `image`, so the
            // shell's own toast renders it as a thumbnail.
            Quickshell.execDetached(["notify-send", "-a", "Capture", "-t", "4000",
                "-h", "string:image-path:" + root.shotFile,
                Config.shotSave ? "Screenshot saved" : "Screenshot copied",
                Config.shotSave ? root.shotFile.split("/").pop() : ""]);
        }
    }

    // --- Recording (gpu-screen-recorder) ---
    function record(src) {
        if (root.active || root.busy || root.picking) return;
        root.hideThenRun(() => {
            if (src !== "region") { root.launch(src, null); return; }
            root.pickRegion(r => { if (r) root.launch(src, r); });
        }, src === "region" ? 60 : 150);
    }

    // Also stamps lastFile: the detached recorder never tells us where it wrote, so the name has
    // to be remembered at launch time.
    function recArgv(region) {
        const ext = Config.recFormat;
        const a = ["gpu-screen-recorder"];
        if (region) a.push("-w", "region", "-region", region.w + "x" + region.h + "+" + region.x + "+" + region.y);
        else a.push("-w", root.monitor() || "screen");
        a.push("-c", ext, "-f", String(Config.recFps), "-q", Config.recQuality,
               "-cursor", Config.recCursor ? "yes" : "no");
        // gsr defaults to variable frame rate, which most editors mishandle outside matroska.
        if (ext !== "mkv") a.push("-fm", "cfr");
        // webm needs VP8/VP9, and VAAPI VP9 encode is not a given on this GPU.
        if (ext === "webm") a.push("-k", "vp9", "-fallback-cpu-encoding", "yes");
        const audio = { desktop: "default_output", mic: "default_input",
                        both: "default_output|default_input" }[Config.recAudio];   // '|' merges into one track
        if (audio) a.push("-a", audio);
        root.lastFile = root.absDir(root.recTarget) + "/rec_" + root.stamp() + "." + ext;
        a.push("-o", root.lastFile);
        return a;
    }

    // Detached, not a child Process: the shell reloads its QML on every file change and would
    // kill a child mid-recording. stderr is teed to a log so a failed launch still has a reason.
    readonly property string recLog: Paths.captureLog
    function launch(src, region) {
        root.hidingForCapture = false;
        const argv = root.recArgv(region);
        root.mkdirThen(root.absDir(root.recTarget), () => {
            root.lastError = "";
            root.stopping = false;
            root.source = src;
            root.startedAt = Date.now();
            root.pausedMs = 0;
            root.pausedAt = 0;
            root.elapsed = 0;
            root.state = "recording";
            Quickshell.execDetached(["sh", "-c", 'exec "$@" 2>"$0"', root.recLog].concat(argv));
            watcher.running = true;
        });
    }

    // One process, two jobs: hand back the recorder's PID, then block until it is gone. The sleep
    // lets gsr appear; its exit is the poll-free signal that recording ended, even from a kill.
    Process {
        id: watcher
        command: ["sh", "-c",
            'sleep 0.8; pid=$(pidof -x gpu-screen-recorder); pid=${pid%% *}; ' +
            '[ -n "$pid" ] || exit 1; echo "$pid"; while kill -0 "$pid" 2>/dev/null; do sleep 0.15; done']
        stdout: SplitParser { onRead: line => root.recPid = parseInt(line.trim()) || 0 }
        onExited: code => {
            const failedToStart = code !== 0 && root.elapsed < 1;
            const path = root.lastFile;
            const took = root.elapsedText;
            root.state = "idle";
            root.stopping = false;
            root.recPid = 0;
            root.source = "";
            root.startedAt = 0;
            root.pausedMs = 0;
            root.pausedAt = 0;
            root.elapsed = 0;
            if (failedToStart) { root.wantErr = true; errLog.reload(); return; }
            Quickshell.execDetached(["notify-send", "-a", "Capture", "-t", "4000",
                "Recording saved", path.split("/").pop() + " — " + took]);
            if (Config.recCopyPath) Quickshell.clipboardText = path;
        }
    }
    // Only read after a failed launch: why gsr refused (no encoder, bad monitor) is the one thing
    // the detached path can't return. The flag stops a stale log at shell start reporting it.
    property bool wantErr: false
    FileView {
        id: errLog
        path: root.recLog
        printErrors: false
        onLoaded: {
            if (!root.wantErr) return;
            root.wantErr = false;
            const lines = errLog.text().trim().split("\n").filter(Boolean);
            root.fail("Recording failed", lines.length ? lines[lines.length - 1] : "gpu-screen-recorder did not start");
        }
    }

    function pause() {
        if (root.state !== "recording" || !root.recPid) return;
        root.tick();                                   // snap to the exact pause instant first
        root.pausedAt = Date.now();
        root.state = "paused";
        Quickshell.execDetached(["kill", "-SIGUSR2", String(root.recPid)]);
    }
    function resume() {
        if (root.state !== "paused" || !root.recPid) return;
        root.pausedMs += Date.now() - root.pausedAt;
        root.pausedAt = 0;
        root.state = "recording";
        Quickshell.execDetached(["kill", "-SIGUSR2", String(root.recPid)]);
    }
    function togglePause() { root.paused ? root.resume() : root.pause(); }
    function stop() {
        // `stopping` too: a second SIGINT while gsr is writing the file out cuts the mux short and
        // leaves a broken recording, and the stop buttons elsewhere stay live during that window.
        if (!root.active || !root.recPid || root.stopping) return;
        // SIGINT only asks; gsr then muxes the file, which on a long recording takes seconds, and
        // `state` cannot go idle until it actually exits (that is what stamps the saved file in the
        // notification). The UI must not sit there in the meantime, so the intent is published
        // separately — the bar drops its popout on this, not on the process finally dying.
        root.stopping = true;
        Quickshell.execDetached(["kill", "-SIGINT", String(root.recPid)]);   // stop and mux
    }
    function toggle() { root.active ? root.stop() : root.record(Config.capSource); }

    // Output directories are typed by hand in Settings, so "~/Videos/Recordings", "Videos/Recordings"
    // and "/mnt/media/clips" all have to land somewhere sensible. Anything that isn't already
    // absolute is resolved against $HOME rather than left to the process's inherited cwd — that cwd
    // is why a bare "Pictures/Screenshots" appeared to work while nothing else did.
    function absDir(p) {
        const home = Paths.home;
        const s = (p ?? "").trim().replace(/\/+$/, "");
        if (s === "" || s === "~") return home;
        if (s.startsWith("~/")) return home + s.slice(1);
        if (s.startsWith("/")) return s;
        return home + "/" + s;
    }

    // The form a path is STORED and SHOWN in: absolute, with $HOME folded back to "~". Settings
    // writes every directory field through this, so "Pictures", "~/Pictures" and "/home/me/Pictures"
    // all end up on disk as the same string — the two capture fields can't drift into different
    // styles the way they had.
    function niceDir(p) {
        const home = Paths.home;
        const a = root.absDir(p);
        if (a === home) return "~";
        return a.startsWith(home + "/") ? "~" + a.slice(home.length) : a;
    }

    // mkdir -p before every capture: neither grim nor gsr creates its output dir, and both fail
    // opaquely without it.
    property var mkdirCb: null
    property string mkdirDir: ""
    function mkdirThen(dir, cb) {
        root.mkdirCb = cb; root.mkdirDir = dir;
        mkdirProc.command = ["mkdir", "-p", dir]; mkdirProc.running = true;
    }
    Process {
        id: mkdirProc
        onExited: code => {
            const cb = root.mkdirCb;
            root.mkdirCb = null;
            // Name the directory: the usual cause is a path typed into Settings that resolves
            // somewhere unwritable, and "cannot create the output directory" alone never showed which.
            if (code !== 0) { root.busy = false; root.fail("Capture failed", "cannot create " + root.mkdirDir); return; }
            if (cb) cb();
        }
    }

    function fail(title, msg) {
        root.lastError = msg;
        Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Capture", title, msg]);
    }

    // Adopt a recorder that outlived a restart or came from a terminal, recovering elapsed time
    // from its start time. Pause state isn't observable, so it is assumed to be running.
    Component.onCompleted: adoptProc.running = true
    Process {
        id: adoptProc
        command: ["sh", "-c", 'pid=$(pidof -x gpu-screen-recorder); pid=${pid%% *}; ' +
                              '[ -n "$pid" ] && ps -o etimes= -p "$pid" || true']
        stdout: StdioCollector {
            id: adoptOut
            onStreamFinished: {
                const secs = parseInt(adoptOut.text.trim());
                if (!Number.isFinite(secs)) return;
                root.startedAt = Date.now() - secs * 1000;
                root.pausedMs = 0;
                root.pausedAt = 0;
                root.state = "recording";
                root.tick();
                watcher.running = true;
            }
        }
    }

    IpcHandler {
        target: "capture"
        // Open the capture panel on whichever monitor has focus. A region pick still waiting for
        // a rectangle is cancelled first, so this keybind is always a way back out.
        function panel(): void {
            if (root.picking) { root.cancelPick(); return; }
            Shell.captureScreen = root.monitor();
            Shell.captureVisible = !Shell.captureVisible;
        }
        function shot(src: string): void { root.screenshot(src === "screen" ? "screen" : "region"); }
        function record(src: string): void { root.record(src === "screen" ? "screen" : "region"); }
        function pause(): void { root.togglePause(); }
        function stop(): void { root.stop(); }
        function toggle(): void { root.toggle(); }
        function status(): string { return root.state + (root.picking ? " (picking)" : "") + (root.busy ? " (busy)" : ""); }
    }
}
