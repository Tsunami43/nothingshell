pragma Singleton

// Notification server + transient toast queue. `suppress` (set from the shell when a
// fullscreen window is active) blocks popups while still tracking them for the sidebar list.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

Singleton {
    id: root

    property bool suppress: false

    // Transient toast queue (separate from the persistent sidebar list).
    property alias toasts: toastModel
    ListModel { id: toastModel }
    property int toastSeq: 0

    readonly property NotificationServer server: notifServer

    // Every app that has sent a notification this session — the roster the settings page offers
    // for per-app muting. Nothing is remembered about an app that has never sent one.
    readonly property var apps: {
        const seen = {};
        for (const n of (notifServer.trackedNotifications?.values ?? []))
            if (n.appName) seen[n.appName] = true;
        return Object.keys(seen).sort((a, b) => a.localeCompare(b));
    }
    function muted(app) { return (Config.notifMuted ?? []).indexOf(app) >= 0; }
    function setMuted(app, on) {
        const l = (Config.notifMuted ?? []).slice();
        const i = l.indexOf(app);
        if (on && i < 0) l.push(app);
        else if (!on && i >= 0) l.splice(i, 1);
        else return;
        Config.notifMuted = l;
    }

    // --- Icons ---
    // The picture the app sent (Telegram ships the sender's photo as image-data, the capture
    // service its screenshot), else the app's own icon, else the one its desktop entry declares.
    // Empty when it offers none of the three — the caller draws glyph() instead.
    function art(n) {
        if (!n) return "";
        if (n.image) return n.image;
        if (n.appIcon) return Quickshell.iconPath(n.appIcon, true);
        const entry = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : null;
        return entry?.icon ? Quickshell.iconPath(entry.icon, true) : "";
    }
    // Mark for a notification with no art of its own. The shell's own capture notifications are the
    // common case: a screenshot carries its thumbnail, but a finished recording has no still to
    // show and a failure has nothing at all, so both would land on the generic bell.
    function glyph(appName, summary) {
        if (appName === "Capture") {
            const s = summary ?? "";
            if (s.startsWith("Recording")) return "videocam";
            if (s.startsWith("Screenshot")) return "photo_camera";
            return "screenshot_monitor";   // "Capture failed"
        }
        return "notifications";
    }

    // A body about to be rendered as Markdown, with every image reference taken out:
    // `![alt](url)` and the reference form both make Qt fetch the url the moment the text is
    // laid out, which turns any notification into a read receipt for whoever sent it. Inline
    // styling and links survive — a link is at least a deliberate click (see Toasts.qml).
    function safeBody(text) {
        return (text ?? "")
            .replace(/!\[[^\]]*\]\([^)]*\)/g, "")     // ![alt](url)
            .replace(/!\[[^\]]*\]\[[^\]]*\]/g, "")    // ![alt][ref]
            .replace(/^\s*\[[^\]]*\]:\s*\S+.*$/gm, ""); // the [ref]: url definition line
    }

    // How many notifications stay in the dashboard's list. Nothing expires them on its own —
    // `tracked` keeps a notification alive until it is dismissed — so an app in a crash loop
    // would grow the list, and the delegates behind it, for as long as the session lasts.
    readonly property int maxTracked: 100
    function trimTracked() {
        // Snapshot first: dismiss() removes from the very list being walked, so iterating `values`
        // live would skip every other entry.
        const all = (notifServer.trackedNotifications?.values ?? []).slice();
        if (all.length <= root.maxTracked) return;
        // `values` is oldest-first; drop from that end until the cap holds. expire(), not
        // dismiss(): the sender is told the notification timed out, which is what happened —
        // dismiss() would claim the user closed one they were never shown.
        for (let i = 0; i < all.length - root.maxTracked; i++) all[i].expire();
    }

    function removeToast(key) {
        for (let i = 0; i < toastModel.count; i++)
            if (toastModel.get(i).key === key) { toastModel.remove(i); return; }
    }

    NotificationServer {
        id: notifServer
        keepOnReload: false
        bodySupported: true
        imageSupported: true
        actionsSupported: true
        onNotification: n => {
            n.tracked = true;   // keep it in the sidebar list
            root.trimTracked();
            // DND, fullscreen/game mode or a muted app: no popup, but still tracked above, so the
            // dashboard's list stays complete either way.
            if (Config.dnd || root.suppress || root.muted(n.appName ?? "")) return;
            toastModel.insert(0, {
                key: ++root.toastSeq,
                summary: n.summary ?? "",
                body: n.body ?? "",
                appName: n.appName ?? "",
                image: n.image ?? "",
                urgency: n.urgency ?? 1,
                notif: n
            });
            while (toastModel.count > 1) toastModel.remove(toastModel.count - 1);   // show one at a time (full list lives in the dashboard)
        }
    }
}
