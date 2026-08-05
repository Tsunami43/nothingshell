// Enum-driven animation: choose a motion Type and it pulls the matching duration
// and easing curve from the Motion singleton, so every new Behavior/Transition
// shares the shell's tuned curves. For colour transitions use ColorAnim instead.
//
//   Behavior on x { Anim { type: Anim.Spatial } }
//   Behavior on opacity { Anim { type: Anim.Effect } }
pragma ComponentBehavior: Bound

import QtQuick
import qs

NumberAnimation {
    enum Type { Spatial, SpatialFast, Effect }

    property int type: Anim.Spatial

    duration: type === Anim.SpatialFast ? Motion.spatialFastDur
            : type === Anim.Effect ? Motion.effectDur
            : Motion.spatialDur
    easing.type: Easing.BezierSpline
    easing.bezierCurve: type === Anim.SpatialFast ? Motion.spatialFastCurve
                      : type === Anim.Effect ? Motion.effectCurve
                      : Motion.spatialCurve
}
