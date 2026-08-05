// Vertical status bar (left edge): launcher, workspaces, active window, tray, clock, volume,
// recording, brightness, kb layout, battery, network/bt/vpn, power. Hover-popouts grow out of it
// with a concave "cove" join — every one, tray menu included, is a transparent PopupWindow whose
// background is the Frame's SDF bulge (reportPopBox → PopoutState → modules/Frame.qml).
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs
import qs.components
import qs.services

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    // One popout at a time, with a small close delay so the cursor can travel into it.
    property string popout: ""
    Timer { id: popHideTimer; interval: 180; onTriggered: bar.popout = "" }
    // Clear the frame bulge only when SWITCHING popouts. Re-calling showPopout for the one
    // already open (the cursor entering its body fires the HoverHandler) must not clear it:
    // bar.popout wouldn't change, so nothing would re-report the box and the background would go.
    // All bar popouts claim the bulge under one owner id, so closing one drops only its own — a
    // tray menu fading out used to clear the box the Dashboard had just claimed.
    readonly property string bulgeOwner: "bar"
    function showPopout(name) { popHideTimer.stop(); if (bar.popout !== name) PopoutState.clear(bar.bulgeOwner); bar.popout = name; }
    function hidePopout() { popHideTimer.restart(); }

    // Report an open popout's body rect (screen px) so the Frame bulges the bar into it. Quickshell
    // centres the popup on its widget then clamps it on-screen; that clamp is replicated here so
    // the bulge tracks tall popouts too. `anim` false lands the bulge in the same frame, for a
    // popout that merely resized. `height` overrides popup.implicitHeight where that binding may
    // still be stale at report time (the tray menu).
    function reportPopBox(widget, popup, anim, height) {
        const gcy = widget.mapToItem(null, 0, widget.height / 2).y;   // widget center, screen y
        const ph = height === undefined ? popup.implicitHeight : height;
        const bh = ph - Config.popFillet * 2;                         // body height (minus fillets)
        const pf = Config.popFillet;
        // Skirt under the body: normally a full fillet so the SDF cove has room to curve back
        // into the bar. Where the screen edge already crowds the body — the power menu — that
        // skirt is dead space between the menu and the edge, so trade it for the bar's own 12px
        // margin and let the body reach down. The window height is unchanged; the padding just
        // moves from under the body to above it, so the window still lands flush at the edge.
        const bp = gcy + bh / 2 + pf > bar.height ? 12 : pf;
        if (popup.botPad !== undefined) popup.botPad = bp;
        let top = gcy - bh / 2;
        top = Math.max(pf, Math.min(top, bar.height - bh - bp));      // keep body on-screen
        // Where the bulge grows from and collapses back to, as a fraction of the box. Left edge
        // (0) is the bar; the vertical share is the WIDGET's centre, not the box's — once the
        // screen edge has clamped the body those differ, and the default (0,0) meant every popout
        // retracted towards the top of itself instead of into the icon it flowed out of.
        const ay = bh > 0 ? Math.max(0, Math.min(1, (gcy - top) / bh)) : 0.5;
        PopoutState.setBox(bar.implicitWidth - 18, top, popup.implicitWidth + 12, bh,
                           bar.bulgeOwner, anim, 0, ay);
    }

    // Which tray item's menu the shared tray-menu popout should show.
    property var trayMenuHandle: null
    property Item trayMenuAnchor: null

    // Session actions for the power popout, each on a 0.5s hold so a stray click can't reboot.
    readonly property var sessionActions: [
        { icon: "lock",               label: "Lock",      run: function() { Lock.locked = true; } },
        { icon: "logout",             label: "Log out",   run: function() { Quickshell.execDetached(["hyprctl", "dispatch", "exit"]); } },
        { icon: "restart_alt",        label: "Reboot",    run: function() { Quickshell.execDetached(["systemctl", "reboot"]); } },
        { icon: "power_settings_new", label: "Shut down", run: function() { Quickshell.execDetached(["systemctl", "poweroff"]); } }
    ]
    // Out of `sessionActions` on purpose: that array is the Repeater's model, so a palette
    // dependency there would rebuild all four delegates per theme change. Indexed in parallel
    // instead, so a switch only repaints them.
    readonly property var sessionTones: [Config.info, Config.warning, Config.success, Config.danger]

    // Keep-awake: inhibits idle/sleep while Shell.keepAwake is on.
    IdleInhibitor { window: bar; enabled: Shell.keepAwake }

    // Fullscreen on THIS output's current workspace, not anywhere in the session: a video going
    // fullscreen on another workspace used to take this bar away and hand back its exclusive zone.
    readonly property bool fullscreenHere: Hypr.fullscreenOn(bar.modelData?.name ?? "")

    anchors { top: true; left: true; bottom: true }
    implicitWidth: 56
    color: "transparent"
    // Never toggle `visible` on fullscreen: remapping the layer surface races with the Frame's own
    // remap and the bar routinely fails to reappear (QML reports visible=true, surface unmapped).
    // Keep it mapped — drop the exclusive zone, hide the content, empty the input region.
    visible: true
    exclusiveZone: bar.fullscreenHere ? 0 : implicitWidth
    mask: bar.fullscreenHere ? passthrough : null
    Region { id: passthrough }   // empty region → input passes through under fullscreen

    // Background is drawn by the Frame (one continuous SDF surface); this stays transparent.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        visible: !bar.fullscreenHere   // hide widgets under a fullscreen window

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 10

        // --- Arch logo (top) — opens the app launcher ---
        ArchLogo {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 22
            implicitHeight: 22
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Shell.launcherVisible = !Shell.launcherVisible
            }
        }

        // --- Workspaces: fixed slots + sliding active indicator ---
        Item {
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barWorkspaces
            readonly property int slot: 28
            readonly property int gap: 6
            readonly property int pitch: slot + gap
            readonly property int pill: 42          // match the network pill width
            readonly property int padV: 7           // vertical padding inside the pill
            implicitWidth: pill
            implicitHeight: Hypr.maxWs * slot + (Hypr.maxWs - 1) * gap + padV * 2

            // Scroll over the workspaces to switch (up = previous, down = next).
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => Hyprland.dispatch(e.angleDelta.y > 0 ? "workspace e-1" : "workspace e+1")
            }

            // Pill background grouping the whole workspace column (matches the network pill below).
            Rectangle {
                anchors.fill: parent
                radius: 16
                color: Config.containerSoft
            }

            // Sliding coral indicator behind the active workspace.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.slot; height: parent.slot; radius: parent.slot / 2
                color: Config.accent
                y: parent.padV + (Hypr.activeWs - 1) * parent.pitch
                Behavior on y { SpatialFast {} }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.padV
                spacing: parent.gap
                Repeater {
                    model: Hypr.maxWs
                    Rectangle {
                        id: wsSlot
                        required property int index
                        readonly property int ws: index + 1
                        readonly property bool active: ws === Hypr.activeWs
                        readonly property var wins: Hypr.wsWindows(ws)
                        readonly property bool occupied: wins.length > 0 || Hypr.wsOccupied(ws)
                        readonly property bool urgent: !!Hypr.urgentWs[ws] && !active
                        // Workspace number as a Roman numeral (I, II, III … up to ~X).
                        readonly property string roman: {
                            let n = ws, r = "";
                            const m = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
                            for (const p of m) while (n >= p[0]) { r += p[1]; n -= p[0]; }
                            return r;
                        }
                        width: 28; height: 28; radius: 14
                        color: "transparent"

                        // Roman numeral of the workspace number when occupied; a small dot when empty.
                        Text {
                            anchors.centerIn: parent
                            visible: wsSlot.occupied
                            text: wsSlot.roman
                            font.family: Config.textFont; font.pixelSize: 13; font.bold: true
                            color: wsSlot.active ? Config.accentText : (wsSlot.urgent ? Config.error : Config.fg)
                            // Pulse while requesting attention.
                            SequentialAnimation on opacity {
                                running: wsSlot.urgent; loops: Animation.Infinite
                                NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            visible: !wsSlot.occupied
                            width: wsSlot.active ? 7 : 5; height: width; radius: width / 2
                            color: wsSlot.active ? Config.accentText : (wsSlot.urgent ? Config.error : Config.dim)
                            Behavior on width { SpatialFast {} }
                            Behavior on color { ColorAnim {} }
                        }
                        StateLayer { ovRadius: 14; onTapped: Hyprland.dispatch("workspace " + parent.ws) }
                    }
                }
            }
        }


        Item { Layout.fillHeight: true }  // spacer

        // --- Active window (icon + vertical title) ---
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barWindow && Hypr.activeClass !== ""
            spacing: 10

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 26; implicitHeight: 26
                FadeImage {
                    id: activeIconImg
                    anchors.fill: parent
                    box: 26
                    fillMode: Image.PreserveAspectFit
                    source: Hypr.activeEntry?.icon ? Quickshell.iconPath(Hypr.activeEntry.icon, true) : ""
                }
                MatIcon {
                    anchors.centerIn: parent
                    visible: !activeIconImg.ready
                    text: "web_asset"
                    font.pixelSize: 20
                    color: Config.dim
                }
            }

            // Title written sideways (rotated 90°).
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: awTitle.contentHeight
                implicitHeight: Math.min(240, awTitle.contentWidth)
                clip: true
                Text {
                    id: awTitle
                    anchors.centerIn: parent
                    rotation: -90
                    text: Hypr.activeTitle || Hypr.activeClass
                    // A window title is set by the window — a web page picks its own through
                    // <title>. AutoText would hand that to the rich-text engine, which resolves
                    // remote <img> URLs; PlainText is the only safe reading of foreign text.
                    textFormat: Text.PlainText
                    color: Config.dim
                    font.family: Config.textFont; font.pixelSize: 12
                }
            }
        }

        Item { Layout.fillHeight: true }  // spacer

        // --- System tray ---
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barTray
            spacing: 10
            Repeater {
                model: SystemTray.items
                Item {
                    id: trayItem
                    required property var modelData
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 18; Layout.preferredHeight: 18
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -5; radius: 8
                        color: trayMa.containsMouse ? Config.container : "transparent"
                        Behavior on color { ColorAnim {} }
                    }
                    Image {
                        id: trayIcon
                        anchors.fill: parent
                        sourceSize: Qt.size(18, 18)
                        source: trayItem.modelData.icon
                    }
                    function openMenu() {
                        if (!trayItem.modelData.hasMenu) return;
                        // Idempotent: reassigning the handle reloads the D-Bus menu, which briefly
                        // empties it and thrashes the bulge.
                        if (bar.popout === "traymenu" && bar.trayMenuAnchor === trayIcon) {
                            bar.showPopout("traymenu");
                            return;
                        }
                        bar.trayMenuHandle = trayItem.modelData.menu;
                        bar.trayMenuAnchor = trayIcon;
                        bar.showPopout("traymenu");
                    }
                    MouseArea {
                        id: trayMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.RightButton | Qt.MiddleButton
                        // Hover shows the app's menu; it closes on hover-out like every other popout.
                        onEntered: trayItem.openMenu()
                        onExited: bar.hidePopout()
                        onClicked: e => {
                            if (e.button === Qt.MiddleButton) trayItem.modelData.secondaryActivate();
                            else if (e.button === Qt.RightButton) trayItem.openMenu();
                        }
                    }
                }
            }
        }

        // --- Clock (vertical): day / date / time ---
        Item {
            id: clockWidget
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barClock
            Layout.topMargin: 4
            implicitWidth: clockCol.implicitWidth
            implicitHeight: clockCol.implicitHeight

            ColumnLayout {
                id: clockCol
                anchors.centerIn: parent
                spacing: 0
                property var now: new Date()
                // Once a minute, aligned to :00 — the readout is day/date/hh/mm with no seconds
                // anywhere, so a 1s tick relaid out and repainted the bar sixty times per visible
                // change. See components/DesktopClock.qml for the same pattern.
                Timer {
                    id: barMinuteTick
                    interval: 60000 - (Date.now() % 60000)
                    running: true
                    onTriggered: {
                        clockCol.now = new Date();
                        barMinuteTick.interval = 60000 - (Date.now() % 60000);
                        barMinuteTick.restart();
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clockCol.now, "ddd")
                    font.family: Config.textFont; font.pixelSize: 10; color: Config.dim
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clockCol.now, "d")
                    font.family: Config.textFont; font.pixelSize: 13; font.bold: true; color: Config.tertiary
                }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4; Layout.bottomMargin: 4
                    implicitWidth: 18; implicitHeight: 1; color: Config.container
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    // Qt reads "hh" as 00–23 unless an AP field is present, so 12-hour mode asks
                    // for one and drops it into its own line below.
                    text: Config.barClock12h ? Qt.formatDateTime(clockCol.now, "hh AP").split(" ")[0]
                                             : Qt.formatDateTime(clockCol.now, "hh")
                    font.family: Config.textFont; font.pixelSize: 17; font.bold: true; color: Config.tertiary
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clockCol.now, "mm")
                    font.family: Config.textFont; font.pixelSize: 17; color: Config.tertiary
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: Config.barClock12h
                    text: Qt.formatDateTime(clockCol.now, "AP")
                    font.family: Config.textFont; font.pixelSize: 9; color: Config.dim
                }
            }
        }


        // --- Volume (standalone: scroll to change, click to mute, hover for slider) ---
        Item {
            id: volWidget
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barVolume
            implicitWidth: 40
            implicitHeight: volStat.implicitHeight
            Rectangle {
                anchors.fill: parent; radius: 9
                color: volMa.containsMouse ? Config.container : "transparent"
                Behavior on color { ColorAnim {} }
            }
            Stat {
                id: volStat
                anchors.horizontalCenter: parent.horizontalCenter
                icon: Audio.muted ? "volume_off" : (Audio.volume > 0.5 ? "volume_up" : "volume_down")
                value: Audio.muted ? "—" : Math.round(Audio.volume * 100) + ""
                tint: Audio.muted ? Config.dim : Config.fg
            }
            MouseArea {
                id: volMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: bar.showPopout("volume")
                onExited: bar.hidePopout()
                onClicked: Audio.toggleMute()
                onWheel: e => Audio.addVolume(e.angleDelta.y > 0 ? 0.05 : -0.05)
            }
        }

        // --- Recording indicator (only while recording: elapsed time, hover for pause/stop) ---
        Item {
            id: recWidget
            Layout.alignment: Qt.AlignHCenter
            visible: Capture.active
            Layout.preferredHeight: Capture.active ? implicitHeight : 0
            implicitWidth: 40
            implicitHeight: recStat.implicitHeight
            Rectangle {
                anchors.fill: parent; radius: 9
                color: recMa.containsMouse ? Config.container : "transparent"
                Behavior on color { ColorAnim {} }
            }
            Stat {
                id: recStat
                anchors.horizontalCenter: parent.horizontalCenter
                // Muxing after a stop is neither recording nor paused: a blinking red dot over a
                // still-ticking clock would claim the capture is going when it is being written out.
                icon: Capture.stopping ? "save" : (Capture.paused ? "pause_circle" : "fiber_manual_record")
                value: Capture.elapsedText
                tint: Capture.stopping ? Config.dim : (Capture.paused ? Config.warning : Config.error)
                // Pulse only while capturing, so a paused recording reads as held. The value source
                // keeps the opacity it stopped on, so pausing must reset it to 1.
                SequentialAnimation on opacity {
                    running: Capture.state === "recording" && !Capture.stopping; loops: Animation.Infinite
                    onRunningChanged: if (!running) recStat.opacity = 1
                    NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }
            }
            MouseArea {
                id: recMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: bar.showPopout("rec")
                onExited: bar.hidePopout()
                onClicked: Capture.togglePause()
            }
        }

        // --- Game mode indicator (only shown while active; click to turn off) ---
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            visible: GameMode.enabled
            Layout.preferredHeight: GameMode.enabled ? implicitHeight : 0
            implicitWidth: 30; implicitHeight: 30; radius: 9
            color: "transparent"
            MatIcon {
                anchors.centerIn: parent
                text: "sports_esports"
                font.pixelSize: 16
                color: Config.accent
            }
            StateLayer { ovRadius: 9; tint: Config.accent; onTapped: GameMode.toggle() }
        }

        // --- Brightness (standalone: scroll to change, hover for slider; DDC/CI monitor) ---
        Item {
            id: briWidget
            visible: Config.barBrightness && Brightness.available
            Layout.preferredHeight: briWidget.visible ? implicitHeight : 0
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 40
            implicitHeight: briStat.implicitHeight
            Rectangle {
                anchors.fill: parent; radius: 9
                color: briMa.containsMouse ? Config.container : "transparent"
                Behavior on color { ColorAnim {} }
            }
            Stat {
                id: briStat
                anchors.horizontalCenter: parent.horizontalCenter
                icon: "brightness_medium"
                value: Brightness.brightness + ""
                tint: Config.fg
            }
            MouseArea {
                id: briMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: bar.showPopout("brightness")
                onExited: bar.hidePopout()
                onWheel: e => Brightness.set(Brightness.brightness + (e.angleDelta.y > 0 ? 5 : -5))
            }
        }

        // --- Keyboard layout (standalone, click to switch) ---
        Item {
            id: kbWidget
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barKeyboard
            implicitWidth: kbStat.implicitWidth
            implicitHeight: kbStat.implicitHeight
            Rectangle {
                anchors.fill: parent; anchors.margins: -4; radius: 9
                color: kbMa.containsMouse ? Config.container : "transparent"
                Behavior on color { ColorAnim {} }
            }
            Stat { id: kbStat; anchors.centerIn: parent; icon: "keyboard"; value: Hypr.kbLayout; tint: Config.fg }
            MouseArea {
                id: kbMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", Hypr.kbDevice || "all", "next"])
            }
        }

        // --- Battery (laptops only) ---
        Stat {
            id: batWidget
            visible: Config.barBattery && Bat.has
            Layout.preferredHeight: batWidget.visible ? implicitHeight : 0
            icon: Bat.charging ? "battery_charging_full" : "battery_full"
            value: Bat.percent + ""
            tint: Bat.percent <= 15 ? Config.error : (Bat.percent <= 30 ? Config.warning : Config.tertiary)
        }

        // --- Controls pill: network / bluetooth / VPN ---
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barControls
            implicitWidth: 42
            implicitHeight: ctrlCol.implicitHeight + 12
            radius: 16
            // Fade the group background while its popout is open, so the coves blend into the
            // plain bar instead of clipping the pill.
            readonly property bool popActive: bar.popout === "network" || bar.popout === "bluetooth" || bar.popout === "vpn"
            color: popActive ? "transparent" : Config.containerSoft
            Behavior on color { ColorAnim {} }
            ColumnLayout {
                id: ctrlCol
                anchors.centerIn: parent
                spacing: 8

                // Network: one icon for whichever link actually carries traffic — wired when it
                // owns the default route (or is the only one up), else the Wi-Fi signal. The
                // popout below lists both when they are up together.
                IconBtn {
                    id: netWidget
                    icon: Net.ethernetUp && (Net.ethernetIsDefault || !Net.wifiUp) ? "settings_ethernet"
                        : (!Net.wifiOn ? "wifi_off" : (Net.wifiUp ? Net.netIcon(Net.wifiSignal) : "wifi_find"))
                    tint: Net.netUp ? Config.accent : Config.dim
                    onClicked: Net.toggleWifi()
                    onHoverIn: { bar.showPopout("network"); Net.scan(); }
                    onHoverOut: bar.hidePopout()
                }
                // Bluetooth (click toggles power via bluetoothctl, hover for devices)
                IconBtn {
                    id: btWidget
                    icon: !Bt.enabled ? "bluetooth_disabled" : (Bt.connected ? "bluetooth_connected" : "bluetooth")
                    tint: Bt.connected ? Config.accent : (Bt.enabled ? Config.fg : Config.dim)
                    onClicked: Bt.toggle()
                    onHoverIn: bar.showPopout("bluetooth")
                    onHoverOut: bar.hidePopout()
                }
                // VPN (hover for the profile list)
                IconBtn {
                    id: vpnWidget
                    visible: Net.hasVpn
                    Layout.preferredHeight: Net.hasVpn ? implicitHeight : 0
                    icon: Net.vpnActive ? "vpn_lock" : "vpn_key_off"
                    tint: Net.vpnActive ? Config.accent : Config.dim
                    onHoverIn: bar.showPopout("vpn")
                    onHoverOut: bar.hidePopout()
                }
            }
        }

        // --- Power (bottom) — hover (or click) opens the session popout ---
        Rectangle {
            id: powerWidget
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            implicitWidth: 34; implicitHeight: 34; radius: 10
            color: powerMa.containsMouse ? Config.container : "transparent"
            Behavior on color { ColorAnim {} }
            MatIcon {
                anchors.centerIn: parent
                text: "power_settings_new"
                color: Config.error
            }
            MouseArea {
                id: powerMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Hover-opened like the rest; the click stays so tapping the icon opens it too.
                onEntered: bar.showPopout("power")
                onExited: bar.hidePopout()
                onClicked: bar.showPopout("power")
            }
        }
    }
    }

    // --- Volume popout: vertical slider + mute ---
    PopupWindow {
        id: volPop
        anchor.window: bar
        anchor.item: volWidget
        anchor.edges: Edges.Right
        anchor.gravity: Edges.Right
        // Slide, never flip — the default adjustment lets a popout too tall for the room below its
        // widget jump to the other side of it, which threw the power menu (bottom of the bar) up
        // near the top of the screen. Sliding keeps it centred on the widget as far as the screen
        // allows, then pins it to the edge — exactly what reportPopBox's clamp already draws.
        anchor.adjustment: PopupAdjustment.Slide
        anchor.margins.left: -2           // sit flush against the bar edge
        readonly property bool shown: bar.popout === "volume"
        visible: shown || volBody.opacity > 0.01   // stay mapped through the fade-out
        implicitWidth: 64
        implicitHeight: 220 + Config.popFillet * 2
        property real botPad: Config.popFillet   // set by reportPopBox when the screen edge crowds the body
        color: "transparent"

        // Bulge the bar into this popout via the Frame's SDF (see bar.reportPopBox).
        onShownChanged: { if (shown) bar.reportPopBox(volWidget, volPop); else if (bar.popout === "") PopoutState.clear(bar.bulgeOwner); }

        Item {
            id: volBody
            anchors.fill: parent
            opacity: volPop.shown ? 1 : 0
            Behavior on opacity { Anim { type: Anim.Effect } }
            transform: Translate { x: volPop.shown ? 0 : -14; Behavior on x { Anim { type: Anim.Spatial } } }

            HoverHandler {
                onHoveredChanged: hovered ? bar.showPopout("volume") : bar.hidePopout()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                anchors.topMargin: 12 + Config.popFillet * 2 - volPop.botPad
                anchors.bottomMargin: 12 + volPop.botPad
                spacing: 10

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Audio.muted ? "muted" : Math.round(Audio.volume * 100) + "%"
                    color: Config.fg
                    font.family: Config.textFont; font.pixelSize: 12; font.bold: true
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: true
                    implicitWidth: 10
                    radius: 5
                    color: Config.track
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.height * Math.min(1, Audio.volume)
                        radius: 5
                        color: Audio.muted ? Config.dim : Config.accent
                    }
                    MouseArea {
                        anchors.fill: parent
                        function setVol(y) { Audio.setVolume(1 - y / height); }
                        onPressed: e => setVol(e.y)
                        onPositionChanged: e => setVol(e.y)
                    }
                }

                MatIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: Audio.muted ? "volume_off" : "volume_up"
                    color: Audio.muted ? Config.dim : Config.fg
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.toggleMute()
                    }
                }
            }
        }
    }

    // --- Recording popout: elapsed time + pause/stop ---
    PopupWindow {
        id: recPop
        anchor.window: bar
        anchor.item: recWidget
        anchor.edges: Edges.Right
        anchor.gravity: Edges.Right
        anchor.adjustment: PopupAdjustment.Slide
        anchor.margins.left: -2
        // `stopping`, not just `active`: pressing stop has to close this pane at once, and the
        // recorder can spend seconds muxing before `active` finally clears.
        readonly property bool shown: bar.popout === "rec" && Capture.active && !Capture.stopping
        visible: shown || recBody.opacity > 0.01
        implicitWidth: 150
        implicitHeight: 128 + Config.popFillet * 2
        property real botPad: Config.popFillet   // set by reportPopBox when the screen edge crowds the body
        color: "transparent"

        onShownChanged: {
            if (shown) { bar.reportPopBox(recWidget, recPop); return; }
            // Stopping the recording takes the whole widget away, so the hover-out that closes
            // every other popout never arrives — bar.popout would stay "rec" and the frame bulge
            // would keep painting an empty pane. Drop it here instead of waiting for a pointer
            // event that cannot happen.
            if (bar.popout === "rec") bar.popout = "";
            if (bar.popout === "") PopoutState.clear(bar.bulgeOwner);
        }

        Item {
            id: recBody
            anchors.fill: parent
            opacity: recPop.shown ? 1 : 0
            Behavior on opacity { Anim { type: Anim.Effect } }
            transform: Translate { x: recPop.shown ? 0 : -14; Behavior on x { Anim { type: Anim.Spatial } } }

            HoverHandler { onHoveredChanged: hovered ? bar.showPopout("rec") : bar.hidePopout() }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                anchors.topMargin: 12 + Config.popFillet * 2 - recPop.botPad
                anchors.bottomMargin: 12 + recPop.botPad
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Capture.elapsedText
                    color: Capture.paused ? Config.warning : Config.error
                    font.family: Config.textFont; font.pixelSize: 20; font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: (Capture.paused ? "paused · " : "") + (Capture.source === "region" ? "region" : "screen") + " · " + Config.recFormat
                    color: Config.dim
                    font.family: Config.textFont; font.pixelSize: 10
                    elide: Text.ElideRight
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    spacing: 8
                    IconBtn {
                        icon: Capture.paused ? "play_arrow" : "pause"
                        tint: Config.warning
                        onClicked: Capture.togglePause()
                    }
                    // Stopping saves the file rather than destroying anything, so no hold-to-confirm.
                    IconBtn {
                        icon: "stop"
                        tint: Config.error
                        onClicked: Capture.stop()
                    }
                }
            }
        }
    }

    // --- Brightness popout: vertical slider (DDC/CI) ---
    PopupWindow {
        id: briPop
        anchor.window: bar
        anchor.item: briWidget
        anchor.edges: Edges.Right
        anchor.gravity: Edges.Right
        anchor.adjustment: PopupAdjustment.Slide
        anchor.margins.left: -2           // sit flush against the bar edge
        readonly property bool shown: bar.popout === "brightness"
        visible: shown || briBody.opacity > 0.01   // stay mapped through the fade-out
        implicitWidth: 64
        implicitHeight: 220 + Config.popFillet * 2
        property real botPad: Config.popFillet   // set by reportPopBox when the screen edge crowds the body
        color: "transparent"

        // Bulge the bar into this popout via the Frame's SDF (see bar.reportPopBox).
        onShownChanged: { if (shown) bar.reportPopBox(briWidget, briPop); else if (bar.popout === "") PopoutState.clear(bar.bulgeOwner); }

        Item {
            id: briBody
            anchors.fill: parent
            opacity: briPop.shown ? 1 : 0
            Behavior on opacity { Anim { type: Anim.Effect } }
            transform: Translate { x: briPop.shown ? 0 : -14; Behavior on x { Anim { type: Anim.Spatial } } }
            HoverHandler {
                onHoveredChanged: hovered ? bar.showPopout("brightness") : bar.hidePopout()
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                anchors.topMargin: 12 + Config.popFillet * 2 - briPop.botPad
                anchors.bottomMargin: 12 + briPop.botPad
                spacing: 10

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Brightness.brightness + "%"
                    color: Config.fg
                    font.family: Config.textFont; font.pixelSize: 12; font.bold: true
                }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: true
                    implicitWidth: 10
                    radius: 5
                    color: Config.track
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.height * (Brightness.brightness / 100)
                        radius: 5
                        color: Config.accent
                    }
                    MouseArea {
                        anchors.fill: parent
                        function setBri(y) { Brightness.set((1 - y / height) * 100); }
                        onPressed: e => setBri(e.y)
                        onPositionChanged: e => setBri(e.y)
                    }
                }
                MatIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "brightness_medium"
                    color: Config.fg
                }
            }
        }
    }

    // --- Network popout: Wi-Fi toggle + network list ---
    PopupWindow {
        anchor.window: bar
        anchor.item: netWidget
        anchor.edges: Edges.Right
        anchor.gravity: Edges.Right
        anchor.adjustment: PopupAdjustment.Slide
        anchor.margins.left: -2           // sit flush against the bar edge
        id: netPop
        readonly property bool shown: bar.popout === "network"
        visible: shown || netBody.opacity > 0.01   // stay mapped through the fade-out
        implicitWidth: 288
        implicitHeight: netCol.implicitHeight + 28 + Config.popFillet * 2
        property real botPad: Config.popFillet   // set by reportPopBox when the screen edge crowds the body
        color: "transparent"

        // Bulge the bar into this popout via the Frame's SDF (see bar.reportPopBox).
        onShownChanged: { if (shown) bar.reportPopBox(netWidget, netPop); else if (bar.popout === "") PopoutState.clear(bar.bulgeOwner); }
        onImplicitHeightChanged: if (shown) bar.reportPopBox(netWidget, netPop);

        Item {
            id: netBody
            anchors.fill: parent
            opacity: netPop.shown ? 1 : 0
            Behavior on opacity { Anim { type: Anim.Effect } }
            transform: Translate { x: netPop.shown ? 0 : -14; Behavior on x { Anim { type: Anim.Spatial } } }
            HoverHandler {
                onHoveredChanged: hovered ? bar.showPopout("network") : bar.hidePopout()
            }
            ColumnLayout {
                id: netCol
                anchors { top: parent.top; left: parent.left; right: parent.right
                          topMargin: 14 + Config.popFillet * 2 - netPop.botPad; leftMargin: 16; rightMargin: 16 }
                spacing: 8

                Text { text: "Wireless"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 15; font.bold: true }

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    Text { text: "Enabled"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 13; Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: 42; implicitHeight: 24; radius: 12
                        color: Net.wifiOn ? Config.accent : Config.switchTrackOff
                        Behavior on color { ColorAnim {} }
                        Rectangle {
                            width: 18; height: 18; radius: 9
                            color: Net.wifiOn ? Config.accentText : Config.dim
                            anchors.verticalCenter: parent.verticalCenter
                            x: Net.wifiOn ? parent.width - width - 3 : 3
                            Behavior on x { SpatialFast {} }
                            Behavior on color { ColorAnim {} }
                        }
                        StateLayer { ovRadius: 12; onTapped: Net.toggleWifi() }
                    }
                }

                // Wired links — one line each, naming the profile and interface so two ports
                // are told apart, and marking whichever one owns the default route.
                Repeater {
                    model: Net.ethernetLinks.filter(l => l.stateCode >= 40)
                    RowLayout {
                        id: ethItem
                        required property var modelData
                        Layout.fillWidth: true; Layout.topMargin: 2; spacing: 8
                        readonly property bool primary: ethItem.modelData.isDefault
                        MatIcon {
                            text: "cable"; font.pixelSize: 17
                            color: ethItem.primary ? Config.accent : Config.fg
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text {
                                text: ethItem.modelData.connection || "Ethernet"
                                textFormat: Text.PlainText
                                color: ethItem.primary ? Config.accent : Config.fg
                                font.family: Config.textFont; font.pixelSize: 12; font.bold: true
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                text: ethItem.modelData.device
                                    + (ethItem.modelData.ip4 ? " · " + ethItem.modelData.ip4.split("/")[0] : "")
                                textFormat: Text.PlainText
                                color: Config.dim; font.family: Config.textFont; font.pixelSize: 10
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                        }
                        Text {
                            visible: ethItem.primary
                            text: "primary"; color: Config.accent
                            font.family: Config.textFont; font.pixelSize: 10
                        }
                    }
                }

                Text {
                    Layout.topMargin: 2
                    text: Net.wifiOn ? (Net.wifiScan.length + " networks available") : "Wi-Fi is off"
                    color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                }

                // Network list, with per-item connect button + ripple. Net.wifiScan is already
                // active-first then strongest and already capped at 8, so re-sorting here only
                // built a second array.
                //
                // ScriptModel, not the bare array: every scan produces fresh objects, and a plain
                // array model destroys and rebuilds all eight delegates on each one — losing hover,
                // ripple and any press in flight. Keyed on the ssid, ScriptModel diffs instead, so
                // a row whose signal moved is updated in place and only real arrivals and
                // departures touch the delegates. Same for the two lists below.
                Repeater {
                    model: ScriptModel {
                        objectProp: "ssid"
                        values: Net.wifiOn ? Net.wifiScan : []
                    }
                    RowLayout {
                        id: netItem
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        MatIcon { text: Net.netIcon(netItem.modelData.signal); font.pixelSize: 17; color: netItem.modelData.active ? Config.accent : Config.dim }
                        MatIcon { visible: netItem.modelData.secure; text: "lock"; font.pixelSize: 12; color: Config.dim }
                        Text {
                            Layout.fillWidth: true
                            text: netItem.modelData.ssid
                            // An SSID is 32 bytes chosen by whoever runs the access point — as
                            // foreign as text gets. PlainText, like every other outside string.
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: netItem.modelData.active ? Config.accent : Config.fg
                            font.family: Config.textFont; font.pixelSize: 13; font.bold: netItem.modelData.active
                        }
                        Rectangle {
                            implicitWidth: 30; implicitHeight: 30; radius: 15
                            color: netItem.modelData.active ? Config.accent : "transparent"
                            Behavior on color { ColorAnim {} }
                            MatIcon {
                                anchors.centerIn: parent
                                text: netItem.modelData.active ? "link_off" : "link"
                                font.pixelSize: 16
                                color: netItem.modelData.active ? Config.accentText : Config.fg
                            }
                            StateLayer {
                                ovRadius: 15; tint: netItem.modelData.active ? Config.accentText : Config.fg
                                onTapped: netItem.modelData.active ? Net.disconnectWifi(netItem.modelData.ssid) : Net.connectWifi(netItem.modelData.ssid)
                            }
                        }
                    }
                }

                Rectangle {
                    visible: Net.wifiOn
                    Layout.fillWidth: true; Layout.topMargin: 4
                    implicitHeight: 36; radius: 18
                    color: Config.container
                    RowLayout {
                        anchors.centerIn: parent; spacing: 6
                        MatIcon { text: "wifi_find"; font.pixelSize: 17; color: Config.accent }
                        Text { text: "Rescan networks"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 12 }
                    }
                    StateLayer { ovRadius: 18; onTapped: Net.scan() }
                }
            }
        }
    }

    // --- Bluetooth popout: power toggle + device list ---
    PopupWindow {
        anchor.window: bar
        anchor.item: btWidget
        anchor.edges: Edges.Right
        anchor.gravity: Edges.Right
        anchor.adjustment: PopupAdjustment.Slide
        anchor.margins.left: -2           // sit flush against the bar edge
        id: btPop
        readonly property bool shown: bar.popout === "bluetooth"
        visible: shown || btBody.opacity > 0.01   // stay mapped through the fade-out
        implicitWidth: 288
        implicitHeight: btCol.implicitHeight + 28 + Config.popFillet * 2
        property real botPad: Config.popFillet   // set by reportPopBox when the screen edge crowds the body
        color: "transparent"

        // Bulge the bar into this popout via the Frame's SDF (see bar.reportPopBox).
        onShownChanged: { if (shown) bar.reportPopBox(btWidget, btPop); else if (bar.popout === "") PopoutState.clear(bar.bulgeOwner); }
        onImplicitHeightChanged: if (shown) bar.reportPopBox(btWidget, btPop);

        Item {
            id: btBody
            anchors.fill: parent
            opacity: btPop.shown ? 1 : 0
            Behavior on opacity { Anim { type: Anim.Effect } }
            transform: Translate { x: btPop.shown ? 0 : -14; Behavior on x { Anim { type: Anim.Spatial } } }
            HoverHandler {
                onHoveredChanged: hovered ? bar.showPopout("bluetooth") : bar.hidePopout()
            }
            ColumnLayout {
                id: btCol
                anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16; topMargin: 14 + Config.popFillet * 2 - btPop.botPad }
                spacing: 8

                Text { text: "Bluetooth"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 15; font.bold: true }

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    Text { text: "Enabled"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 13; Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: 42; implicitHeight: 24; radius: 12
                        color: Bt.enabled ? Config.accent : Config.switchTrackOff
                        Behavior on color { ColorAnim {} }
                        Rectangle {
                            width: 18; height: 18; radius: 9; color: Bt.enabled ? Config.accentText : Config.dim
                            anchors.verticalCenter: parent.verticalCenter
                            x: Bt.enabled ? parent.width - width - 3 : 3
                            Behavior on x { SpatialFast {} }
                            Behavior on color { ColorAnim {} }
                        }
                        StateLayer { ovRadius: 12; onTapped: Bt.toggle() }
                    }
                }
                RowLayout {
                    visible: Bt.enabled
                    Layout.fillWidth: true; spacing: 12
                    Text { text: "Discovering"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 13; Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: 42; implicitHeight: 24; radius: 12
                        color: Bt.discovering ? Config.accent : Config.switchTrackOff
                        Behavior on color { ColorAnim {} }
                        Rectangle {
                            width: 18; height: 18; radius: 9; color: Bt.discovering ? Config.accentText : Config.dim
                            anchors.verticalCenter: parent.verticalCenter
                            x: Bt.discovering ? parent.width - width - 3 : 3
                            Behavior on x { SpatialFast {} }
                            Behavior on color { ColorAnim {} }
                        }
                        StateLayer { ovRadius: 12; onTapped: Bt.toggleScan() }
                    }
                }

                Text {
                    Layout.topMargin: 2
                    text: {
                        if (!Bt.enabled) return "Bluetooth is off";
                        const n = Bt.devices.length, c = Bt.devices.filter(d => d.connected).length;
                        return n + " device" + (n === 1 ? "" : "s") + " available" + (c > 0 ? " (" + c + " connected)" : "");
                    }
                    color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                }

                // Device list (connected first, then paired, then name).
                Repeater {
                    model: ScriptModel {
                        objectProp: "address"
                        values: Bt.enabled ? [...Bt.devices].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name ?? "").localeCompare(b.name ?? "")).slice(0, 6) : []
                    }
                    // No per-row entrance animation — see the Wi-Fi list above.
                    RowLayout {
                        id: btItem
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        MatIcon { text: Bt.icon(btItem.modelData.icon); font.pixelSize: 17; color: btItem.modelData.connected ? Config.accent : Config.dim }
                        Text {
                            Layout.fillWidth: true
                            text: btItem.modelData.name ?? ""
                            textFormat: Text.PlainText   // the device names itself over the air
                            elide: Text.ElideRight
                            color: btItem.modelData.connected ? Config.accent : Config.fg
                            font.family: Config.textFont; font.pixelSize: 13; font.bold: btItem.modelData.connected
                        }
                        MatIcon {
                            visible: btItem.modelData.connected && (btItem.modelData.batteryAvailable ?? false)
                            text: "battery_full"
                            font.pixelSize: 14
                            color: (btItem.modelData.battery ?? 1) < 0.2 ? Config.error : Config.dim
                        }
                        Rectangle {
                            implicitWidth: 30; implicitHeight: 30; radius: 15
                            color: btItem.modelData.connected ? Config.accent : "transparent"
                            Behavior on color { ColorAnim {} }
                            MatIcon {
                                anchors.centerIn: parent
                                text: btItem.modelData.connected ? "link_off" : "link"
                                font.pixelSize: 16
                                color: btItem.modelData.connected ? Config.accentText : Config.fg
                            }
                            StateLayer {
                                ovRadius: 15; tint: btItem.modelData.connected ? Config.accentText : Config.fg
                                onTapped: {
                                    if (btItem.modelData.connected && btItem.modelData.disconnect) btItem.modelData.disconnect();
                                    else if (btItem.modelData.connect) btItem.modelData.connect();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- VPN popout: profile list ---
    PopupWindow {
        anchor.window: bar
        anchor.item: vpnWidget
        anchor.edges: Edges.Right
        anchor.gravity: Edges.Right
        anchor.adjustment: PopupAdjustment.Slide
        anchor.margins.left: -2           // sit flush against the bar edge
        id: vpnPop
        readonly property bool shown: bar.popout === "vpn"
        visible: shown || vpnBody.opacity > 0.01   // stay mapped through the fade-out
        implicitWidth: 288
        implicitHeight: vpnCol.implicitHeight + 28 + Config.popFillet * 2
        property real botPad: Config.popFillet   // set by reportPopBox when the screen edge crowds the body
        color: "transparent"

        // Bulge the bar into this popout via the Frame's SDF (see bar.reportPopBox).
        onShownChanged: { if (shown) bar.reportPopBox(vpnWidget, vpnPop); else if (bar.popout === "") PopoutState.clear(bar.bulgeOwner); }
        onImplicitHeightChanged: if (shown) bar.reportPopBox(vpnWidget, vpnPop);

        Item {
            id: vpnBody
            anchors.fill: parent
            opacity: vpnPop.shown ? 1 : 0
            Behavior on opacity { Anim { type: Anim.Effect } }
            transform: Translate { x: vpnPop.shown ? 0 : -14; Behavior on x { Anim { type: Anim.Spatial } } }
            HoverHandler {
                onHoveredChanged: hovered ? bar.showPopout("vpn") : bar.hidePopout()
            }
            ColumnLayout {
                id: vpnCol
                anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16; topMargin: 14 + Config.popFillet * 2 - vpnPop.botPad }
                spacing: 8

                Text { text: "VPN"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 15; font.bold: true }
                Text {
                    Layout.topMargin: 2
                    text: {
                        const n = Net.vpnList.length, c = Net.vpnList.filter(v => v.active).length;
                        return n + " profile" + (n === 1 ? "" : "s") + (c > 0 ? " (" + c + " active)" : "");
                    }
                    color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                }
                Repeater {
                    model: ScriptModel {
                        objectProp: "name"
                        values: [...Net.vpnList].sort((a, b) => (b.active - a.active) || a.name.localeCompare(b.name))
                    }
                    // No per-row entrance animation — see the Wi-Fi list above.
                    RowLayout {
                        id: vpnItem
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        MatIcon { text: vpnItem.modelData.active ? "vpn_lock" : "vpn_key"; font.pixelSize: 17; color: vpnItem.modelData.active ? Config.accent : Config.dim }
                        Text {
                            Layout.fillWidth: true
                            text: vpnItem.modelData.name
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: vpnItem.modelData.active ? Config.accent : Config.fg
                            font.family: Config.textFont; font.pixelSize: 13; font.bold: vpnItem.modelData.active
                        }
                        Rectangle {
                            implicitWidth: 30; implicitHeight: 30; radius: 15
                            color: vpnItem.modelData.active ? Config.accent : "transparent"
                            Behavior on color { ColorAnim {} }
                            MatIcon {
                                anchors.centerIn: parent
                                text: vpnItem.modelData.active ? "link_off" : "link"
                                font.pixelSize: 16
                                color: vpnItem.modelData.active ? Config.accentText : Config.fg
                            }
                            StateLayer {
                                ovRadius: 15; tint: vpnItem.modelData.active ? Config.accentText : Config.fg
                                onTapped: vpnItem.modelData.active ? Net.vpnDown(vpnItem.modelData.name) : Net.vpnUp(vpnItem.modelData.name)
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Tray menu popout: our own hover-controlled menu (native menus don't hover-close) ---
    PopupWindow {
        anchor.window: bar
        anchor.item: bar.trayMenuAnchor
        anchor.edges: Edges.Right
        anchor.gravity: Edges.Right
        anchor.adjustment: PopupAdjustment.Slide
        anchor.margins.left: -2
        id: trayPop
        readonly property bool shown: bar.popout === "traymenu" && !!bar.trayMenuAnchor && !!bar.trayMenuHandle
        visible: shown || trayBody.opacity > 0.01   // stay mapped through the fade-out
        implicitWidth: 214
        implicitHeight: menuCol.implicitHeight + 24 + Config.popFillet * 2
        property real botPad: Config.popFillet   // set by reportPopBox when the screen edge crowds the body
        color: "transparent"

        // Bulges out of the bar like every other popout. Tray menus load asynchronously over D-Bus,
        // resize and switch items while the window stays open, so the box is re-reported on every
        // height or anchor change with anim=false — it must land in the same frame as the menu or
        // the content hangs outside its background. Height comes off the layout, not
        // trayPop.implicitHeight: that binding may still hold the previous value here, which left
        // the bulge a size behind every other icon switch. An empty layout means mid-reload — keep
        // the current bulge and let the refill report the real size.
        function reportBulge(anim) {
            if (!trayPop.shown || !bar.trayMenuAnchor || menuCol.implicitHeight < 1)
                return;
            bar.reportPopBox(bar.trayMenuAnchor, trayPop, anim, menuCol.implicitHeight + 24 + Config.popFillet * 2);
        }
        onShownChanged: { if (shown) reportBulge(true); else if (bar.popout === "") PopoutState.clear(bar.bulgeOwner); }
        onImplicitHeightChanged: reportBulge(false)
        Connections {
            target: bar
            function onTrayMenuAnchorChanged() { trayPop.reportBulge(false); }
        }

        QsMenuOpener {
            id: trayOpener
            menu: bar.trayMenuHandle
        }

        Item {
            id: trayBody
            anchors.fill: parent
            opacity: trayPop.shown ? 1 : 0
            Behavior on opacity { Anim { type: Anim.Effect } }
            transform: Translate { x: trayPop.shown ? 0 : -14; Behavior on x { Anim { type: Anim.Spatial } } }
            HoverHandler {
                onHoveredChanged: {
                    if (hovered) { bar.showPopout("traymenu"); trayPop.reportBulge(false); }
                    else bar.hidePopout();
                }
            }
            ColumnLayout {
                id: menuCol
                anchors { top: parent.top; left: parent.left; right: parent.right
                          topMargin: 12 + Config.popFillet * 2 - trayPop.botPad; leftMargin: 8; rightMargin: 8 }
                spacing: 2
                // implicitHeight is a binding on this layout and doesn't notify reliably, so the
                // bulge is re-reported here: hovering a second tray icon swaps the D-Bus menu,
                // emptying and refilling the layout, and without this the bulge stays collapsed.
                onImplicitHeightChanged: trayPop.reportBulge(false)
                Repeater {
                    model: trayOpener.children
                    delegate: Item {
                        id: menuItem
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: menuItem.modelData.isSeparator ? 9 : 32

                        Rectangle {
                            visible: menuItem.modelData.isSeparator
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            implicitHeight: 1; color: Config.outline
                        }
                        Rectangle {
                            visible: !menuItem.modelData.isSeparator
                            anchors.fill: parent
                            radius: 8
                            color: "transparent"
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                                Image {
                                    visible: (menuItem.modelData.icon ?? "") !== ""
                                    Layout.preferredWidth: visible ? 16 : 0
                                    Layout.preferredHeight: 16
                                    sourceSize: Qt.size(16, 16)
                                    source: menuItem.modelData.icon ?? ""
                                }
                                Text {
                                    text: menuItem.modelData.text ?? ""
                                    textFormat: Text.PlainText   // menu labels arrive over D-Bus
                                    color: menuItem.modelData.enabled ? Config.fg : Config.fgDisabled
                                    font.family: Config.textFont; font.pixelSize: 13
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                                MatIcon {
                                    visible: menuItem.modelData.hasChildren
                                    text: "chevron_right"; font.pixelSize: 16
                                    color: menuItem.modelData.enabled ? Config.dim : Config.fgDisabled
                                }
                            }
                            StateLayer {
                                ovRadius: 8
                                enabled: menuItem.modelData.enabled && !menuItem.modelData.hasChildren
                                onTapped: { menuItem.modelData.triggered(); bar.popout = ""; }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Power popout: hold-to-confirm session actions, bulging out of the bar like the rest ---
    PopupWindow {
        id: powerPop
        anchor.window: bar
        anchor.item: powerWidget
        anchor.edges: Edges.Right
        anchor.gravity: Edges.Right
        anchor.adjustment: PopupAdjustment.Slide
        anchor.margins.left: -2           // sit flush against the bar edge
        readonly property bool shown: bar.popout === "power"
        visible: shown || powerBody.opacity > 0.01   // stay mapped through the fade-out
        implicitWidth: 208
        implicitHeight: powerCol.implicitHeight + 24 + Config.popFillet * 2
        property real botPad: Config.popFillet   // set by reportPopBox when the screen edge crowds the body
        color: "transparent"

        // Bulge the bar into this popout via the Frame's SDF (see bar.reportPopBox). The IPC flag
        // is kept in step both ways, so `ipc call session toggle` still closes a hover-open one.
        onShownChanged: {
            Shell.sessionVisible = shown;
            if (shown) bar.reportPopBox(powerWidget, powerPop);
            else if (bar.popout === "") PopoutState.clear(bar.bulgeOwner);
        }

        // IPC toggles Shell.sessionVisible, so mirror that flag onto the shared popout slot
        // rather than owning a second state.
        Connections {
            target: Shell
            function onSessionVisibleChanged() {
                if (Shell.sessionVisible) bar.showPopout("power");
                else if (bar.popout === "power") bar.popout = "";
            }
        }

        Item {
            id: powerBody
            anchors.fill: parent
            opacity: powerPop.shown ? 1 : 0
            Behavior on opacity { Anim { type: Anim.Effect } }
            transform: Translate { x: powerPop.shown ? 0 : -14; Behavior on x { Anim { type: Anim.Spatial } } }

            HoverHandler {
                onHoveredChanged: hovered ? bar.showPopout("power") : bar.hidePopout()
            }

            ColumnLayout {
                id: powerCol
                anchors { top: parent.top; left: parent.left; right: parent.right
                          topMargin: 12 + Config.popFillet * 2 - powerPop.botPad; leftMargin: 10; rightMargin: 10 }
                spacing: 2

                Repeater {
                    model: bar.sessionActions
                    // A row, not a button: no plate and no border of its own. What marks it is the
                    // wash under the cursor, in the action's own colour, so the menu reads as a
                    // list of four choices rather than four boxes stacked in a fifth.
                    Item {
                        id: pbtn
                        required property var modelData
                        required property int index
                        readonly property color tone: bar.sessionTones[pbtn.index]
                        readonly property bool holding: pbtnMa.pressed
                        property real fill: 0
                        Layout.fillWidth: true
                        implicitHeight: 38

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: pbtn.tone
                            opacity: pbtn.holding ? 0.20 : (pbtnMa.containsMouse ? 0.11 : 0)
                            Behavior on opacity { Anim { type: Anim.Effect } }
                        }

                        onHoldingChanged: {
                            if (pbtn.holding) { pbtn.fill = 0; pfillAnim.restart(); }
                            else { pfillAnim.stop(); pbtn.fill = 0; }
                        }
                        NumberAnimation {
                            id: pfillAnim
                            target: pbtn; property: "fill"; from: 0; to: 1; duration: 500
                            onFinished: { Shell.sessionVisible = false; bar.popout = ""; pbtn.modelData.run(); }
                        }

                        // Hold progress: a rail under the row. Flooding the whole row instead would
                        // just be the old plate coming back for half a second.
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                                      leftMargin: 10; rightMargin: 10; bottomMargin: 3 }
                            height: 2; radius: 1
                            color: Config.outline
                            opacity: pbtn.holding ? 1 : 0
                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: parent.width * pbtn.fill
                                radius: 1
                                color: pbtn.tone
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            spacing: 12
                            MatIcon { text: pbtn.modelData.icon; font.pixelSize: 19; color: pbtn.tone }
                            Text {
                                Layout.fillWidth: true
                                text: pbtn.modelData.label
                                color: Config.fg; font.family: Config.textFont; font.pixelSize: 13
                            }
                        }

                        MouseArea {
                            id: pbtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }

            }
        }
    }

}
