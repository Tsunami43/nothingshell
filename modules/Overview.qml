// Right-edge workspace overview: every workspace top to bottom with the windows on it. Hover the
// right border to reveal it. Like the other popouts it paints nothing — the background is the
// Frame's THIRD SDF bulge slot (reportBox → PopoutState.setBox3 → modules/Frame.qml), the slot the
// old side panel used and left free.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import qs.modules.overview

PanelWindow {
    id: ovWin
    required property var modelData
    screen: modelData

    // Always realized, like the launcher: it slides off-screen instead of unmapping, so the window
    // is the real screen size and the bulge geometry is right from the first frame.
    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    // Never takes the keyboard: this panel opens on hover, and an Exclusive grab would pull
    // keystrokes out of the focused window just because the cursor brushed the border.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property int gap: 16     // panel inset from the screen edges
    readonly property int pad: 26     // content padding inside the bulge
    // Both fractions of the screen, never pixel constants: the same numbers have to read the same
    // on a 1080p laptop and on this 1440p-logical panel.
    readonly property int triggerH: Math.round(ovWin.height * 0.25)  // closed hot-zone: middle quarter
    readonly property int panelH: Math.round(ovWin.height * 0.5)     // panel height, content-independent

    property bool ovOpen: false
    property bool triggerHov: false
    property bool panelHov: false
    onTriggerHovChanged: ovUpdate()
    onPanelHovChanged: ovUpdate()

    // --- Drag state ---
    // A drag pins the panel open: the cursor routinely leaves it while carrying a window, and a
    // hover rule that closed the panel mid-drag would drop the thing being dragged.
    property string dragKind: ""      // "" | "win" | "ws"
    property string dragAddr: ""
    property int dragWs: 0
    property int dropWs: 0
    property int scrollDir: 0
    readonly property bool dragging: ovWin.dragKind !== ""
    onDraggingChanged: ovUpdate()
    // The launcher and the capture panel hold an exclusive keyboard grab and sit over everything;
    // staying open behind them only gets in the way.
    readonly property bool blocked: Shell.launcherVisible || Shell.captureVisible
    onBlockedChanged: ovUpdate()

    function ovUpdate() {
        // Checked first and returns: no hover transition may close the panel mid-drag.
        if (ovWin.dragging) { openTimer.stop(); closeTimer.stop(); ovWin.ovOpen = true; return; }
        if (ovWin.blocked) { openTimer.stop(); closeTimer.stop(); ovWin.ovOpen = false; return; }
        // Keyboard route in: no settle delay, a keybind is not a cursor brushing past.
        if (Shell.overviewVisible) { openTimer.stop(); closeTimer.stop(); ovWin.ovOpen = true; return; }
        if (ovWin.triggerHov || ovWin.panelHov) {
            closeTimer.stop();
            if (!ovWin.ovOpen) openTimer.restart();
        } else {
            openTimer.stop();
            closeTimer.restart();
        }
    }
    // The trigger sits where scrollbars and window edges live, so brushing past it must not count —
    // the cursor has to rest there first.
    Timer { id: openTimer; interval: 180; onTriggered: ovWin.ovOpen = true }
    // Short, not zero: crossing the seam between the trigger strip and the panel drops both hover
    // trackers for a frame.
    Timer { id: closeTimer; interval: 90; onTriggered: ovWin.ovOpen = false }

    // Opening scrolls the active workspace into view. The panel is a fixed half-screen while the
    // list behind it is as long as the workspaces are, so the one you are actually on is usually
    // outside the viewport — landing on it is what makes the panel useful on open.
    // Deferred: it runs before the rows have laid out on the very first open otherwise.
    onOvOpenChanged: {
        reportBox();
        if (ovWin.ovOpen) Qt.callLater(ovWin.revealActive);
        // Clear the IPC flag on the way out, so the keybind can open it again.
        else Shell.overviewVisible = false;
    }
    Connections {
        target: Shell
        function onOverviewVisibleChanged() { ovWin.ovUpdate(); }
    }
    function revealActive() {
        const it = wsRep.itemAt(Hypr.activeWs - 1);   // null for a special workspace (negative id)
        if (!it) return;
        const max = Math.max(0, wsList.contentHeight - wsList.height);
        wsList.contentY = Math.max(0, Math.min(max, it.y + it.height / 2 - wsList.height / 2));
    }

    // Thumbnails capture only while the panel is actually up; every tile binds its capture source
    // to this, and a false tears every context down.
    readonly property bool capturing: ovWin.ovOpen && !ovWin.blocked
    // A counter rather than a signal: the tiles hold this window as an untyped `var`, and
    // Connections can't resolve a signal through that — it warns and never fires.
    property int shotTick: 0
    Timer {
        interval: Math.max(400, Config.overviewRefreshMs)
        running: ovWin.capturing && Power.windowThumbs
        repeat: true
        onTriggered: ovWin.shotTick++
    }

    // Report the panel body rect (screen px) so the Frame bulges the right border out into it.
    // Driven off the panel's LIVE x, so the bulge rides the slide 1:1 — slot 3 is passed to the
    // shader unsmoothed for exactly this reason (Frame.qml:93-95).
    // One slot, one panel per screen — so a closing panel only drops the box if it still owns it.
    readonly property string slotId: "overview:" + (modelData?.name ?? "")
    function reportBox() {
        if (!ovWin.ovOpen && PopoutState.owner3 !== ovWin.slotId) return;
        // Inset LESS than the content padding, so a ring of background frames the content.
        const inset = 16;
        const px = panel.x + inset;
        // Fully off the right edge: the bulge has sunk back into the border.
        if (px >= ovWin.width) { PopoutState.clear3(ovWin.slotId); return; }
        // Runs 18px past the right edge so it fuses with the border. Anchored on its right edge,
        // which is where it collapses back to.
        PopoutState.setBox3(px, panel.y + inset, ovWin.width - px + 18,
                            panel.height - inset * 2, 1.0, 0.5, ovWin.slotId);
    }

    // --- Drag controller ---
    // Coordinates are dragLayer's throughout, so the proxy and the hit-test agree.
    function beginDrag(kind, addr, ws, w, h) {
        ovWin.dragKind = kind; ovWin.dragAddr = addr; ovWin.dragWs = ws;
        ghost.width = w; ghost.height = h;
    }
    function moveDrag(pt) {
        ghost.x = pt.x - ghost.width / 2;
        ghost.y = pt.y - ghost.height / 2;
        ovWin.dropWs = ovWin.hitWs(pt);
        const f = wsList.mapFromItem(dragLayer, pt.x, pt.y);
        ovWin.scrollDir = f.y < 52 ? -1 : (f.y > wsList.height - 52 ? 1 : 0);
    }
    function endDrag() {
        const from = ovWin.dragWs, to = ovWin.dropWs, kind = ovWin.dragKind, addr = ovWin.dragAddr;
        ovWin.cancelDrag();
        if (!to || to === from) return;
        if (kind === "win") Hypr.moveWindow(addr, to);
        else if (kind === "ws") { Hypr.wsBusy = from; Hypr.swapWorkspaces(from, to); busyClear.restart(); }
    }
    function cancelDrag() {
        ovWin.dragKind = ""; ovWin.dragAddr = ""; ovWin.dragWs = 0;
        ovWin.dropWs = 0; ovWin.scrollDir = 0;
    }
    // The busy flag is cleared on a timer rather than on an event: if the batch fails, the rows
    // must not stay disabled forever.
    Timer { id: busyClear; interval: 600; onTriggered: Hypr.wsBusy = 0 }

    // Tiles and rows report pointer positions in their own coordinates; everything the drag does
    // is in the layer's.
    function toDrag(item, x, y) { return dragLayer.mapFromItem(item, x, y); }

    // Which workspace row is under a point. childAt returns the topmost direct child, which is
    // exactly one WsRow, and skips invisible ones.
    function hitWs(pt) {
        const c = wsCol.mapFromItem(dragLayer, pt.x, pt.y);
        const it = wsCol.childAt(c.x, c.y);
        return it && it.ws !== undefined ? it.ws : 0;
    }

    Timer {
        interval: 16; repeat: true
        running: ovWin.dragging && ovWin.scrollDir !== 0
        onTriggered: wsList.contentY = Math.max(0, Math.min(wsList.contentHeight - wsList.height,
                                                            wsList.contentY + ovWin.scrollDir * 14))
    }

    // Hot-zone: when closed, a thin strip covering only the MIDDLE of the right border — the top and
    // bottom of that border belong to window edges and scrollbars, and opening from there was all
    // false positives. When open it grows to the panel plus a buffer; the buffer is hysteresis, so
    // movement near the panel doesn't flicker it. While dragging the whole screen is claimed, so the
    // rows keep seeing the pointer wherever it wanders.
    Item {
        id: ovHot
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: ovWin.ovOpen ? panel.width + ovWin.gap + 40 : 6
        height: ovWin.ovOpen ? parent.height : Math.min(parent.height, ovWin.triggerH)
        HoverHandler { onHoveredChanged: ovWin.triggerHov = hovered }
    }
    Item { id: fullMask; anchors.fill: parent }
    mask: Region { item: ovWin.dragging ? fullMask : ovHot }

    Item {
        id: panel
        // Plain numbers, never a sum of implicit heights: sizing the panel from the rows while the
        // rows size themselves from the panel is a cycle, and QML resolves it by drawing nothing.
        width: Math.max(280, Config.overviewWidth)
        // Half the screen, NOT the sum of the rows: sizing to the content made the panel — and the
        // frame bulge behind it — grow every time a workspace appeared or a window opened. Nine
        // workspaces get the same panel as two; the list inside scrolls.
        height: ovWin.panelH
        anchors.verticalCenter: parent.verticalCenter

        anchors.right: parent.right
        anchors.rightMargin: ovWin.ovOpen ? ovWin.gap : -width - 24
        Behavior on anchors.rightMargin { Anim { type: Anim.Spatial } }

        // The bulge IS the background, so every geometry change has to be re-reported.
        onXChanged: ovWin.reportBox()
        onYChanged: ovWin.reportBox()
        onWidthChanged: ovWin.reportBox()
        onHeightChanged: ovWin.reportBox()

        // Tracks the panel and all its children; a parent HoverHandler is not stolen by child
        // MouseAreas, so hovering a tile keeps the panel open.
        HoverHandler { onHoveredChanged: ovWin.panelHov = hovered }
        MouseArea { anchors.fill: parent }   // swallow clicks on the panel itself

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: ovWin.pad
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MatIcon { text: "grid_view"; font.pixelSize: 17; color: Config.accent }
                Text {
                    text: "Workspaces"
                    color: Config.fg; font.family: Config.textFont; font.pixelSize: 14; font.bold: true
                }
                Item { Layout.fillWidth: true }
                Text {
                    readonly property int n: Hypr.wsList.length
                    text: n + (n === 1 ? " space" : " spaces")
                    color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                }
            }

            Flickable {
                id: wsList
                Layout.fillWidth: true; Layout.fillHeight: true
                contentHeight: wsCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // The drag scrolls the list itself; leaving it interactive would let a drag fling
                // the list out from under its own drop target.
                interactive: !ovWin.dragging

                ColumnLayout {
                    id: wsCol
                    width: wsList.width
                    spacing: 8

                    Repeater {
                        id: wsRep
                        model: Hypr.maxWs
                        WsRow {
                            required property int index
                            ws: index + 1
                            panel: ovWin
                        }
                    }
                }
            }
        }

        // Drag layer: the ghost lives here, above the clipped list, so it stays visible when the
        // cursor carries it past the viewport edge. A real thumbnail is deliberately NOT used —
        // moving a capture context around every frame is the one thing that would stutter.
        Item {
            id: dragLayer
            anchors.fill: parent
            z: 100
            visible: ovWin.dragging

            Rectangle {
                id: ghost
                width: 150; height: 92
                radius: 12
                color: Config.containerSoft
                opacity: 0.92
                scale: 1.05
                rotation: 3
                border.width: 2
                border.color: Config.accent
                Elevation { anchors.fill: parent; radius: parent.radius; z: -1; level: 3 }

                MatIcon {
                    anchors.centerIn: parent
                    text: ovWin.dragKind === "ws" ? "workspaces" : "drag_indicator"
                    font.pixelSize: 26
                    color: Config.accent
                }
            }
        }
    }
}
