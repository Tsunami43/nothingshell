pragma Singleton

// Geometry of the currently-open bar popout, in screen pixels. The Frame's SDF shader reads it
// and bulges the bar surface out to form the popout body — one continuous surface, not a detached
// panel. Stored as one atomic vector4d (x, y, w, h) because assigning the components one by one
// let the shader sample a torn state and flash a zero width. z (=w) <= 0 means nothing is open.
import QtQuick
import Quickshell

Singleton {
    id: root
    property vector4d box: Qt.vector4d(0, 0, 0, 0)
    // Second, independent bulge slot (a toast melting out of the top border).
    property vector4d box2: Qt.vector4d(0, 0, 0, 0)
    // Third slot: the right-edge side panel, the one popout that stays open while another is
    // used — a translation is what you keep on screen while the launcher comes and goes.
    property vector4d box3: Qt.vector4d(0, 0, 0, 0)

    // Who owns the `box` slot, so a closing popout can't wipe a bulge another just claimed.
    // Empty = the legacy anonymous bar popouts.
    property string owner: ""

    // False draws `box` at its reported size instantly, for a popout that animates its own
    // geometry and re-reports every frame (the launcher): the bulge tracks it 1:1.
    property bool animated: true

    // Which point of the box stays put while the Frame eases the bulge open and shut, as a
    // fraction of it: (0,0) top-left, (0.5,1) bottom-centre. The Frame animates the SIZE only,
    // so without this every bulge grows out of its top-left corner instead of out of the border
    // it belongs to. The bar passes the left edge and its widget's own vertical share.
    property vector2d anchor: Qt.vector2d(0, 0)

    // Same for slot 2: a toast sits top-RIGHT, so it holds that edge (1, 0) and retracts into
    // the corner instead of towards the screen interior.
    property vector2d anchor2: Qt.vector2d(0, 0)
    // Slot 3. The side panel holds its right edge (1, 0.5) to sink back into the right border.
    property vector2d anchor3: Qt.vector2d(1, 0.5)

    // Back-compat individual readers (x, y, w, h).
    readonly property real x: box.x
    readonly property real y: box.y
    readonly property real w: box.z
    readonly property real h: box.w

    // Report a popout body rect (screen px), overlapping the bar on the left so the bulge
    // connects to it. `o` is an owner id for the matching clear(o), `anim` false tracks a
    // self-animating panel 1:1, `ax`/`ay` name the anchor point.
    function setBox(bx, by, bw, bh, o, anim, ax, ay) {
        root.owner = (o === undefined ? "" : o);
        root.animated = (anim === undefined ? true : anim);
        root.anchor = Qt.vector2d(ax === undefined ? 0 : ax, ay === undefined ? 0 : ay);
        root.box = Qt.vector4d(bx, by, bw, bh);
    }

    // Collapse onto the ANCHOR point, not the top-left corner, so the shrink runs back into the
    // border the popout grew out of. With an owner id, no-op unless we still own the slot.
    function clear(o) {
        if (o !== undefined && o !== root.owner) return;
        root.owner = "";
        root.animated = true;
        root.box = Qt.vector4d(root.box.x + root.box.z * root.anchor.x,
                               root.box.y + root.box.w * root.anchor.y, 0, 0);
    }

    // Second slot (toast); `ax`/`ay` as in `anchor2`.
    function setBox2(bx, by, bw, bh, ax, ay) {
        root.anchor2 = Qt.vector2d(ax === undefined ? 0 : ax, ay === undefined ? 0 : ay);
        root.box2 = Qt.vector4d(bx, by, bw, bh);
    }
    function clear2() {
        root.box2 = Qt.vector4d(root.box2.x + root.box2.z * root.anchor2.x,
                                root.box2.y + root.box2.w * root.anchor2.y, 0, 0);
    }

    // Third slot (right-edge overview). Reported live off the sliding panel, so it always tracks
    // 1:1 and ignores `animated`. Owner-guarded like slot 1: the panel is per-screen while this
    // slot is one global, so a closing panel must not wipe a box another screen's just claimed.
    property string owner3: ""
    function setBox3(bx, by, bw, bh, ax, ay, o) {
        root.owner3 = (o === undefined ? "" : o);
        root.anchor3 = Qt.vector2d(ax === undefined ? 1 : ax, ay === undefined ? 0.5 : ay);
        root.box3 = Qt.vector4d(bx, by, bw, bh);
    }
    function clear3(o) {
        if (o !== undefined && o !== root.owner3) return;
        root.owner3 = "";
        root.box3 = Qt.vector4d(root.box3.x + root.box3.z * root.anchor3.x,
                                root.box3.y + root.box3.w * root.anchor3.y, 0, 0);
    }
}
