pragma ComponentBehavior: Bound

// Audio spectrum bars driven by the Cava service. Bottom-anchored, evenly spaced.
import QtQuick
import qs
import qs.services

Item {
    id: root
    property color barColor: Config.accent
    property real gap: 2
    property real minFrac: 0.015   // idle floor so a thin baseline stays visible
    readonly property int count: Cava.bars
    readonly property real barW: (width - (count - 1) * gap) / count

    Repeater {
        model: root.count
        Rectangle {
            id: bar
            required property int index
            x: index * (root.barW + root.gap)
            width: root.barW
            anchors.bottom: parent.bottom
            radius: Math.min(width / 2, 3)
            color: root.barColor
            height: Math.max(root.height * root.minFrac, root.height * (Cava.values[bar.index] ?? 0))
            // No Behavior here on purpose: cava.conf runs at 60 fps, so a 110ms easing was being
            // restarted on all 44 bars every frame — 44 animations perpetually in flight, smoothing
            // a signal that already arrives faster than the display refreshes. cava smooths its own
            // output (noise_reduction = 45 in cava.conf); this just draws what it sends.
        }
    }
}
