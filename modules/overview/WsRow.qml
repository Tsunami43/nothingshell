// One workspace in the overview: a header (Roman numeral, matching the bar, plus the window
// count) over the windows living on it. Empty workspaces get a row too — they are drop targets.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

Rectangle {
    id: row
    required property int ws
    required property var panel        // the Overview window, passed down to the tiles

    // The workspace object where Hyprland knows about it; null for a slot that doesn't exist yet.
    readonly property var hws: Hypr.wsList.find(w => w.id === row.ws) ?? null
    // Its own toplevel model, which notifies per workspace — cheaper and more reactive than
    // re-filtering the global list on every refresh the way the bar does.
    readonly property var wins: row.hws ? (row.hws.toplevels?.values ?? []) : []
    readonly property bool active: row.ws === Hypr.activeWs
    readonly property bool urgent: !!Hypr.urgentWs[row.ws] && !row.active
    // Same numbering the bar shows, so a workspace reads the same in both places.
    readonly property string roman: {
        let n = row.ws, r = "";
        const m = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
        for (const p of m) while (n >= p[0]) { r += p[1]; n -= p[0]; }
        return r;
    }

    // Where a drag would land. A window drop fills the row in the accent container; a workspace
    // swap tints it differently, so "move this window here" never looks like "swap these two".
    readonly property bool winTarget: row.panel?.dragKind === "win"
        && row.panel.dropWs === row.ws && row.panel.dragWs !== row.ws
    readonly property bool swapTarget: row.panel?.dragKind === "ws"
        && row.panel.dropWs === row.ws && row.panel.dragWs !== row.ws

    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + 20
    radius: 16
    color: row.winTarget ? Config.accentContainer
         : row.swapTarget ? Config.container
         : row.active ? Config.containerSoft : Config.surface
    Behavior on color { ColorAnim {} }
    // Swapping this workspace: refuse input and dim until the batch has landed.
    enabled: Hypr.wsBusy === 0
    opacity: Hypr.wsBusy === row.ws ? 0.55 : 1
    Behavior on opacity { Effect {} }

    // Only the active workspace is outlined, so the row a dragged window would land on is the one
    // that stands out (that highlight arrives with the drag step).
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: row.winTarget || row.swapTarget ? 2 : (row.active ? 1 : 0)
        border.color: row.swapTarget ? Config.tertiary : Config.accent
        Behavior on border.color { ColorAnim {} }
    }

    // Clicking the row anywhere the tiles don't cover switches to that workspace. Behind the
    // content, so a tile's own click wins.
    StateLayer {
        ovRadius: row.radius
        z: -1
        // activate() where the workspace exists; a slot Hyprland hasn't created yet has no object,
        // so the dispatch fallback is required, not decorative.
        onTapped: { if (row.hws) row.hws.activate(); else Hyprland.dispatch("workspace " + row.ws) }
    }

    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top
                  leftMargin: 10; rightMargin: 10; topMargin: 10 }
        spacing: 8

        // The header doubles as the workspace's own drag handle: press it and move to swap this
        // workspace with another. A plain click still activates it. The wrapper exists because a
        // MouseArea placed directly in a layout cannot use anchors — the layout owns its geometry.
        Item {
            Layout.fillWidth: true
            implicitHeight: hdr.implicitHeight

            RowLayout {
                id: hdr
                anchors.fill: parent
                spacing: 8

                Rectangle {
                    implicitWidth: 24; implicitHeight: 24; radius: 8
                    color: row.active ? Config.accent : "transparent"
                    Behavior on color { ColorAnim {} }
                    Text {
                        anchors.centerIn: parent
                        text: row.roman
                        font.family: Config.textFont; font.pixelSize: 12; font.bold: true
                        color: row.active ? Config.accentText : (row.urgent ? Config.error : Config.dim)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: row.wins.length === 0 ? "empty"
                        : row.wins.length + (row.wins.length === 1 ? " window" : " windows")
                    color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                }
                MatIcon {
                    text: "drag_indicator"
                    font.pixelSize: 16
                    color: hdrMa.containsMouse ? Config.tertiary : Config.outline
                    Behavior on color { ColorAnim {} }
                }
            }

            MouseArea {
                id: hdrMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                property real px: 0
                property real py: 0
                property bool armed: false

                onPressed: e => { hdrMa.px = e.x; hdrMa.py = e.y; hdrMa.armed = false; }
                onPositionChanged: e => {
                    if (!hdrMa.pressed) return;
                    if (!hdrMa.armed && Math.hypot(e.x - hdrMa.px, e.y - hdrMa.py) > 8) {
                        hdrMa.armed = true;
                        row.panel.beginDrag("ws", "", row.ws, 150, 60);
                    }
                    if (hdrMa.armed) row.panel.moveDrag(row.panel.toDrag(hdrMa, e.x, e.y));
                }
                onReleased: {
                    if (hdrMa.armed) { hdrMa.armed = false; row.panel.endDrag(); return; }
                    if (row.hws) row.hws.activate();
                    else Hyprland.dispatch("workspace " + row.ws);
                }
                onCanceled: { if (hdrMa.armed) { hdrMa.armed = false; row.panel.cancelDrag(); } }
            }
        }

        // Two tiles fit the default panel width exactly; a wider panel wraps three.
        Flow {
            Layout.fillWidth: true
            visible: row.wins.length > 0
            spacing: 8
            Repeater {
                model: row.wins
                WinTile {
                    required property var modelData
                    toplevel: modelData
                    panel: row.panel
                    ws: row.ws
                }
            }
        }

        // An empty workspace keeps a slot of its own — it is what a dragged window aims at.
        Rectangle {
            Layout.fillWidth: true
            visible: row.wins.length === 0
            implicitHeight: 34
            radius: 10
            color: "transparent"
            border.width: 1
            border.color: Config.outline
            opacity: 0.6
        }
    }
}
