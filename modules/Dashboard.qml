// Top dashboard (hover the top-centre edge): Dashboard (media + clock) / Performance / Notifications.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: dashWin
    required property var modelData
    screen: modelData
    anchors { top: true; left: true; right: true }
    // Fixed at the tallest the panel can get (Dashboard with a full mixer) + hover buffer: the
    // panel's own height animates per tab, and resizing the layer surface every frame to match
    // would be both expensive and visibly janky.
    implicitHeight: 560
    color: "transparent"
    // Span the full output width so window coords match the real screen, which is what the Frame's
    // SDF bulge is drawn in. (exclusiveZone: 0 would force Normal mode.)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top

    property bool dashOpen: false
    onDashOpenChanged: {
        if (dashOpen) dashCalendar.reset();  // back to the current month, and re-read "today"
        // Clear the IPC flag on the way out, so the keybind can reopen it.
        else Shell.dashboardVisible = false;
        // The configured tab is restored once the panel is off-screen (see dashPanel.onYChanged),
        // not here: switching on the way out made the dashboard flip tabs in your face — and now
        // that its height follows the tab, resize itself — before it had finished leaving.
        reportBox();
    }
    // Report the body rect so the Frame bulges the top border down into it: sides inset to match
    // the content padding, 18px above the body so the bulge fuses with the border.
    //
    // Driven off the panel's LIVE y with anim=false, so the bulge rides the slide 1:1. Reporting
    // the resting rect and letting the Frame ease it grew the box out of its top-LEFT corner —
    // the width unrolled rightward, which read as opening sideways.
    function reportBox() {
        // The panel keeps sliding for a moment after closing; by then a bottom popout may already
        // own the shared slot, so stop reporting once it is not ours.
        if (!dashOpen && PopoutState.owner !== "dashboard") return;
        // Inset LESS than the content margin (40), so a ring of background frames the content
        // on every side — the same 40/16 pair the launcher uses.
        const inset = 16;
        const x = dashWin.width / 2 - dashPanel.width / 2 + inset;
        // Fully back above the screen: the bulge has retracted into the top border, so drop it.
        if (dashPanel.y + dashPanel.height <= 0) { PopoutState.clear("dashboard"); return; }
        // Anchored top-centre so any easing the Frame does opens out of the centre, not the corner.
        PopoutState.setBox(x, dashPanel.y - 18, dashPanel.width - inset * 2,
                           dashPanel.height + 18, "dashboard", false, 0.5, 0.0);
    }
    // A bottom "flows-out" popout takes over the shared bulge slot, so close and yield to it, then
    // re-evaluate hover on its close so the Dashboard reopens under a resting cursor. Only the
    // launcher and capture panel qualify: Settings is a FloatingWindow with its own background and
    // never claims the slot — listing it here killed the Dashboard for as long as it existed.
    readonly property bool blocked: Shell.launcherVisible || Shell.captureVisible
    onBlockedChanged: dashUpdate()
    // Two hover trackers: the panel is an opaque sibling occluding the hot-zone's handler, so keep
    // the dashboard open while EITHER is hovered and close only when both are clear.
    property bool triggerHov: false
    property bool panelHov: false
    onTriggerHovChanged: dashUpdate()
    onPanelHovChanged: dashUpdate()
    function dashUpdate() {
        if (blocked) { dashCloseTimer.stop(); dashOpen = false; }
        else if (Shell.dashboardVisible || triggerHov || panelHov) { dashCloseTimer.stop(); dashOpen = true; }
        else dashCloseTimer.restart();
    }
    // Keyboard route in; the flag is cleared again in onDashOpenChanged above.
    Connections {
        target: Shell
        function onDashboardVisibleChanged() { dashWin.dashUpdate(); }
    }
    Timer { id: dashCloseTimer; interval: 0; onTriggered: dashWin.dashOpen = false }

    // One row of the audio mixer: a mute toggle, an optional stream name, the slider and a
    // percentage. The same row serves the mic, the master sink and every app, so the sliders
    // line up down the card instead of each control inventing its own geometry.
    component MixRow: RowLayout {
        id: mix
        property string icon
        property string name: ""            // apps show one; the fixed rows are named by their icon
        property real value: 0
        property color tint: Config.accent
        property bool off: false            // muted — icon, fill and percentage all dim together
        signal moved(real v)
        signal toggled()
        Layout.fillWidth: true
        spacing: 8
        IconBtn {
            implicitWidth: 24; implicitHeight: 24; iconSize: 15
            icon: mix.icon
            tint: mix.off ? Config.dim : mix.tint
            onClicked: mix.toggled()
        }
        Text {
            visible: mix.name.length > 0
            Layout.preferredWidth: 84
            text: mix.name
            textFormat: Text.PlainText   // a pipewire stream names itself
            color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
            elide: Text.ElideRight
        }
        HSlider {
            value: mix.value
            fill: mix.off ? Config.dim : mix.tint
            onMoved: v => mix.moved(v)
        }
        Text {
            Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight
            text: Math.round(mix.value * 100) + "%"
            color: Config.dim; font.family: Config.textFont; font.pixelSize: 10
        }
    }

    // One "label … value" row of the Performance readout. It hides itself when the source has
    // nothing to report (no GPU, no sensor), so the grid closes the gap instead of holding a
    // blank field.
    component PerfLine: RowLayout {
        id: line
        property string k
        property string v
        property string icon: ""
        property color tint: Config.dim
        visible: line.v.length > 0
        Layout.fillWidth: true
        spacing: 8
        MatIcon { visible: line.icon.length > 0; text: line.icon; font.pixelSize: 14; color: line.tint }
        Text { text: line.k; color: Config.dim; font.family: Config.textFont; font.pixelSize: 12 }
        Item { Layout.fillWidth: true }
        Text { text: line.v; color: Config.fg; font.family: Config.textFont; font.pixelSize: 12; font.bold: true }
    }

    // Hot-zone: a narrow top strip when closed, the whole panel plus a buffer when open. The
    // buffer is hysteresis, so movement near the edge doesn't flicker it.
    Item {
        id: dashHot
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: dashPanel.width + 80
        // Fixed size when open (NOT tied to the animating dashPanel.y), else the
        // hot-zone shrinks during the slide and the cursor falls out of it → closes.
        height: dashWin.dashOpen ? (dashPanel.height + 40) : 10

        // Tracks the trigger strip (and the hot-zone area above the panel).
        HoverHandler {
            onHoveredChanged: dashWin.triggerHov = hovered
        }
    }
    mask: Region { item: dashHot }

    Item {
        id: dashPanel
        anchors.horizontalCenter: parent.horizontalCenter
        width: 720
        // Height follows the ACTIVE tab, not the tallest one: the mixer makes Dashboard tall and
        // there is no reason for Performance and Notifications to inherit that and hang down the
        // screen. chrome is the panel's own padding plus the tab bar and its spacing.
        readonly property Item curTab: tab === 1 ? perfTab : tab === 2 ? notifTab : homeTab
        readonly property int chrome: 20 + 18 + 32 + 14
        height: dashPanel.chrome + Math.max(280, curTab.implicitHeight)
        // Eased so switching tabs slides the bottom edge instead of snapping it — but only while
        // the panel is up. Closed, the tab reset changes this height too, and easing it there is
        // what let the panel grow back down past the screen edge for a frame.
        Behavior on height { enabled: dashWin.dashOpen; Spatial {} }
        // The bulge is drawn from this rect, so a height change has to re-report like a move does.
        onHeightChanged: dashWin.reportBox()

        // Background is drawn by the Frame's SDF (it bulges the top border down into this
        // panel via PopoutState — one continuous surface, same as the bar popouts).

        property int tab: Config.dashTab
        // Gate the (relatively expensive) system-stats sampler on the Performance tab (index 1).
        readonly property bool perfShowing: dashWin.dashOpen && tab === 1
        onPerfShowingChanged: Sys.active = perfShowing
        // Parked off the WINDOW, not off its own height: the tab reset that follows a close also
        // changes that height, and a resting spot derived from it would drag the panel back into
        // view as the taller tab took over.
        y: dashWin.dashOpen ? 0 : -dashWin.implicitHeight
        Behavior on y { Spatial {} }
        // The bulge IS this panel's background, so it re-reports on every move.
        onYChanged: {
            dashWin.reportBox();
            // Parked far enough up that even the tallest tab stays hidden — only then does the tab
            // go back to the configured one. Resetting at close time showed the switch on the way
            // out; resetting at its own height showed the next tab's extra height.
            if (!dashWin.dashOpen && y + dashWin.implicitHeight <= 0) tab = Config.dashTab;
        }

        // Tracks the panel + all children (tabs/buttons); a parent HoverHandler is
        // not stolen by child MouseAreas, so hovering them keeps the panel open.
        HoverHandler {
            onHoveredChanged: dashWin.panelHov = hovered
        }

        property var now: new Date()
        property real mediaPos: 0   // polled media position (Mpris doesn't tick on its own)
        // Only tick while the dashboard is open — the clock/progress it drives aren't visible otherwise.
        Timer {
            interval: 1000; running: dashWin.dashOpen; repeat: true; triggeredOnStart: true
            onTriggered: { dashPanel.now = new Date(); dashPanel.mediaPos = Media.player?.position ?? 0; }
        }

        // Child MouseAreas (tabs/buttons/thumbnails) steal hover from the window's
        // MouseArea, so each of them also calls dashKeep()/dashRelease() to hold it open.
        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 20; anchors.bottomMargin: 18
            anchors.leftMargin: 40; anchors.rightMargin: 40   // matches the launcher's panel.pad
            spacing: 14

            // --- Tab bar (centered) ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Item { Layout.fillWidth: true }
                Repeater {
                    model: [ { i: 0, t: "Dashboard", ic: "dashboard" }, { i: 1, t: "Performance", ic: "speed" }, { i: 2, t: "Notifications", ic: "notifications" } ]
                    Rectangle {
                        id: tabBtn
                        required property var modelData
                        readonly property bool sel: dashPanel.tab === tabBtn.modelData.i
                        implicitWidth: tabRow.implicitWidth + 26; implicitHeight: 32; radius: 16
                        color: tabBtn.sel ? Config.accent : "transparent"
                        Behavior on color { ColorAnim {} }
                        RowLayout {
                            id: tabRow
                            anchors.centerIn: parent
                            spacing: 6
                            MatIcon { text: tabBtn.modelData.ic; font.pixelSize: 16; color: tabBtn.sel ? Config.accentText : Config.fg }
                            Text {
                                text: tabBtn.modelData.t
                                color: tabBtn.sel ? Config.accentText : Config.fg
                                font.family: Config.textFont; font.pixelSize: 13; font.bold: tabBtn.sel
                            }
                        }
                        StateLayer { ovRadius: 16; onTapped: dashPanel.tab = tabBtn.modelData.i }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            StackLayout {
                id: dashStack
                Layout.fillWidth: true; Layout.fillHeight: true
                currentIndex: dashPanel.tab

                // Fade + a small slide-up of the new tab's content on switch.
                transform: Translate { id: tabSlide }
                onCurrentIndexChanged: tabAnim.restart()
                ParallelAnimation {
                    id: tabAnim
                    NumberAnimation { target: dashStack; property: "opacity"; from: 0; to: 1
                                      duration: Motion.effectDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectCurve }
                    NumberAnimation { target: tabSlide; property: "y"; from: 10; to: 0
                                      duration: Motion.spatialDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve }
                }

                // --- Dashboard (media player + quick controls | clock + calendar) ---
                RowLayout {
                    id: homeTab
                    spacing: 12

                    // Left column: player on top, quick sliders and the recorder below it. The
                    // player takes the slack so the column's height is driven by the calendar.
                    ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        // The player gives up its slack to the mixer below, but only down to what
                        // its own content needs — it clips, so without this floor a couple of app
                        // rows would saw the cover art and the transport off the bottom. An
                        // implicit height doubles as the layout minimum and feeds the tab's own
                        // implicit height, which is what sizes the panel.
                        implicitHeight: mediaRow.implicitHeight + 32
                        radius: 22; color: Config.containerSoft
                        clip: true

                        // Request the audio spectrum only while this tab is on-screen and something plays.
                        Binding {
                            target: Cava; property: "wantMedia"
                            value: dashWin.dashOpen && dashPanel.tab === 0 && (Media.player?.isPlaying ?? false)
                        }
                        // Spectrum backdrop behind the player content.
                        Visualiser {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14 }
                            height: parent.height * 0.5
                            opacity: 0.20
                            visible: Media.player?.isPlaying ?? false
                        }

                        RowLayout {
                            id: mediaRow
                            anchors.fill: parent; anchors.margins: 16; spacing: 16
                            Rectangle {
                                Layout.preferredWidth: 96; Layout.preferredHeight: 96; Layout.alignment: Qt.AlignVCenter
                                radius: 14; color: Config.surface; clip: true
                                FadeImage {
                                    id: coverArt
                                    anchors.fill: parent
                                    source: Media.artUrl
                                    box: 96
                                    visible: ready
                                }
                                MatIcon { anchors.centerIn: parent; visible: !coverArt.ready; text: "music_note"; font.pixelSize: 40; color: Config.dim }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 3
                                // PlainText: MPRIS metadata is whatever the stream says it is.
                                Text {
                                    text: Media.player ? (Media.player.trackTitle || "Unknown") : "Nothing playing"
                                    textFormat: Text.PlainText
                                    color: Config.fg; font.family: Config.textFont; font.pixelSize: 17; font.bold: true
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                                Text {
                                    visible: Media.player !== null
                                    text: Media.player?.trackArtist ?? ""
                                    textFormat: Text.PlainText
                                    color: Config.dim; font.family: Config.textFont; font.pixelSize: 13
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                                RowLayout {
                                    Layout.topMargin: 10; spacing: 8
                                    IconBtn { icon: "skip_previous"; iconSize: 20; onClicked: Media.player?.previous() }
                                    IconBtn { icon: Media.player?.isPlaying ? "pause" : "play_arrow"; iconSize: 22; active: Media.player?.isPlaying ?? false; onClicked: Media.player?.togglePlaying() }
                                    IconBtn { icon: "skip_next"; iconSize: 20; onClicked: Media.player?.next() }
                                }

                                // Progress bar + times (click to seek).
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.topMargin: 8; spacing: 4
                                    visible: Media.player !== null && Media.trackLength > 0
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 5; radius: 3; color: Config.track
                                        Rectangle {
                                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width * (Media.trackLength > 0 ? Math.min(1, dashPanel.mediaPos / Media.trackLength) : 0)
                                            height: parent.height; radius: 3; color: Config.accent
                                            Behavior on width { Effect {} }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; anchors.topMargin: -6; anchors.bottomMargin: -6
                                            enabled: Media.player?.canSeek ?? false
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: e => {
                                                if (!Media.player || Media.trackLength <= 0)
                                                    return;
                                                const target = (e.x / width) * Media.trackLength;
                                                Media.player.position = target;
                                                dashPanel.mediaPos = target;   // reflect the seek without waiting a tick
                                            }
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        // Clamped: the reported position can run past a stale duration.
                                        Text { text: Shell.fmtTime(Math.min(dashPanel.mediaPos, Media.trackLength)); color: Config.dim; font.family: Config.textFont; font.pixelSize: 10 }
                                        Item { Layout.fillWidth: true }
                                        Text { text: Shell.fmtTime(Media.trackLength); color: Config.dim; font.family: Config.textFont; font.pixelSize: 10 }
                                    }
                                }
                            }
                        }
                    }

                    // Quick controls, in the order they get reached for: brightness, mic, master
                    // volume, then a slider per app that is playing. Each icon doubles as the mute
                    // toggle for its row.
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: quickCol.implicitHeight + 20
                        radius: 18; color: Config.containerSoft
                        Elevation { anchors.fill: parent; radius: parent.radius; z: -1; level: 1 }

                        ColumnLayout {
                            id: quickCol
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                      leftMargin: 12; rightMargin: 12 }
                            spacing: 6

                            // Brightness is DDC/CI over i2c — hidden entirely when no monitor answers.
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                visible: Brightness.available
                                MatIcon { Layout.preferredWidth: 24; text: "brightness_medium"; font.pixelSize: 16; color: Config.accent; horizontalAlignment: Text.AlignHCenter }
                                HSlider {
                                    value: Brightness.brightness / 100
                                    onMoved: v => Brightness.set(v * 100)
                                }
                                Text {
                                    Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight
                                    text: Math.round(Brightness.brightness) + "%"
                                    color: Config.dim; font.family: Config.textFont; font.pixelSize: 10
                                }
                            }

                            MixRow {
                                icon: Audio.sourceMuted ? "mic_off" : "mic"
                                tint: Config.tertiary
                                off: Audio.sourceMuted
                                value: Audio.sourceVolume
                                onMoved: v => Audio.setSourceVolume(v)
                                onToggled: Audio.toggleMic()
                            }

                            MixRow {
                                icon: Audio.muted ? "volume_off" : (Audio.volume > 0.5 ? "volume_up" : "volume_down")
                                off: Audio.muted
                                value: Audio.volume
                                onMoved: v => Audio.setVolume(v)
                                onToggled: Audio.toggleMute()
                            }

                            // Per-app volumes sit under the master they feed into, split off by a
                            // hairline. The card is back to three rows the moment nothing plays.
                            Rectangle {
                                Layout.fillWidth: true; Layout.topMargin: 2; Layout.bottomMargin: 2
                                visible: appMix.count > 0
                                implicitHeight: 1; color: Config.outline; opacity: 0.5
                            }

                            Flickable {
                                Layout.fillWidth: true
                                visible: appMix.count > 0
                                // Two rows tall at most: past that the list scrolls instead of
                                // growing the card into the player above it.
                                implicitHeight: Math.min(appCol.implicitHeight, 24 * 2 + 6)
                                contentHeight: appCol.implicitHeight
                                clip: true; boundsBehavior: Flickable.StopAtBounds

                                ColumnLayout {
                                    id: appCol
                                    width: parent.width
                                    spacing: 6
                                    Repeater {
                                        id: appMix
                                        model: Audio.playbackStreams
                                        MixRow {
                                            id: appRow
                                            required property var modelData
                                            icon: appRow.off ? "volume_off" : "graphic_eq"
                                            name: Audio.getStreamName(appRow.modelData)
                                            off: appRow.modelData?.audio?.muted ?? false
                                            value: appRow.modelData?.audio?.volume ?? 0
                                            onMoved: v => Audio.setStreamVolume(appRow.modelData, v)
                                            onToggled: Audio.setStreamMuted(appRow.modelData, !appRow.off)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Capture: idle it opens the capture panel, recording it becomes the transport
                    // (elapsed, pause, stop). Capture's state is event-driven, so this also shows
                    // a recording started from a keybind or adopted after a restart.
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: 12
                        color: Capture.active ? Config.errorContainer : Config.container
                        Behavior on color { ColorAnim {} }

                        // Idle: one wide button.
                        RowLayout {
                            anchors.centerIn: parent; spacing: 8
                            visible: !Capture.active
                            MatIcon { text: "screenshot_monitor"; font.pixelSize: 17; color: Config.accent }
                            Text {
                                text: "Screenshot & record"
                                color: Config.fg
                                font.family: Config.textFont; font.pixelSize: 12; font.bold: true
                            }
                        }
                        StateLayer {
                            ovRadius: 12; tint: Config.fg
                            enabled: !Capture.active
                            onTapped: { Shell.captureScreen = Capture.monitor(); Shell.captureVisible = true; }
                        }

                        // Recording: elapsed on the left, transport on the right.
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 6
                            visible: Capture.active
                            spacing: 8
                            MatIcon {
                                text: Capture.paused ? "pause_circle" : "fiber_manual_record"
                                font.pixelSize: 17
                                color: Capture.paused ? Config.warning : Config.error
                            }
                            Text {
                                text: Capture.elapsedText
                                color: Capture.paused ? Config.warning : Config.error
                                font.family: Config.textFont; font.pixelSize: 12; font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            IconBtn {
                                implicitWidth: 26; implicitHeight: 26; iconSize: 15
                                icon: Capture.paused ? "play_arrow" : "pause"
                                tint: Config.warning
                                onClicked: Capture.togglePause()
                            }
                            IconBtn {
                                implicitWidth: 26; implicitHeight: 26; iconSize: 15
                                icon: "stop"
                                tint: Config.error
                                onClicked: Capture.stop()
                            }
                        }
                    }

                    }   // end left column

                    // Right column: clock and calendar as separate cards. fillWidth must be spelled
                    // out — nested layouts default it to TRUE (plain Items to false), which would
                    // stretch this column and push the player one off the panel.
                    ColumnLayout {
                        Layout.fillWidth: false
                        Layout.preferredWidth: 214; Layout.fillHeight: true
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: clockCol.implicitHeight + 22
                            radius: 22; color: Config.containerSoft
                            Elevation { anchors.fill: parent; radius: parent.radius; z: -1; level: 1 }
                            ColumnLayout {
                                id: clockCol
                                anchors.centerIn: parent
                                spacing: 0
                                Text { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDateTime(dashPanel.now, "hh:mm"); color: Config.fg; font.family: Config.textFont; font.pixelSize: 34; font.bold: true }
                                Text { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDateTime(dashPanel.now, "dddd"); color: Config.accent; font.family: Config.textFont; font.pixelSize: 13; font.bold: true }
                                Text { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 1; text: Qt.formatDateTime(dashPanel.now, "d MMMM yyyy"); color: Config.dim; font.family: Config.textFont; font.pixelSize: 11 }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            implicitHeight: dashCalendar.implicitHeight + 24
                            radius: 22; color: Config.containerSoft
                            Elevation { anchors.fill: parent; radius: parent.radius; z: -1; level: 1 }
                            Calendar {
                                id: dashCalendar
                                anchors.centerIn: parent
                                width: parent.width - 24
                                cell: 24
                            }
                        }
                    }
                }

                // --- Performance ---
                // No cards here: one centred row of rings over a rule, with the absolute figures
                // as a two-column readout below. Cards stretched to fill left each ring floating
                // in its own empty box, which is what made the tab look pulled apart.
                ColumnLayout {
                    id: perfTab
                    spacing: 14

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 26
                        // Each gauge takes its own slot from the palette's data ramp: five rings in
                        // one accent were indistinguishable, and all five turning the same red said
                        // nothing about which was in trouble. They still converge under load.
                        Gauge { icon: "speed";           label: "CPU";  value: Sys.cpu;                    valueText: Math.round(Sys.cpu * 100) + "%"; tint: Config.severity(Sys.cpu, Config.series[0], 0.75, 0.85) }
                        Gauge { icon: "memory";          label: "RAM";  value: Sys.mem;                    valueText: Math.round(Sys.mem * 100) + "%"; tint: Config.severity(Sys.mem, Config.series[1], 0.8, 0.9) }
                        Gauge { icon: "developer_board"; label: "GPU";  value: Sys.gpu;                    valueText: Math.round(Sys.gpu * 100) + "%"; visible: Sys.hasGpu; tint: Config.severity(Sys.gpu, Config.series[2], 0.8, 0.9) }
                        Gauge { icon: "storage";         label: "Disk"; value: Sys.disk;                   valueText: Math.round(Sys.disk * 100) + "%"; tint: Config.severity(Sys.disk, Config.series[3], 0.8, 0.9) }
                        Gauge { icon: "thermostat";      label: "Temp"; value: Math.min(1, Sys.temp / 100); valueText: Sys.temp + "°"; tint: Config.severity(Sys.temp / 100, Config.series[4], 0.7, 0.8) }
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Config.outline; opacity: 0.6 }

                    // The figures each ring is derived from — the ring says "how full", these say
                    // "out of what". Rows drop out of the grid when their source is missing.
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2; columnSpacing: 40; rowSpacing: 7

                        PerfLine { k: "CPU load";   v: Shell.fmtPair(Sys.load, Sys.cores, "", 1) }
                        PerfLine { k: "Memory";     v: Shell.fmtPair(Sys.memUsedGb, Sys.memTotalGb, "GB", 1) }
                        PerfLine { k: "Disk";       v: Shell.fmtPair(Sys.diskUsedGb, Sys.diskTotalGb, "GB", 0) }
                        PerfLine { k: "GPU memory"; v: Sys.hasGpu ? Shell.fmtPair(Sys.vramUsedGb, Sys.vramTotalGb, "GB", 1) : "" }
                        PerfLine { k: "Uptime";     v: Sys.uptime }
                        PerfLine { k: "GPU temp";   v: Sys.hasGpu && Sys.gpuTemp > 0 ? Sys.gpuTemp + "°" : "" }
                        PerfLine { k: "Download";   v: Shell.fmtSpeed(Sys.down); icon: "south"; tint: Config.accent }
                        PerfLine { k: "Upload";     v: Shell.fmtSpeed(Sys.up);   icon: "north"; tint: Config.tertiary }
                    }
                }

                // --- Notifications ---
                ColumnLayout {
                    id: notifTab
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Recent"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 12 }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            implicitWidth: dndRow.implicitWidth + 18; implicitHeight: 28; radius: 8
                            color: Config.dnd ? Config.accent : "transparent"
                            border.width: Config.dnd ? 0 : 1
                            border.color: Config.outline
                            Behavior on color { ColorAnim {} }
                            RowLayout {
                                id: dndRow
                                anchors.centerIn: parent; spacing: 5
                                MatIcon { text: Config.dnd ? "notifications_off" : "notifications"; font.pixelSize: 15; color: Config.dnd ? Config.accentText : Config.dim }
                                Text { text: "DND"; color: Config.dnd ? Config.accentText : Config.dim; font.family: Config.textFont; font.pixelSize: 12 }
                            }
                            StateLayer { ovRadius: 8; tint: Config.dnd ? Config.accentText : Config.fg; onTapped: Config.dnd = !Config.dnd }
                        }
                        Rectangle {
                            visible: (Notifs.server.trackedNotifications?.values.length ?? 0) > 0
                            Layout.leftMargin: 6
                            implicitWidth: nclrRow.implicitWidth + 18; implicitHeight: 28; radius: 8
                            color: nclrMa.containsMouse ? Config.container : "transparent"
                            Behavior on color { ColorAnim {} }
                            RowLayout {
                                id: nclrRow
                                anchors.centerIn: parent; spacing: 5
                                MatIcon { text: "clear_all"; font.pixelSize: 15; color: Config.dim }
                                Text { text: "Clear all"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 12 }
                            }
                            MouseArea {
                                id: nclrMa
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { const ns = (Notifs.server.trackedNotifications?.values ?? []).slice(); ns.forEach(n => n.dismiss()); }
                            }
                        }
                    }
                    Text {
                        visible: (Notifs.server.trackedNotifications?.values.length ?? 0) === 0
                        Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 24
                        text: "No notifications"
                        color: Config.dim; font.family: Config.textFont; font.pixelSize: 13
                    }
                    Flickable {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        // Grows with the list up to a ceiling, then scrolls — the panel sizes
                        // itself off this tab, so an unbounded list would drag it down the screen.
                        implicitHeight: Math.min(dnlist.implicitHeight, 260)
                        contentHeight: dnlist.implicitHeight
                        clip: true; boundsBehavior: Flickable.StopAtBounds
                        ColumnLayout {
                            id: dnlist
                            width: parent.width
                            spacing: 12
                            // Group tracked notifications by app, preserving arrival order.
                            readonly property var groups: {
                                const g = {}, order = [];
                                for (const n of (Notifs.server.trackedNotifications?.values ?? [])) {
                                    const app = n.appName || "Other";
                                    if (!g[app]) { g[app] = []; order.push(app); }
                                    g[app].push(n);
                                }
                                return order.map(a => ({ app: a, items: g[a] }));
                            }
                            Repeater {
                                model: dnlist.groups
                                ColumnLayout {
                                    id: notifGroup
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 5
                                    // Group header: app name + count + clear-group.
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 6
                                        Text { text: notifGroup.modelData.app; textFormat: Text.PlainText; color: Config.accent; font.family: Config.textFont; font.pixelSize: 11; font.bold: true }
                                        Rectangle {
                                            implicitWidth: grpCnt.implicitWidth + 12; implicitHeight: 16; radius: 8; color: Config.container
                                            Text { id: grpCnt; anchors.centerIn: parent; text: notifGroup.modelData.items.length; color: Config.dim; font.family: Config.textFont; font.pixelSize: 10 }
                                        }
                                        Item { Layout.fillWidth: true }
                                        MatIcon {
                                            text: "close"; font.pixelSize: 14; color: Config.dim
                                            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                                                onClicked: notifGroup.modelData.items.slice().forEach(n => n.dismiss()) }
                                        }
                                    }
                                    Repeater {
                                        model: notifGroup.modelData.items
                                        Rectangle {
                                            id: notifItem
                                            required property var modelData
                                            // Shared with the toasts, so the same notification never shows
                                            // one thing here and another there.
                                            readonly property string art: Notifs.art(notifItem.modelData)
                                            Layout.fillWidth: true
                                            implicitHeight: Math.max(dni.implicitHeight, 34) + 18
                                            radius: 10; color: Config.container
                                            RowLayout {
                                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                                                spacing: 10
                                                // Transparent behind the image: Telegram's avatar is already a
                                                // circle with alpha corners, so a filled plate would show through.
                                                Rectangle {
                                                    Layout.preferredWidth: 34; Layout.preferredHeight: 34
                                                    Layout.alignment: Qt.AlignTop
                                                    radius: 10; color: "transparent"; clip: true
                                                    Image {
                                                        id: notifArt
                                                        anchors.fill: parent
                                                        source: notifItem.art
                                                        sourceSize.width: 68; sourceSize.height: 68
                                                        fillMode: Image.PreserveAspectFit
                                                        visible: status === Image.Ready
                                                    }
                                                    MatIcon {
                                                        anchors.centerIn: parent
                                                        visible: notifArt.status !== Image.Ready
                                                        text: Notifs.glyph(notifItem.modelData.appName ?? "",
                                                                           notifItem.modelData.summary ?? "")
                                                        font.pixelSize: 18; color: Config.dim
                                                    }
                                                }
                                                ColumnLayout {
                                                    id: dni
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    // PlainText: an app's own strings must never reach
                                                    // the rich-text engine — see Toasts.qml.
                                                    Text { text: notifItem.modelData.summary; textFormat: Text.PlainText; color: Config.fg; font.family: Config.textFont; font.pixelSize: 14; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                                    Text { visible: (notifItem.modelData.body ?? "").length > 0; text: notifItem.modelData.body; textFormat: Text.PlainText; color: Config.dim; font.family: Config.textFont; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                                                }
                                            }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: notifItem.modelData.dismiss() }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
