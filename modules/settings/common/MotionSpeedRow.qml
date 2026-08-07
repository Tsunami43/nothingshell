// The animation-speed slider, offered by both Appearance and Shell.
// Stored as a duration multiplier, shown as speed. Zero means instant, not merely quick.
pragma ComponentBehavior: Bound

import QtQuick
import qs

SliderRow {
    icon: "speed"
    label: "Animation speed"
    value: (2.0 - Config.motionScale) / 2.0
    valueText: Config.motionScale === 0 ? "Off — instant"
             : (Config.motionScale === 1 ? "Normal" : (1 / Config.motionScale).toFixed(2) + "×")
    onMoved: v => Config.motionScale = Math.round((2.0 - v * 2.0) * 20) / 20
}
