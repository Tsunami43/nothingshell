pragma Singleton

// Clipboard history kept by the shell itself, no cliphist/clipman/copyq: `wl-paste --watch CMD`
// runs CMD on every change with the new content on stdin, so one long-lived process feeds it all.
//
// Text only (an image would have to be spooled to disk) and memory-only for the session, on
// purpose — persisting it would put every password that crossed the clipboard into a plain file.
//
// Named Clip, not Clipboard, to stay clear of the QML/Quickshell namespaces — see SysLocale.qml.
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // [{ text, at }] — newest first.
    property var entries: []

    // Past ~1 MB it is a file paste, not something worth re-selecting from a list.
    readonly property int maxBytes: 1048576
    // The history is capped by bytes too, not just entry count: clipboardMax alone would let
    // 100 × 1 MB sit in RSS forever. Whichever limit bites first wins.
    readonly property int maxTotalBytes: 8388608
    property int usedBytes: 0

    // ASCII record separator, not a newline: clipboard content is routinely multi-line and
    // splitting on "\n" would shred every entry.
    readonly property string sep: "\x1e"

    // `wl-paste --watch` fires once with whatever is already on the clipboard the moment it
    // starts. After a pause that is precisely the content the pause existed to keep out — turning
    // the history switch back on would have recorded the password copied while it was off — so the
    // first payload of every run is dropped. At shell start it means the clipboard you arrived
    // with is not in the list until you copy something.
    property bool skipFirst: true

    Process {
        id: watcher
        running: Config.clipboardEnabled
        onRunningChanged: if (watcher.running) root.skipFirst = true
        // Password managers (KeePassXC, Bitwarden, Secret Service clients) mark a copied secret
        // with the x-kde-passwordManagerHint offer, which every one of them honours precisely so
        // that history tools skip it. Without this check the shell keeps a copied password in the
        // list for the rest of the session, one "#" away in the launcher. The offer list is re-read
        // per change rather than trusted from the payload — only the types say what this is.
        // The separator is still printed for a skipped entry, so the parser stays in sync.
        command: ["wl-paste", "--type", "text", "--watch", "sh", "-c",
                  "if wl-paste --list-types 2>/dev/null | grep -qF x-kde-passwordManagerHint; "
                  + "then cat >/dev/null; else cat; fi; printf '\\036'"]
        stdout: SplitParser {
            splitMarker: root.sep
            onRead: data => root.add(data)
        }
    }

    function add(text) {
        if (!Config.clipboardEnabled) return;
        if (root.skipFirst) { root.skipFirst = false; return; }   // the watcher's start-up echo
        if (!text || text.length === 0 || text.length > root.maxBytes) return;
        // Whitespace-only selections are almost always an accident of a drag.
        if (text.trim().length === 0) return;
        const l = root.entries.filter(e => e.text !== text);
        // Re-copying from the history re-fires the watcher, so a reused entry climbs back to
        // the top rather than being dropped as a duplicate.
        l.unshift({ text: text, at: Date.now() });
        root.trim(l);
    }

    // Drop from the oldest end until both limits hold, then publish once per copy.
    function trim(l) {
        let used = 0, cut = l.length;
        for (let i = 0; i < l.length; i++) {
            used += l[i].text.length;
            if (i >= Config.clipboardMax || used > root.maxTotalBytes) { cut = i; break; }
            if (i === l.length - 1) cut = l.length;
        }
        root.entries = cut === l.length ? l : l.slice(0, cut);
        root.usedBytes = root.entries.reduce((a, e) => a + e.text.length, 0);
    }

    function copy(text) { Quickshell.execDetached(["wl-copy", "--", text]); }
    function remove(i) {
        // Guard the miss: callers pass an indexOf() result, and splice(-1, 1) would quietly drop
        // the OLDEST entry instead of the one the user pressed Delete on.
        if (i < 0 || i >= root.entries.length) return;
        const l = root.entries.slice();
        l.splice(i, 1);
        root.entries = l;
        root.usedBytes = l.reduce((a, e) => a + e.text.length, 0);
    }
    function clear() {
        root.entries = [];
        root.usedBytes = 0;
        Quickshell.execDetached(["wl-copy", "--clear"]);
    }

    // One line fit for a list row: newlines become a pilcrow, runs of blanks collapse.
    function preview(text) {
        const s = text.replace(/\s+/g, " ").trim();
        return s.length > 120 ? s.slice(0, 120) + "…" : s;
    }
    // "3 lines · 452 characters" — what the preview had to throw away.
    function summary(text) {
        const lines = text.split("\n").length;
        const chars = text.length;
        return (lines > 1 ? lines + " lines · " : "") + chars + (chars === 1 ? " character" : " characters");
    }

    function search(query) {
        const q = (query ?? "").trim().toLowerCase();
        if (!q) return root.entries;
        return root.entries.filter(e => e.text.toLowerCase().includes(q));
    }
}
