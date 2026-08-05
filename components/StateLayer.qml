// Material state layer: hover/press tint + ripple from the click point.
// The tint and the ripple are masked to the host's own rounded shape — Qt Quick's `clip` is
// always rectangular, so a growing ripple used to paint square corners over a rounded row.
// The mask is engaged only while the ripple is alive, so idle rows pay for no extra layer.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs
MouseArea {
    id: sl
    property color tint: Config.fg
    // Corners default to the host's own, so a layer dropped on a rounded card matches it without
    // repeating the numbers — and follows it when the host animates its radius. A connected-group
    // row carries different top and bottom corners, hence the two. Non-Rectangle hosts report no
    // radius and fall back to 8. Set ovRadius to force both, or either one for finer control.
    property real ovRadius: -1
    // qmllint disable missing-property
    // The host is typed as Item here, so the corner properties are read dynamically; a host
    // without them yields undefined and falls back.
    property real ovTopRadius: sl.ovRadius >= 0 ? sl.ovRadius : (sl.parent?.topLeftRadius ?? 8)
    property real ovBottomRadius: sl.ovRadius >= 0 ? sl.ovRadius : (sl.parent?.bottomLeftRadius ?? 8)
    // qmllint enable missing-property
    signal tapped(var mouse)
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => sl.tapped(mouse)

    Item {
        anchors.fill: parent
        layer.enabled: rip.opacity > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: shapeMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Rectangle {
            anchors.fill: parent
            topLeftRadius: sl.ovTopRadius; topRightRadius: sl.ovTopRadius
            bottomLeftRadius: sl.ovBottomRadius; bottomRightRadius: sl.ovBottomRadius
            color: sl.tint
            opacity: sl.pressed ? Config.pressOpacity : (sl.containsMouse ? Config.hoverOpacity : 0)
            Behavior on opacity { Effect {} }
        }
        Rectangle {
            id: rip
            radius: width / 2
            color: sl.tint
            opacity: 0
            property real px: 0
            property real py: 0
            x: px - width / 2
            y: py - height / 2
            width: 0; height: width
            Behavior on opacity { Effect {} }
        }
    }

    Item {
        id: shapeMask
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle {
            anchors.fill: parent
            topLeftRadius: sl.ovTopRadius; topRightRadius: sl.ovTopRadius
            bottomLeftRadius: sl.ovBottomRadius; bottomRightRadius: sl.ovBottomRadius
        }
    }

    NumberAnimation {
        id: ripGrow; target: rip; property: "width"
        from: 0; to: Math.max(sl.width, sl.height) * 2.4; duration: 480; easing.type: Easing.OutCubic
    }
    // Assigned imperatively, not bound: a binding on Config.rippleOpacity would outrank the
    // `rip.opacity = 0` below and the ripple would never fade out.
    onPressed: e => { rip.px = e.x; rip.py = e.y; rip.opacity = Config.rippleOpacity; ripGrow.restart(); }
    onReleased: rip.opacity = 0
    onCanceled: rip.opacity = 0
}
