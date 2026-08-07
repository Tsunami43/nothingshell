pragma Singleton

// Shell-wide UI toggles (launcher/settings/capture visibility, keep-awake idle inhibitor).
import Quickshell
import qs

Singleton {
    id: root
    property bool launcherVisible: false
    // Preloaded into the launcher's field on the next open, so a keybind can drop straight into
    // a mode: ">", ">theme", ":" … Consumed and cleared by the launcher.
    property string launcherQuery: ""
    property bool sessionVisible: false   // power popout in the bar (hover, or IPC; no default bind)
    property bool settingsVisible: false  // the settings window (modules/Settings.qml)
    // Page to land on, by id (see modules/settings/PageRegistry.qml). Empty resumes the last one.
    property string settingsPage: ""
    property bool keepAwake: false   // idle inhibitor (see the bar's IdleInhibitor + toggle)
    property bool captureVisible: false   // screenshot/recording panel (modules/CapturePanel.qml)
    property string captureScreen: ""     // which output owns it; only that one takes keyboard focus
    // The hover-opened surfaces, as flags a keybind can reach over IPC. Each panel keeps its
    // flag in step both ways. Global rather than per-output, like launcherVisible.
    property bool dashboardVisible: false
    property bool overviewVisible: false
    property string barPopout: ""         // "volume", "network", … see modules/Bar.qml
    // Open settings, optionally deep-linking to a page. Settings consumes settingsPage on show.
    function openSettings(pageId) {
        root.settingsPage = pageId ?? "";
        root.settingsVisible = true;
    }
    function openLauncher(query) {
        root.launcherQuery = query ?? "";
        root.launcherVisible = true;
    }

    // The capture panel and the launcher share one PopoutState bulge slot, so they can never
    // both be open.
    onCaptureVisibleChanged: if (root.captureVisible) root.launcherVisible = false;
    onLauncherVisibleChanged: if (root.launcherVisible) root.captureVisible = false;

    // Seconds → m:ss.
    function fmtTime(s) {
        if (!s || s < 0) s = 0;
        const m = Math.floor(s / 60), sec = Math.floor(s % 60);
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }
    // "6.4 / 15.5 GB" — the absolute pair behind a percentage gauge. Empty when the total is
    // unknown, so a gauge without figures shows nothing.
    function fmtPair(used, total, unit, digits) {
        if (!total || total <= 0) return "";
        const d = digits === undefined ? 1 : digits;
        return used.toFixed(d) + " / " + total.toFixed(d) + (unit ? " " + unit : "");
    }
    // Human-readable bytes/second.
    function fmtSpeed(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s";
        if (bps >= 1024)    return (bps / 1024).toFixed(0) + " KB/s";
        return Math.round(bps) + " B/s";
    }
}
