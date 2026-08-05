// Colour cross-fade animation.
pragma ComponentBehavior: Bound

import QtQuick
import qs
ColorAnimation { duration: Motion.colorDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.colorCurve }
