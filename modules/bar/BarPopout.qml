// Shared shell for every bar popout: anchor, fade-and-slide body, hover, and the Frame bulge
// that serves as its background. Callers add content and name their widget.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

PopupWindow {
    id: pop

    // The Bar window. Untyped: Bar.qml instantiates these, so naming its type would be circular.
    required property var bar
    // The bar widget this anchors to and grows out of.
    required property Item widget
    // The bar.popout value that shows this one.
    required property string name
    // A condition beyond the name (the recorder pane closes on its own state).
    property bool available: true
    // Content height, before the fillets the SDF cove needs.
    property real bodyHeight: 0

    default property alias content: body.data

    readonly property bool shown: pop.bar.popout === pop.name && pop.available
    signal opened()
    // Raised before the shared bulge slot is released. NOT `closed`: PopupWindow already has a
    // signal by that name, and the override is rejected — the handlers would then hang off the
    // base signal instead.
    signal dismissed()

    // Height to draw the bulge at where implicitHeight lags (the tray menu). Negative = use
    // implicitHeight; zero = the body is mid-reload, keep the bulge that is up.
    //
    // A FUNCTION, not a property: a popout whose body resizes asynchronously reports from the very
    // change handler that feeds this, and a property binding still holds the PREVIOUS value there.
    // As a property it left the bulge a size behind every icon switch — the menu drew at full size
    // over a stub of a background, and the stub stayed until the next switch.
    function bulge() { return -1; }
    // Re-report while merely hovered, for content that changes under the cursor.
    property bool reportOnHover: false

    anchor.window: pop.bar
    anchor.item: pop.widget
    anchor.edges: Edges.Right
    anchor.gravity: Edges.Right
    // Slide, never flip: flipping threw the power menu to the top of the screen.
    anchor.adjustment: PopupAdjustment.Slide
    anchor.margins.left: -2           // sit flush against the bar edge

    visible: pop.shown || body.opacity > 0.01   // stay mapped through the fade-out
    implicitHeight: pop.bodyHeight + Config.popFillet * 2
    property real botPad: Config.popFillet   // set by reportPopBox when the screen edge crowds the body
    color: "transparent"

    onShownChanged: {
        if (pop.shown) { pop.opened(); pop.report(undefined); return; }
        pop.dismissed();
        if (pop.bar.popout === "") PopoutState.clear(pop.bar.bulgeOwner);
    }
    // Content that resizes has to re-report, or the bulge keeps the old size. Only where the body
    // height IS the window height: a popout with its own bulge() derives this from the same layout
    // it already reports off, so acting here too would report the identical box a second time —
    // once more with `anim` unset, which restarts the Frame's easing over a bulge the first call
    // had already landed.
    onImplicitHeightChanged: if (pop.shown && pop.bulge() < 0) pop.report(undefined)

    // `anim` false lands the bulge in the same frame, for a popout that merely resized.
    function report(anim) {
        if (!pop.shown || !pop.widget) return;
        const h = pop.bulge();
        if (h < 0) { pop.bar.reportPopBox(pop.widget, pop, anim); return; }
        if (h < 1) return;                     // mid-reload: keep the bulge that is up
        pop.bar.reportPopBox(pop.widget, pop, anim, h);
    }

    Item {
        id: body
        anchors.fill: parent
        opacity: pop.shown ? 1 : 0
        Behavior on opacity { Anim { type: Anim.Effect } }
        transform: Translate { x: pop.shown ? 0 : -14; Behavior on x { Anim { type: Anim.Spatial } } }
        HoverHandler {
            onHoveredChanged: {
                if (!hovered) { pop.bar.hidePopout(); return; }
                pop.bar.showPopout(pop.name);
                if (pop.reportOnHover) pop.report(false);
            }
        }
    }
}
