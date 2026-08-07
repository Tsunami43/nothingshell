// Screen frame: the bar plus three thin borders as one surface, coves where they meet.
// Two implementations, picked by services/Power.qml: the SDF shader, or plain rects on battery.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    id: frame
    required property var modelData
    property bool suppressed: false
    property int barWidth: 56
    // Shared, so the flat surface lands on the same geometry as the shader.
    readonly property real borderT: 8    // top/right/bottom border thickness
    readonly property real holeR: 20     // content-hole and popout corner radius
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // Keep the surface mapped across fullscreen toggles; unmap→remap is unreliable (see Bar.qml).
    visible: true
    exclusionMode: ExclusionMode.Ignore   // span the whole output; coords = real screen
    WlrLayershell.layer: WlrLayer.Top
    mask: Region {}   // clicks pass through; the bar window handles bar input

    // One popout slot as a plain plate — the flat frame's answer to a bulge.
    component Plate: Rectangle {
        id: plate
        required property vector4d box
        // Size eases from the same anchor the shader uses, so a popout still grows out of the border.
        property vector2d anchor: Qt.vector2d(0, 0)
        property bool eased: true
        // Gated on the animating width: clearing a slot zeroes the box at once.
        visible: plate.width > 0.5
        width: plate.box.z
        height: plate.box.w
        x: plate.box.x + (plate.box.z - plate.width) * plate.anchor.x
        y: plate.box.y + (plate.box.w - plate.height) * plate.anchor.y
        radius: frame.holeR
        color: Config.bg
        Behavior on width { NumberAnimation { duration: plate.eased ? Motion.spatialDur : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve } }
        Behavior on height { NumberAnimation { duration: plate.eased ? Motion.spatialDur : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve } }
    }

    // No layer.effect shadow: caching this into a layer stops it presenting new bulges.
    Item {
        id: frameLayer
        anchors.fill: parent
        visible: !frame.suppressed   // hidden under a fullscreen window

        Loader {
            anchors.fill: parent
            active: Power.frameShader
            sourceComponent: sdfSurface
        }
        Loader {
            anchors.fill: parent
            active: !Power.frameShader
            sourceComponent: flatSurface
        }
    }

    Component {
        id: sdfSurface

        ShaderEffect {
            id: sdf
            property real barW: frame.barWidth
            property real t: frame.borderT
            property real r: frame.holeR
            property real k: 26       // cove size (smin)
            property real popK: 34    // popout bulge smoothing
            // Open popout body in screen px. Only the SIZE animates — a snapping position keeps
            // a switch to a neighbouring widget from flying the bulge across the bar.
            property real bw: PopoutState.box.z
            property real bh: PopoutState.box.w
            // Duration, not `enabled`: disabling a Behavior doesn't stop an animation in flight.
            Behavior on bw { NumberAnimation { duration: PopoutState.animated ? Motion.spatialDur : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve } }
            Behavior on bh { NumberAnimation { duration: PopoutState.animated ? Motion.spatialDur : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve } }

            // A uniform change alone doesn't damage the layer surface here, so nudge a repaint.
            Timer { id: repaintKick; interval: 50; onTriggered: sdf.opacity = 1 }
            Connections {
                target: PopoutState
                function onBoxChanged() {
                    sdf.opacity = 0.999;
                    repaintKick.restart();
                }
                function onBox3Changed() {
                    sdf.opacity = 0.999;
                    repaintKick.restart();
                }
            }
            // Position derived from the animating size, so the bulge grows out of its own border.
            readonly property vector4d pop: Qt.vector4d(
                PopoutState.box.x + (PopoutState.box.z - bw) * PopoutState.anchor.x,
                PopoutState.box.y + (PopoutState.box.w - bh) * PopoutState.anchor.y,
                bw, bh)

            // Second bulge (toast) — same treatment.
            property real bw2: PopoutState.box2.z
            property real bh2: PopoutState.box2.w
            Behavior on bw2 { NumberAnimation { duration: Motion.spatialDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve } }
            Behavior on bh2 { NumberAnimation { duration: Motion.spatialDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve } }
            readonly property vector4d pop2: Qt.vector4d(
                PopoutState.box2.x + (PopoutState.box2.z - bw2) * PopoutState.anchor2.x,
                PopoutState.box2.y + (PopoutState.box2.w - bh2) * PopoutState.anchor2.y,
                bw2, bh2)
            // Third bulge (side panel): reported live every frame, so easing would only lag it.
            readonly property vector4d pop3: PopoutState.box3

            property color fillColor: Config.bg
            // Raised edge on the surface itself; a drop shadow only shows against light content.
            property color bevelColor: Config.bevel
            // Tight falloff: wider spreads read as a glow rather than depth.
            property real bevelR: 1.2
            property real bevelA: 1.0
            // Dark themes want a highlight, light ones a contact shadow.
            property real bevelDir: Config.lightMode ? -1.0 : 1.0
            readonly property vector2d res: Qt.vector2d(width, height)
            fragmentShader: Qt.resolvedUrl("../assets/frame.frag.qsb")
        }
    }

    Component {
        id: flatSurface

        // The same surface as rectangles. No coves, no bevel, no rounded recess — no GPU pass.
        Item {
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: frame.barWidth
                color: Config.bg
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: frame.borderT
                color: Config.bg
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: frame.borderT
                color: Config.bg
            }
            Rectangle {
                anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                width: frame.borderT
                color: Config.bg
            }

            // Declared after the borders, so a plate overlaps the one it flows out of.
            Plate { box: PopoutState.box;  anchor: PopoutState.anchor;  eased: PopoutState.animated }
            Plate { box: PopoutState.box2; anchor: PopoutState.anchor2 }
            // Slot 3 reports live geometry every frame; easing here would lag the panel.
            Plate { box: PopoutState.box3; anchor: PopoutState.anchor3; eased: false }
        }
    }
}
