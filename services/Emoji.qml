pragma Singleton

// Emoji dataset for the launcher ":" picker (loaded from assets/emoji.json).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var data: []
    FileView {
        path: Qt.resolvedUrl("../assets/emoji.json").toString().replace("file://", "")
        onLoaded: { try { root.data = JSON.parse(text()); } catch (e) {} }
    }
}
