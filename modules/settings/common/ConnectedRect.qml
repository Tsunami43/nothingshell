// Rounded container row for the settings surfaces. `first`/`last` pick large vs small
// corner radii so vertically-stacked rows fuse into one connected group (M3 style).
pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.components
Rectangle {
    property bool first: true
    property bool last: true
    property real bigRadius: 20
    property real smallRadius: 6
    color: Config.container
    topLeftRadius: first ? bigRadius : smallRadius
    topRightRadius: first ? bigRadius : smallRadius
    bottomLeftRadius: last ? bigRadius : smallRadius
    bottomRightRadius: last ? bigRadius : smallRadius
    Behavior on color { ColorAnim {} }
}
