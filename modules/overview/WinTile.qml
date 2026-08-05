// One window in the overview. The card underneath is always an icon + title; the live thumbnail
// fades in over it only once a frame actually arrives, so a window whose capture never lands (or
// lands empty) stays readable instead of showing a black box.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

Rectangle {
    id: tile
    required property var toplevel     // HyprlandToplevel
    required property var panel        // the Overview window, for the capture gate and drag state
    required property int ws           // the workspace this tile currently sits on

    readonly property string addr: Hypr.addrOf(tile.toplevel)
    readonly property string cls: tile.toplevel?.lastIpcObject?.class ?? ""
    readonly property string title: tile.toplevel?.title ?? tile.toplevel?.lastIpcObject?.title ?? ""
    readonly property var entry: tile.cls ? DesktopEntries.heuristicLookup(tile.cls) : null
    readonly property bool focused: tile.toplevel?.activated ?? false
    // A HoverHandler, NOT the MouseArea's containsMouse: the close button is a mouse area of its
    // own, so hovering it dropped containsMouse, which hid the button, which handed the hover
    // back — the tile strobed. A parent HoverHandler is not stolen by child mouse areas.
    readonly property bool hovered: tileHov.hovered
    HoverHandler { id: tileHov }
    // Ghosted while its own proxy is in flight, so it is obvious which window is being carried.
    opacity: (tile.panel?.dragging ?? false) && tile.panel.dragAddr === tile.addr ? 0.25 : 1
    Behavior on opacity { Anim { type: Anim.Effect } }

    function focusWin() {
        // The Wayland handle where it exists: it is the protocol's own verb and sidesteps the
        // address-format trap entirely.
        if (tile.toplevel?.wayland) tile.toplevel.wayland.activate();
        else Hypr.focusWindow(tile.addr);
    }
    function closeWin() {
        // close() is a polite request — an editor with unsaved work still gets to ask.
        if (tile.toplevel?.wayland) tile.toplevel.wayland.close();
        else Hypr.closeWindow(tile.addr);
    }

    implicitWidth: 150; implicitHeight: 92
    radius: 12
    color: Config.container
    clip: true

    // --- Icon card (the floor: always present, covered when a thumbnail arrives) ---
    FadeImage {
        id: appIcon
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -6
        width: 30; height: 30
        box: 30
        fillMode: Image.PreserveAspectFit
        source: tile.entry?.icon ? Quickshell.iconPath(tile.entry.icon, true) : ""
    }
    // No desktop entry, or no icon in the theme: the category glyph, which is what
    // Hypr.appCategoryIcon was written for and never used until now.
    MatIcon {
        anchors.centerIn: appIcon
        visible: !appIcon.ready
        text: Hypr.appCategoryIcon(tile.cls, "web_asset")
        font.pixelSize: 24
        color: Config.dim
    }

    // --- Thumbnail ---
    // `captureSource: null` tears the capture context down, so gating on it is what makes a closed
    // panel cost nothing at all. Assigning a source already grabs one frame, so a still needs no
    // `live` — only the tile under the cursor streams.
    ScreencopyView {
        id: shot
        anchors.centerIn: parent
        z: 1
        // Scales the source into the tile keeping its aspect, so a window letterboxes rather than
        // stretching.
        constraintSize: Qt.size(tile.width - 6, tile.height - 6)
        paintCursor: false
        live: tile.hovered && (tile.panel?.capturing ?? false)
        captureSource: (Config.overviewThumbs && (tile.panel?.capturing ?? false) && tile.toplevel?.wayland)
                       ? tile.toplevel.wayland : null
        opacity: shot.hasContent && shot.sourceSize.width > 1 ? 1 : 0
        Behavior on opacity { Anim { type: Anim.Effect } }

        onStopped: shot.captureSource = null    // compositor ended the stream: fall back to the icon
    }

    // One panel-wide pulse re-grabs every still. captureFrame() no-ops while a request is already
    // in flight, so this can't pile up.
    //
    // `hasContent` is the gate: assigning captureSource asks the compositor for a context, and
    // until the first frame lands there is nothing to capture from — asking anyway is what filled
    // the log with "no recording context is ready", once per tile per pulse. A window whose first
    // frame never arrives simply keeps its icon card.
    readonly property int tick: tile.panel?.shotTick ?? 0
    onTickChanged: if (!shot.live && shot.captureSource && shot.hasContent) shot.captureFrame()

    // --- Title, over the thumbnail on its own scrim so it stays readable either way ---
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 20
        z: 2
        color: Config.bg
        opacity: shot.opacity > 0.5 ? 0.72 : 0
        Behavior on opacity { Anim { type: Anim.Effect } }
    }
    Text {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                  leftMargin: 6; rightMargin: 6; bottomMargin: 4 }
        z: 3
        text: tile.title || tile.cls
        textFormat: Text.PlainText   // the window titles itself; never rich text
        color: tile.focused ? Config.fg : Config.dim
        font.family: Config.textFont; font.pixelSize: 10
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: tile.focused ? 2 : 0
        border.color: Config.accent
        z: 4
    }

    // Hover wash. StateLayer would be the house primitive here, but it hard-wires onPressed /
    // onReleased for its ripple and this tile needs those for the drag threshold.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        z: 5
        color: Config.fg
        opacity: tile.hovered ? Config.hoverOpacity : 0
        Behavior on opacity { Anim { type: Anim.Effect } }
    }

    IconBtn {
        id: closeBtn
        anchors { top: parent.top; right: parent.right; margins: 3 }
        z: 7
        // Faded rather than toggled: `visible` flipping under the cursor is what starts a
        // hover loop in the first place.
        opacity: tile.hovered ? 1 : 0
        visible: opacity > 0.01
        implicitWidth: 22; implicitHeight: 22; iconSize: 14
        icon: "close"; tint: Config.error
        onClicked: tile.closeWin()
        Behavior on opacity { Anim { type: Anim.Effect } }
    }

    // Click focuses, drag past the threshold carries the window to another workspace. Middle-click
    // closes, the usual taskbar gesture.
    MouseArea {
        id: tileMa
        anchors.fill: parent
        z: 6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        // Without this the Flickable claims any vertical motion and the drag never starts.
        preventStealing: true

        property real px: 0
        property real py: 0
        property bool armed: false

        onPressed: e => { tileMa.px = e.x; tileMa.py = e.y; tileMa.armed = false; }
        onPositionChanged: e => {
            if (!tileMa.pressed) return;
            if (!tileMa.armed && Math.hypot(e.x - tileMa.px, e.y - tileMa.py) > 8) {
                tileMa.armed = true;
                tile.panel.beginDrag("win", tile.addr, tile.ws, tile.width, tile.height);
            }
            if (tileMa.armed) tile.panel.moveDrag(tile.panel.toDrag(tileMa, e.x, e.y));
        }
        onReleased: e => {
            if (tileMa.armed) { tileMa.armed = false; tile.panel.endDrag(); return; }
            if (e.button === Qt.MiddleButton) tile.closeWin();
            else tile.focusWin();
        }
        // The compositor can take the grab away mid-drag (alt-tab, a popup). Without this the
        // drag state would stay set and the panel would be pinned open forever.
        onCanceled: { if (tileMa.armed) { tileMa.armed = false; tile.panel.cancelDrag(); } }
    }
}
