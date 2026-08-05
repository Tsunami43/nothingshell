// Unified screen frame: the bar (thick left border) plus thin top/right/bottom ones as a single
// SDF surface, with concave coves where they meet (assets/frame.frag). Full-screen via
// ExclusionMode.Ignore so its coords are the real screen, drawn above windows with input passing
// through, hidden under a fullscreen one. The bar keeps its own window on top for the widgets.
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
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // Keep the surface mapped across fullscreen toggles (unmap→remap is unreliable, see Bar.qml);
    // hide the shader instead. mask is already empty, so there is no input to gate.
    visible: true
    exclusionMode: ExclusionMode.Ignore   // span the whole output; coords = real screen
    WlrLayershell.layer: WlrLayer.Top
    mask: Region {}   // clicks pass through everywhere (the bar window handles bar input)

    // No layer.effect drop shadow: caching the frame into a layer stopped it presenting new
    // frames when only the bulge changed, leaving popouts over a stale background. Depth comes
    // from the shader's bevel; free-floating popouts (the OSDs) use Elevation.
    Item {
        id: frameLayer
        anchors.fill: parent
        visible: !frame.suppressed   // hide the frame under a fullscreen window

        ShaderEffect {
            id: sdf
            anchors.fill: parent
            property real barW: frame.barWidth
            property real t: 8        // top/right/bottom border thickness
            property real r: 20       // content-hole corner radius
            property real k: 26       // cove size (smin)
            property real popK: 34    // popout bulge smoothing
            // Open bar-popout body (screen px): x, y, z=w, w=h; read atomically, see PopoutState.
            // Only the SIZE animates — a snapping position keeps a switch to a neighbouring
            // widget from flying the bulge across the bar.
            property real bw: PopoutState.box.z
            property real bh: PopoutState.box.w
            // Duration, not `enabled`: disabling a Behavior doesn't stop an animation in flight,
            // so the old easing kept overwriting freshly reported sizes — that is what stuck the
            // tray menu's bulge at the previous menu's height. Zero duration still intercepts the
            // change and lands it in the same frame, which self-animating panels want.
            Behavior on bw { NumberAnimation { duration: PopoutState.animated ? Motion.spatialDur : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve } }
            Behavior on bh { NumberAnimation { duration: PopoutState.animated ? Motion.spatialDur : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve } }

            // On this Qt build a shader uniform change alone doesn't mark the layer-shell window
            // damaged, so with no animation running it kept presenting the previous bulge until
            // something else dirtied the scene graph — the tray menu drew over a stale background
            // and moving the cursor "fixed" it. Opacity 0.999 is a visual no-op that forces the
            // repaint; the timer puts it back.
            Timer { id: repaintKick; interval: 50; onTriggered: sdf.opacity = 1 }
            Connections {
                target: PopoutState
                function onBoxChanged() {
                    sdf.opacity = 0.999;
                    repaintKick.restart();
                }
                // Same staleness trap for the side panel's slot: its box changes without any
                // animation of ours running, so the window has to be nudged into repainting.
                function onBox3Changed() {
                    sdf.opacity = 0.999;
                    repaintKick.restart();
                }
            }
            // Position derived from the animating size, so the bulge grows out of the border it
            // belongs to: PopoutState.anchor is the point that stays put while bw/bh ease. The
            // default (0,0) pins the top-left corner, what the bar popouts were written against.
            readonly property vector4d pop: Qt.vector4d(
                PopoutState.box.x + (PopoutState.box.z - bw) * PopoutState.anchor.x,
                PopoutState.box.y + (PopoutState.box.w - bh) * PopoutState.anchor.y,
                bw, bh)

            // Second bulge (toast) — same in-place grow/shrink treatment.
            property real bw2: PopoutState.box2.z
            property real bh2: PopoutState.box2.w
            Behavior on bw2 { NumberAnimation { duration: Motion.spatialDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve } }
            Behavior on bh2 { NumberAnimation { duration: Motion.spatialDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve } }
            readonly property vector4d pop2: Qt.vector4d(
                PopoutState.box2.x + (PopoutState.box2.z - bw2) * PopoutState.anchor2.x,
                PopoutState.box2.y + (PopoutState.box2.w - bh2) * PopoutState.anchor2.y,
                bw2, bh2)
            // Third bulge (side panel). It reports live geometry every frame while it slides, so
            // easing here would only lag the panel this is the background of.
            readonly property vector4d pop3: PopoutState.box3

            property color fillColor: Config.bg
            // Raised edge on the surface itself: a drop shadow only shows against light content,
            // and the windows against the frame are usually dark. Its own palette role because
            // the direction it travels from the fill depends on the mode.
            property color bevelColor: Config.bevel
            // Tight falloff on purpose: at 2.5 the tint spread ~12px and saturated the perimeter
            // into a uniform halo, which reads as a glow rather than depth. Pulled in, the light
            // collects into a line along the boundary.
            property real bevelR: 1.2
            property real bevelA: 1.0
            // Which way the overhead light shades the edge: a dark theme wants a highlight, a
            // light one a contact shadow — opposite responses to the same normal.
            property real bevelDir: Config.lightMode ? -1.0 : 1.0
            readonly property vector2d res: Qt.vector2d(width, height)
            fragmentShader: Qt.resolvedUrl("../assets/frame.frag.qsb")
        }
    }
}
