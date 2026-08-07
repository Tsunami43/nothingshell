pragma Singleton

// Easing curves + durations shared by every animation primitive (Spatial / SpatialFast /
// Effect / ColorAnim) and any new Behavior. The shell's whole "feel" is tuned here;
// `scale` speeds all of it up or down at once (1 = normal, <1 = faster).
import QtQuick
import Quickshell
import qs

Singleton {
    id: root

    // Written by Settings > Shell, pushed down by Power on battery. Zero means instant.
    property real scale: Config.motionScale

    // --- Easing curves (cubic-bézier control points) ---
    // Springy overshoot for movement/size/position (panel slides, indicators).
    readonly property var spatialCurve: [0.38, 1.21, 0.22, 1, 1, 1]
    // Stronger, snappier overshoot for small fast moves (bar indicator, dots).
    readonly property var spatialFastCurve: [0.42, 1.67, 0.21, 0.9, 1, 1]
    // Non-overshoot ease for opacity/fades/slider fills.
    readonly property var effectCurve: [0.34, 0.8, 0.34, 1, 1, 1]
    // Colour cross-fades (theme/state tint changes).
    readonly property var colorCurve: [0.34, 0.88, 0.34, 1, 1, 1]

    // --- Base durations (ms), before `scale` ---
    // Against the usual budget: 200-300ms for a panel, 100-150 for a small element, never over 400.
    readonly property int spatialMs: 380
    readonly property int spatialFastMs: 200
    readonly property int effectMs: 200
    readonly property int colorMs: 280

    // --- Scaled durations — what the primitives actually consume ---
    readonly property int spatialDur: Math.round(spatialMs * scale)
    readonly property int spatialFastDur: Math.round(spatialFastMs * scale)
    readonly property int effectDur: Math.round(effectMs * scale)
    readonly property int colorDur: Math.round(colorMs * scale)
}
