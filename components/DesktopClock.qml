// Large clock drawn on the wallpaper (behind windows). A soft shadow keeps it legible
// over any wallpaper. Only hh:mm + the date are shown, so it ticks once a MINUTE.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs

Item {
    id: root
    property var now: new Date()
    // Aligned to the wall clock rather than repeating every 60s, so the display flips at :00 and
    // not at whatever second the shell happened to start. The cost is not the timer but what it
    // drags behind it: this Column is layered with a MultiEffect shadow, so every tick re-renders
    // 100px type into an FBO and runs a blur pass — once a second that was 60x more often than
    // anything on screen could change, forever, on every output, even under a full-screen window.
    Timer {
        id: minuteTick
        interval: 60000 - (Date.now() % 60000)
        running: true
        onTriggered: {
            root.now = new Date();
            minuteTick.interval = 60000 - (Date.now() % 60000);
            minuteTick.restart();
        }
    }

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        spacing: 0
        layer.enabled: true
        // textHalo, not shadow: on a light theme this is dark text on a bright wallpaper, and
        // a dark shadow behind it does nothing. The halo inverts with the mode instead.
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Config.textHalo
            shadowOpacity: Config.lightMode ? 0.65 : 0.5
            shadowBlur: 0.9
            shadowVerticalOffset: Config.lightMode ? 0 : 2
        }
        Text {
            text: Qt.formatDateTime(root.now, "hh:mm")
            color: Config.fg
            font.family: Config.textFont; font.pixelSize: 100; font.bold: true
        }
        Text {
            x: 6
            text: Qt.formatDateTime(root.now, "dddd, d MMMM")
            color: Config.accent
            font.family: Config.textFont; font.pixelSize: 24; font.bold: true
        }
    }
}
