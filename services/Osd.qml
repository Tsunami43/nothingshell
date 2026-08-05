pragma Singleton

// On-screen display state: a brief volume/brightness bar, plus a "now playing" media pop.
import QtQuick
import Quickshell

Singleton {
    id: root

    property string kind: ""     // "volume" | "brightness" | ""
    property bool ready: false   // suppresses OSDs during the first ~1.2s (startup value reads)
    Timer { id: hideTimer; interval: 1500; onTriggered: root.kind = "" }
    Timer { interval: 1200; running: true; onTriggered: root.ready = true }
    function show(k) { if (!ready) return; root.kind = k; hideTimer.restart(); }

    property bool media: false
    Timer { id: mediaTimer; interval: 3500; onTriggered: root.media = false }
    function showMedia() { if (!ready) return; root.media = true; mediaTimer.restart(); }
}
