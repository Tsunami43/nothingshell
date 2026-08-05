// Soft Material drop shadow for a rounded rectangle. Place as a child of the target
// with `anchors.fill: parent; radius: parent.radius; z: -1` — the blur peeks out behind it.
import QtQuick
import QtQuick.Effects
import qs

RectangularShadow {
    property int level: 2
    readonly property int lv: Math.max(0, Math.min(5, level))
    property real dp: [0, 1, 3, 6, 8, 12][lv]
    // Opacity rises with the tier rather than sitting flat at 0.55, and is scaled by the
    // theme: a light palette cannot carry a dark theme's shadow weight without looking grubby.
    readonly property real baseA: [0, 0.30, 0.38, 0.46, 0.52, 0.55][lv]

    color: Qt.rgba(Config.shadow.r, Config.shadow.g, Config.shadow.b, baseA * Config.shadowStrength)
    blur: Math.pow(dp * 5, 0.7)
    spread: -dp * 0.3 + Math.pow(dp * 0.1, 2)
    offset.y: dp / 2

    Behavior on dp { Effect {} }
    Behavior on color { ColorAnim {} }
}
