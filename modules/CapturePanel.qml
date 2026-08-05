// Capture panel (screenshots + recording): a horizontal strip flowing out of the bottom border,
// the Launcher's sibling. Mode -> source -> settings -> go, left to right; the background is the
// Frame's SDF bulge (PopoutState), not this window.
//
// Named CapturePanel, not Capture: modules/ has no qmldir, so modules/Capture.qml would shadow the
// services/Capture.qml singleton wherever both are imported.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import qs.modules.capture

PanelWindow {
    id: capture
    required property var modelData
    screen: modelData

    // Only the focused output shows the panel: every instance asking for an exclusive keyboard
    // grab would have them fighting over it.
    readonly property bool shown: Shell.captureVisible
        && (Shell.captureScreen === "" || Shell.captureScreen === modelData.name)

    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    // Exclusive so the arrow keys work the moment it opens, without a click (see Launcher).
    WlrLayershell.keyboardFocus: capture.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // --- Wizard state ---
    property string mode: Config.capMode        // shot | rec
    property string src: Config.capSource       // screen | region
    property bool settingsOpen: false
    property int focusIdx: 0                    // index into `slots`
    property int sheetIdx: 0
    property bool sheetFocus: false
    property bool kbFocus: false                // draw focus rings only once a key has been used

    readonly property var slots: ["shot", "rec", "screen", "region", "chip", "go"]
    readonly property var rows: capture.mode === "rec" ? capture.recRows : capture.shotRows
    readonly property var recRows: [
        { kind: "opt", label: "Format",  key: "recFormat",  values: ["mkv", "mp4", "webm"] },
        { kind: "opt", label: "FPS",     key: "recFps",     values: [30, 60, 120], num: true },
        { kind: "opt", label: "Audio",   key: "recAudio",   values: ["none", "desktop", "mic", "both"],
                                                            labels: ["none", "system", "mic", "system+mic"] },
        { kind: "opt", label: "Quality", key: "recQuality", values: ["medium", "high", "very_high", "ultra"],
                                                            labels: ["medium", "high", "very high", "ultra"] },
        { kind: "sw",  label: "Cursor",    key: "recCursor" },
        { kind: "sw",  label: "Copy path", key: "recCopyPath" }
    ]
    readonly property var shotRows: [
        { kind: "sw", label: "Clipboard", key: "shotCopy" },
        { kind: "sw", label: "Save file", key: "shotSave" },
        { kind: "sw", label: "Cursor",    key: "shotCursor" }
    ]

    onShownChanged: {
        if (capture.shown) {
            capture.mode = Config.capMode;
            capture.src = Config.capSource;
            capture.settingsOpen = false;
            capture.sheetFocus = false;
            capture.kbFocus = false;
            capture.focusIdx = capture.mode === "rec" ? 1 : 0;
            keys.forceActiveFocus();
        }
        capture.reportBox();
    }

    function setMode(m) { capture.mode = m; Config.capMode = m; capture.settingsOpen = false; capture.sheetFocus = false; }
    function setSrc(s) { capture.src = s; Config.capSource = s; }
    function go() {
        if (Capture.active) { Capture.stop(); Shell.captureVisible = false; return; }
        if (capture.mode === "rec") Capture.record(capture.src);
        else Capture.screenshot(capture.src);
    }
    // Escape/Backspace unwinds one step at a time rather than closing outright.
    function back() {
        if (capture.sheetFocus) { capture.sheetFocus = false; return; }
        if (capture.settingsOpen) { capture.settingsOpen = false; return; }
        Shell.captureVisible = false;
    }
    function activate(slot) {
        switch (slot) {
        case "shot": capture.setMode("shot"); break;
        case "rec":  capture.setMode("rec");  break;
        case "screen": capture.setSrc("screen"); break;
        case "region": capture.setSrc("region"); break;
        case "chip": capture.settingsOpen = !capture.settingsOpen; break;
        case "go": capture.go(); break;
        }
    }
    // Step the focused settings row through its values (arrows) or flip its switch (Enter).
    function bump(dir) {
        const r = capture.rows[capture.sheetIdx];
        if (!r) return;
        if (r.kind === "sw") { if (dir !== 0) return; Config[r.key] = !Config[r.key]; return; }
        const cur = r.values.findIndex(v => String(v) === String(Config[r.key]));
        const next = r.values[(cur + (dir || 1) + r.values.length) % r.values.length];
        Config[r.key] = r.num ? Number(next) : next;
    }

    // Report the panel body rect (screen px) so the Frame bulges the bottom border up into it.
    // Driven off the live geometry with anim=false so the bulge rides the slide 1:1 — see Launcher.
    function reportBox() {
        if (!capture.shown && PopoutState.owner !== "capture") return;
        const inset = 16, topInset = 16;
        const py = panel.y + topInset;
        if (py >= capture.height) { PopoutState.clear("capture"); return; }
        PopoutState.setBox(panel.x + inset, py, panel.width - inset * 2,
                           panel.height - topInset + 18, "capture", false, 0.5, 1.0);
    }

    // Transparent outside-click catcher — interactive only while open, so the click that closes
    // the panel is never the one slurp is waiting for.
    mask: Region { item: capture.shown ? catcher : null }
    MouseArea {
        id: catcher
        anchors.fill: parent
        onClicked: Shell.captureVisible = false
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: capture.back()
        Keys.onPressed: e => {
            switch (e.key) {
            case Qt.Key_Backspace: capture.back(); break;
            case Qt.Key_Left:
            case Qt.Key_Right: {
                const d = e.key === Qt.Key_Right ? 1 : -1;
                capture.kbFocus = true;
                if (capture.sheetFocus) capture.bump(d);
                else capture.focusIdx = (capture.focusIdx + d + capture.slots.length) % capture.slots.length;
                break;
            }
            case Qt.Key_Up:
                capture.kbFocus = true;
                if (!capture.settingsOpen) { capture.settingsOpen = true; capture.sheetIdx = 0; capture.sheetFocus = true; }
                else if (!capture.sheetFocus) capture.sheetFocus = true;
                else capture.sheetIdx = Math.max(0, capture.sheetIdx - 1);
                break;
            case Qt.Key_Down:
                capture.kbFocus = true;
                if (!capture.sheetFocus) break;
                if (capture.sheetIdx >= capture.rows.length - 1) capture.sheetFocus = false;
                else capture.sheetIdx++;
                break;
            case Qt.Key_Tab:
                capture.kbFocus = true;
                capture.focusIdx = (capture.focusIdx + 2) % capture.slots.length;
                capture.sheetFocus = false;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                if (capture.sheetFocus) capture.bump(0);
                else capture.activate(capture.slots[capture.focusIdx]);
                break;
            case Qt.Key_1: capture.setMode("shot"); break;
            case Qt.Key_2: capture.setMode("rec"); break;
            case Qt.Key_S: capture.setMode("shot"); break;
            case Qt.Key_V: capture.setMode("rec"); break;
            case Qt.Key_R: capture.setSrc("region"); break;
            case Qt.Key_F: capture.setSrc("screen"); break;
            case Qt.Key_O: capture.settingsOpen = !capture.settingsOpen; break;
            default: return;
            }
            e.accepted = true;
        }
    }

    // Sliding panel — the background is the Frame bulge, so nothing here paints a surface.
    Item {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        // Centre within the frame's content region: the left bar is 56px, the right border 8px.
        anchors.horizontalCenterOffset: (56 - 8) / 2

        // Content margin > the bulge inset (16) so a ring of background frames the content.
        readonly property int pad: 26
        readonly property int botPad: 1 + Config.popFillet

        anchors.bottom: parent.bottom
        anchors.bottomMargin: capture.shown && !Capture.hidingForCapture ? 0 : (-height - 20)
        Behavior on anchors.bottomMargin { Anim { type: Anim.Spatial } }
        width: inner.width + pad * 2
        Behavior on width { Anim { type: Anim.Spatial } }
        height: inner.implicitHeight + pad + botPad
        Behavior on height { Anim { type: Anim.Spatial } }
        // The bulge is the body's background, so it has to be re-reported on every geometry
        // change: the slide, the width growing with a new segment, the sheet opening.
        onXChanged: capture.reportBox()
        onYChanged: capture.reportBox()
        onWidthChanged: capture.reportBox()
        onHeightChanged: capture.reportBox()
        // The capture path unpaints the panel outright instead of animating it away — a mid-slide
        // frame would otherwise end up in the screenshot.
        visible: !Capture.hidingForCapture
        MouseArea { anchors.fill: parent }   // swallow clicks on the panel

        ColumnLayout {
            id: inner
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: panel.botPad
            spacing: 12

            // --- Settings sheet: grows upward out of the row, on the same bulge ---
            ColumnLayout {
                id: sheet
                Layout.fillWidth: true
                Layout.preferredHeight: capture.settingsOpen && !Capture.active ? implicitHeight : 0
                Behavior on Layout.preferredHeight { Anim { type: Anim.Spatial } }
                opacity: capture.settingsOpen && !Capture.active ? 1 : 0
                Behavior on opacity { Anim { type: Anim.Effect } }
                clip: true
                spacing: 6

                Repeater {
                    model: capture.rows
                    Item {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 28
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            radius: 8
                            color: capture.kbFocus && capture.sheetFocus && capture.sheetIdx === index
                                   ? Config.accentContainer : "transparent"
                            Behavior on color { ColorAnim {} }
                        }
                        OptRow {
                            anchors.fill: parent
                            visible: modelData.kind === "opt"
                            label: modelData.label
                            values: modelData.values ?? []
                            labels: modelData.labels ?? null
                            current: Config[modelData.key]
                            onPicked: v => Config[modelData.key] = modelData.num ? Number(v) : v
                        }
                        SwRow {
                            anchors.fill: parent
                            visible: modelData.kind === "sw"
                            label: modelData.label
                            checked: Config[modelData.key] ?? false
                            onToggled: Config[modelData.key] = !Config[modelData.key]
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 1
                    color: Config.outlineVariant
                }
            }

            // --- The strip itself ---
            RowLayout {
                id: strip
                visible: !Capture.active
                spacing: 10

                CapTile {
                    icon: "screenshot_region"; label: "Screenshot"
                    on: capture.mode === "shot"
                    focused: capture.kbFocus && !capture.sheetFocus && capture.slots[capture.focusIdx] === "shot"
                    onPicked: capture.setMode("shot")
                }
                CapTile {
                    icon: "screen_record"; label: "Record"
                    on: capture.mode === "rec"
                    focused: capture.kbFocus && !capture.sheetFocus && capture.slots[capture.focusIdx] === "rec"
                    onPicked: capture.setMode("rec")
                }

                Rectangle {
                    Layout.leftMargin: 4; Layout.rightMargin: 4
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 1; implicitHeight: 44
                    color: Config.outlineVariant
                }

                CapTile {
                    icon: "monitor"; label: "Full screen"
                    on: capture.src === "screen"
                    focused: capture.kbFocus && !capture.sheetFocus && capture.slots[capture.focusIdx] === "screen"
                    onPicked: capture.setSrc("screen")
                }
                CapTile {
                    icon: "crop_free"; label: "Region"
                    on: capture.src === "region"
                    focused: capture.kbFocus && !capture.sheetFocus && capture.slots[capture.focusIdx] === "region"
                    onPicked: capture.setSrc("region")
                }

                Rectangle {
                    Layout.leftMargin: 4; Layout.rightMargin: 4
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 1; implicitHeight: 44
                    color: Config.outlineVariant
                }

                // Settings chip: click to unfold the sheet above the strip.
                Rectangle {
                    id: chip
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: chipRow.implicitWidth + 28
                    implicitHeight: 44
                    radius: 12
                    color: capture.settingsOpen ? Config.accentContainer : Config.container
                    Behavior on color { ColorAnim {} }
                    Rectangle {
                        anchors.fill: parent; radius: parent.radius; color: "transparent"
                        border.width: 2
                        border.color: capture.kbFocus && !capture.sheetFocus
                                      && capture.slots[capture.focusIdx] === "chip" ? Config.focusRing : "transparent"
                        Behavior on border.color { ColorAnim {} }
                    }
                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 8
                        MatIcon { text: "tune"; font.pixelSize: 17; color: Config.accent }
                        Text {
                            text: capture.mode === "rec" ? Capture.recSummary : Capture.shotSummary
                            color: Config.fg
                            font.family: Config.textFont; font.pixelSize: 11
                        }
                        MatIcon {
                            text: "expand_less"; font.pixelSize: 16; color: Config.dim
                            rotation: capture.settingsOpen ? 180 : 0
                            Behavior on rotation { Anim { type: Anim.SpatialFast } }
                        }
                    }
                    StateLayer { ovRadius: 12; tint: Config.fg; onTapped: capture.settingsOpen = !capture.settingsOpen }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 4
                    implicitWidth: goRow.implicitWidth + 34
                    implicitHeight: 44
                    radius: 12
                    color: capture.mode === "rec" ? Config.error : Config.accent
                    Behavior on color { ColorAnim {} }
                    Rectangle {
                        anchors.fill: parent; radius: parent.radius; color: "transparent"
                        border.width: 2
                        border.color: capture.kbFocus && !capture.sheetFocus
                                      && capture.slots[capture.focusIdx] === "go" ? Config.focusRing : "transparent"
                        Behavior on border.color { ColorAnim {} }
                    }
                    RowLayout {
                        id: goRow
                        anchors.centerIn: parent
                        spacing: 8
                        MatIcon {
                            text: capture.src === "region" ? "crop_free"
                                : (capture.mode === "rec" ? "fiber_manual_record" : "photo_camera")
                            font.pixelSize: 18; color: Config.accentText
                        }
                        // "Region" says what happens next — the panel goes and slurp asks for a
                        // rectangle. "Start recording" made that click look like a no-op.
                        Text {
                            text: capture.src === "region" ? "Select region"
                                : (capture.mode === "rec" ? "Start recording" : "Capture")
                            color: Config.accentText
                            font.family: Config.textFont; font.pixelSize: 12; font.bold: true
                        }
                    }
                    StateLayer { ovRadius: 12; tint: Config.accentText; onTapped: capture.go() }
                }
            }

            // --- Recording in progress: the strip becomes the transport ---
            RowLayout {
                visible: Capture.active
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                MatIcon {
                    text: Capture.paused ? "pause_circle" : "fiber_manual_record"
                    font.pixelSize: 22
                    color: Capture.paused ? Config.warning : Config.error
                }
                Text {
                    text: Capture.elapsedText
                    color: Config.fg
                    font.family: Config.textFont; font.pixelSize: 20; font.bold: true
                }
                Text {
                    text: (Capture.source === "region" ? "region" : "screen") + " · " + Capture.recSummary
                    color: Config.dim
                    font.family: Config.textFont; font.pixelSize: 11
                }
                Rectangle {
                    Layout.leftMargin: 4; Layout.rightMargin: 4
                    implicitWidth: 1; implicitHeight: 32
                    color: Config.outlineVariant
                }
                IconBtn {
                    implicitWidth: 40; implicitHeight: 40; iconSize: 20
                    icon: Capture.paused ? "play_arrow" : "pause"
                    tint: Config.warning
                    onClicked: Capture.togglePause()
                }
                IconBtn {
                    implicitWidth: 40; implicitHeight: 40; iconSize: 20
                    icon: "stop"
                    tint: Config.error
                    onClicked: { Capture.stop(); Shell.captureVisible = false; }
                }
            }
        }
    }
}
