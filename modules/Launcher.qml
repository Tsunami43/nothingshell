// App launcher (Super+Space): fuzzy app search + calc/emoji/actions/run/web prefixes. Per-screen
// panel sliding up from the bottom edge, its background drawn by the Frame's SDF bulge
// (PopoutState) so it flows out of the border — the bottom analogue of the Dashboard. No dim.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: launcher
    required property var modelData
    screen: modelData
    readonly property bool shown: Shell.launcherVisible
    // Always realized, so win.width/height are the real screen size before the first open; the
    // panel slides off-screen and the mask is empty when closed.
    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"                 // no dim behind the launcher
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    // Exclusive, not OnDemand: OnDemand grabs the keyboard only once the surface is clicked, so
    // typing leaked to the window underneath.
    WlrLayershell.keyboardFocus: launcher.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Shell.launcherQuery lets a keybind open straight into a mode (">theme", ":"…), consumed
    // here so the next plain open starts empty.
    function takeQuery() {
        search.text = Shell.launcherQuery;
        Shell.launcherQuery = "";
        search.cursorPosition = search.text.length;
        search.forceActiveFocus();
    }
    onShownChanged: {
        if (launcher.shown) launcher.takeQuery();
        reportBox();
    }
    Connections {
        target: Shell
        // On an already-open launcher onShownChanged never fires again, so switch modes here —
        // otherwise a second `launcher open …` silently does nothing.
        function onLauncherQueryChanged() {
            if (launcher.shown && Shell.launcherQuery) launcher.takeQuery();
        }
    }
    // Report the panel body rect (screen px) so the Frame bulges the bottom border up into it.
    // Inset the sides and extend 18px below the screen bottom so the bulge fuses with the border.
    //
    // Driven off panel.y live and reported with anim=false, so the bulge rides the slide 1:1.
    // Reporting the resting rect made the background appear where the panel was going to land and
    // collapse upward — the Frame eases size only, so the box grew down from a fixed top edge.
    function reportBox() {
        // The panel keeps sliding after closing, by which point the Dashboard may already own the
        // shared bulge slot.
        if (!launcher.shown && PopoutState.owner !== "launcher") return;
        // The bulge is inset LESS than the content margin (panel.pad), so the ring of background
        // showing around the content IS the padding. x anchors to panel.x (it carries an offset).
        const inset = 16;
        const topInset = 16;
        const py = panel.y + topInset;
        // Fully below the screen: the bulge has sunk into the bottom border, so drop it.
        if (py >= launcher.height) { PopoutState.clear("launcher"); return; }
        // Anchored bottom-centre so any easing the Frame does still runs out of the bottom border.
        PopoutState.setBox(panel.x + inset, py, panel.width - inset * 2,
                           panel.height - topInset + 18, "launcher", false, 0.5, 1.0);
    }

    // Command palette, shown when the query starts with ">". The entries themselves live in
    // services/Actions.qml — the list is long and purely declarative.
    readonly property bool isActions: search.text.startsWith(">")

    // ">theme", ">wallpaper" and ">font" swap the result list for a live-preview carousel. One
    // PathView serves all three; the four helpers below are what differs between them.
    readonly property string carouselMode: {
        const t = search.text.trim().toLowerCase();
        if (t === ">theme") return "theme";
        if (t === ">wallpaper") return "wallpaper";
        if (t === ">font") return "font";
        return "";
    }
    readonly property bool isCarousel: launcher.carouselMode !== ""
    readonly property var carouselModel: {
        switch (launcher.carouselMode) {
        case "theme": return Themes.order;
        case "wallpaper": return Wallpaper.list;
        case "font": return Config.fontFiles.map(f => f.key);
        }
        return [];
    }
    function carouselIndex() {
        switch (launcher.carouselMode) {
        case "theme": return Math.max(0, Themes.order.indexOf(Config.activeTheme));
        case "wallpaper": return Math.max(0, Wallpaper.list.indexOf((Config.wallpaper ?? "").replace("file://", "")));
        case "font": return Math.max(0, Config.fontFiles.findIndex(f => f.key === Config.fontKey));
        }
        return 0;
    }
    // Applied as you flip, so the whole shell previews the choice.
    function carouselPreview(i) {
        const k = launcher.carouselModel[i];
        if (k === undefined) return;
        if (launcher.carouselMode === "theme") {
            // A curated theme and wallpaper-derived colours are exclusive, so picking one here
            // would otherwise appear to do nothing.
            if (k !== Config.activeTheme) { Config.autoColors = false; Config.activeTheme = k; }
        } else if (launcher.carouselMode === "font") {
            if (k !== Config.fontKey) Config.fontPreset = k;
        }
        // Wallpapers are not previewed: setting one re-runs matugen, far too heavy per flip.
    }
    function carouselCommit(i) {
        if (launcher.carouselMode !== "wallpaper") return;
        const p = launcher.carouselModel[i];
        if (p) Wallpaper.set(p);
    }
    // Rewrite the query in place instead of closing — how a ">" command hands off to another mode.
    function enterPrefix(text) {
        search.text = text;
        search.cursorPosition = search.text.length;
    }
    function enterMode(name) { launcher.enterPrefix(">" + name); }

    readonly property bool isRun: search.text.startsWith("$")
    readonly property bool isEmoji: search.text.startsWith(":")
    readonly property bool isClip: search.text.startsWith("#")

    // "$" runs under the login shell, not /bin/sh: functions and aliases are half of what anyone
    // types at a prompt, and under sh they come back as "command not found".
    readonly property string userShell: Quickshell.env("SHELL") || "/bin/sh"
    readonly property string terminal: Quickshell.env("TERMINAL") || "ghostty"
    readonly property string shellName: launcher.userShell.split("/").pop()
    readonly property string termName: launcher.terminal.split("/").pop()

    // Shell surfaces that have no .desktop file but should still be findable by name, listed
    // alongside real applications rather than hidden behind a prefix.
    readonly property var pseudoApps: [
        { id: "nothingshell.settings", name: "Settings",
          keywords: "settings preferences control panel system configure настройки",
          matIcon: "settings", isAction: true,
          execute: function() { Shell.launcherVisible = false; Shell.openSettings(""); } }
    ]

    // Results: emoji (":…"), run-command ("$…"), quick actions (">…"), apps, else web-search.
    readonly property var filtered: {
        if (isCalc) return [];
        if (isEmoji) {
            const q = search.text.slice(1).trim().toLowerCase();
            const list = q ? Emoji.data.filter(x => x.k.includes(q)) : Emoji.data;
            return list.slice(0, 60).map(x => ({
                name: x.k.split(" ")[0], emoji: x.e, isEmoji: true, isAction: true,
                execute: function() { Quickshell.execDetached(["wl-copy", x.e]); }
            }));
        }
        if (isRun) {
            const cmd = search.text.slice(1).trim();
            if (!cmd)
                return [{ name: "Type a command", desc: "$firefox · $git status · $systemctl --user restart …",
                          matIcon: "terminal", isAction: true, keepOpen: true, execute: function() {} }];
            // Two ways to run it: the detached form is silent, which suits a GUI app but makes
            // `ls` or `git status` indistinguishable from nothing having happened.
            return [
                { name: "Run in a terminal: " + cmd,
                  desc: launcher.termName + " + " + launcher.shellName + "; stays open on exit",
                  matIcon: "dock_to_bottom", isAction: true,
                  execute: function() {
                      // The epilogue must be POSIX sh (fish has no $? and a different `read`) while
                      // the command still runs under the user's shell, so their aliases exist.
                      // `sh -c <script> $0 $1` passes both as argv, so quotes and $ survive.
                      const script = '"$0" -c "$1"; printf "\\n[exit %s] press Enter to close" "$?"; read -r _';
                      Quickshell.execDetached([launcher.terminal, "-e", "sh", "-c", script, launcher.userShell, cmd]);
                  } },
                { name: "Run: " + cmd, desc: "Detached via " + launcher.shellName + " — no window, no output",
                  matIcon: "terminal", isAction: true,
                  execute: function() { Quickshell.execDetached([launcher.userShell, "-c", cmd]); } }
            ];
        }
        if (isClip) {
            if (!Config.clipboardEnabled)
                return [{ name: "Clipboard history is off", desc: "Turn it on in Settings › Shell › Launcher",
                          matIcon: "content_paste_off", isAction: true, keepOpen: true,
                          execute: function() { Shell.launcherVisible = false; Shell.openSettings("shell"); } }];
            if (Clip.entries.length === 0)
                return [{ name: "Nothing copied yet", desc: "Anything you copy from now on shows up here",
                          matIcon: "content_paste", isAction: true, keepOpen: true,
                          execute: function() {} }];
            return Clip.search(search.text.slice(1)).map(e => ({
                name: Clip.preview(e.text),
                desc: Clip.summary(e.text),
                matIcon: "content_paste",
                isAction: true,
                clipEntry: e,
                execute: function() { Clip.copy(e.text); }
            }));
        }
        if (isActions) {
            if (launcher.isCarousel) return [];
            return Actions.search(search.text.slice(1)).map(a => ({
                name: a.name, desc: a.desc, matIcon: a.icon, isAction: true, action: a
            }));
        }
        const q = search.text.toLowerCase();
        const all = DesktopEntries.applications?.values ?? [];
        // Pseudo-apps join the real ones *before* ranking, so "Settings" competes on launch
        // frequency like anything else.
        const vis = all.filter(a => !a.noDisplay).concat(launcher.pseudoApps);
        const list = q.length === 0 ? vis : vis.filter(a =>
            ((a.name ?? "") + " " + (a.keywords ?? "")).toLowerCase().includes(q));
        // Web-search fallback when a non-empty query matches no apps.
        if (list.length === 0 && q.length > 0) {
            const term = search.text;
            return [{ name: "Search the web for “" + term + "”", matIcon: "travel_explore", isAction: true,
                      execute: function() { Quickshell.execDetached(["xdg-open", Config.launcherSearchUrl + encodeURIComponent(term)]); } }];
        }
        return list.slice().sort((a, b) => {
            const ua = Config.appUsageMap[a.id] || 0, ub = Config.appUsageMap[b.id] || 0;
            if (ua !== ub) return ub - ua;   // most-used first
            return (a.name ?? "").localeCompare(b.name ?? "");
        }).slice(0, Config.launcherMax);
    }

    // Calculator: if the query is a pure arithmetic expression (or "= expr"), evaluate it.
    readonly property string calcExpr: {
        let t = search.text.trim();
        return t.startsWith("=") ? t.slice(1).trim() : t;
    }
    readonly property bool isCalc: {
        const t = calcExpr;
        return t.length > 0 && /^[\d\s+\-*/().%^]+$/.test(t) && /[+\-*/^%]/.test(t) && /\d/.test(t);
    }
    readonly property string calcResult: {
        if (!isCalc) return "";
        try {
            const v = Function('"use strict"; return (' + calcExpr.replace(/\^/g, "**") + ')')();
            if (typeof v === "number" && isFinite(v)) return "" + (Math.round(v * 1e6) / 1e6);
        } catch (e) {}
        return "";
    }

    // Move the selection by one, in whichever is on screen — result list or carousel. Arrows and
    // Ctrl+J/K both land here. Untyped on purpose: an annotated return with an unannotated
    // parameter is rejected outright and the function never registers.
    function step(delta) {
        if (launcher.isCarousel) {
            if (delta > 0) carousel.incrementCurrentIndex();
            else carousel.decrementCurrentIndex();
            return;
        }
        if (delta > 0) appList.incrementCurrentIndex();
        else appList.decrementCurrentIndex();
    }

    function launchCurrent(): void {
        // In a carousel the choice has usually applied already; Enter commits what could not be
        // previewed (the wallpaper) and closes.
        if (launcher.isCarousel) {
            launcher.carouselCommit(carousel.currentIndex);
            Shell.launcherVisible = false;
            return;
        }
        if (launcher.isCalc && launcher.calcResult) {
            Quickshell.execDetached(["wl-copy", launcher.calcResult]);
            Shell.launcherVisible = false;
            return;
        }
        launcher.launchItem(launcher.filtered[appList.currentIndex]);
    }
    // The single place that knows how to run a result row, whether it arrived by Enter or click.
    function launchItem(item): void {
        if (!item) return;
        // Bump anything with an id: only the web-search and command rows are unranked.
        if (item.id) Config.bumpAppUsage(item.id);
        if (item.action) {
            if (Actions.run(item.action, launcher)) Shell.launcherVisible = false;
            return;
        }
        item.execute();
        if (!item.keepOpen) Shell.launcherVisible = false;
    }

    // Transparent outside-click catcher — masked (and thus interactive) only while open.
    mask: Region { item: launcher.shown ? catcher : null }
    MouseArea {
        id: catcher
        anchors.fill: parent
        onClicked: Shell.launcherVisible = false
    }

    // Sliding panel — background from the Frame bulge, content on top. Search sits at the bottom
    // and the height tracks the content, so results grow upward from it.
    Item {
        id: panel
        // Centre within the frame's content region (56px bar, 8px right border), not on the raw
        // screen centre.
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: (56 - 8) / 2
        // A compact box, not screen-relative, so the side padding stays constant; a carousel widens
        // for the previews, and the screen clamp is only a safety net. The base width is measured
        // off the prefix hint rather than hardcoded — the hint grows with every mode added, and a
        // fixed 600 silently clipped it.
        readonly property int chrome: 16 + 20 + 12 + 50   // search icon block + clear-button gutter
        readonly property int hintFit: hint.implicitWidth + panel.chrome + panel.pad * 2
        width: Math.min(launcher.isCarousel ? 900 : Math.max(600, panel.hintFit),
                        launcher.width - 56 - 8 - 32)
        Behavior on width { Anim { type: Anim.Spatial } }

        // Content margin > the bulge inset (16) so a ~24px ring of background frames the content.
        readonly property int pad: 40
        // Smaller bottom gap so the search bar sits lower, closer to the bottom border.
        readonly property int botPad: 1 + Config.popFillet
        readonly property int maxListH: Math.min(430, launcher.height - 220)

        // Bottom-anchored so the panel grows upward as its content height changes; slid off-screen
        // via the bottom margin when hidden.
        anchors.bottom: parent.bottom
        anchors.bottomMargin: launcher.shown ? 0 : (-height - 20)
        Behavior on anchors.bottomMargin { Anim { type: Anim.Spatial } }
        height: inner.implicitHeight + pad + botPad
        Behavior on height { Anim { type: Anim.Spatial } }
        // Re-report on every geometry change: the slide, content growth and >theme all move the
        // body the bulge is supposed to back.
        onXChanged: launcher.reportBox()
        onYChanged: launcher.reportBox()
        onWidthChanged: launcher.reportBox()
        onHeightChanged: launcher.reportBox()
        MouseArea { anchors.fill: parent }  // swallow clicks on the panel

        ColumnLayout {
            id: inner
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: panel.pad; anchors.rightMargin: panel.pad
            anchors.bottomMargin: panel.botPad
            spacing: 12

            // Calculator result card (shown when the query is an arithmetic expression).
            Rectangle {
                Layout.fillWidth: true
                visible: launcher.isCalc && launcher.calcResult.length > 0
                Layout.preferredHeight: visible ? 60 : 0
                radius: 10
                color: Config.container
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
                    MatIcon { text: "calculate"; font.pixelSize: 22; color: Config.accent }
                    Text {
                        text: launcher.calcResult
                        color: Config.fg; font.family: Config.textFont; font.pixelSize: 26; font.bold: true
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text {
                        text: "⏎ copy"
                        color: Config.dim; font.family: Config.textFont; font.pixelSize: 12
                    }
                }
            }

            // Results — sized to content (capped), so the panel hugs the search when short.
            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? Math.min(contentHeight, panel.maxListH) : 0
                visible: !launcher.isCalc && !launcher.isCarousel
                clip: true
                model: launcher.filtered
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: appItem
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === appList.currentIndex
                    width: appList.width
                    height: modelData.desc ? 58 : 48
                    radius: 12
                    color: sel ? Config.accent : "transparent"
                    Behavior on color { ColorAnim {} }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 12
                        spacing: 12

                        // App icon (real desktop icon).
                        Image {
                            width: 30; height: 30
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !appItem.modelData.isAction
                            sourceSize: Qt.size(30, 30)
                            source: (!appItem.modelData.isAction && appItem.modelData.icon) ? Quickshell.iconPath(appItem.modelData.icon, true) : ""
                        }
                        // Command/action icon in a rounded container.
                        Rectangle {
                            width: 34; height: 34; radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: appItem.modelData.isAction === true && appItem.modelData.isEmoji !== true
                            color: appItem.sel ? Config.accentPlate : Config.container
                            MatIcon {
                                anchors.centerIn: parent
                                text: appItem.modelData.matIcon ?? ""
                                font.pixelSize: 20
                                color: appItem.sel ? Config.accentText : Config.accent
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: appItem.modelData.isEmoji === true
                            text: appItem.modelData.emoji ?? ""
                            font.pixelSize: 24
                            width: 30; horizontalAlignment: Text.AlignHCenter
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            // PlainText: a row's name is a .desktop entry in the app case and a
                            // clipboard preview under "#", neither of which the shell wrote.
                            Text {
                                text: appItem.modelData.name ?? ""
                                textFormat: Text.PlainText
                                color: appItem.sel ? Config.accentText : Config.fg
                                font.family: Config.textFont; font.pixelSize: 14
                            }
                            Text {
                                visible: !!appItem.modelData.desc
                                text: appItem.modelData.desc ?? ""
                                textFormat: Text.PlainText
                                color: appItem.sel ? Config.accentTextDim : Config.dim
                                font.family: Config.textFont; font.pixelSize: 12
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: appList.currentIndex = appItem.index
                        onClicked: launcher.launchItem(appItem.modelData)
                    }
                }
            }

            // --- Preview carousel (>theme, >wallpaper, >font): an infinite, always-centred wheel.
            // Theme and font apply live as you flip, the wallpaper on Enter (carouselPreview).
            PathView {
                id: carousel
                visible: launcher.isCarousel
                Layout.fillWidth: true; Layout.preferredHeight: visible ? 250 : 0
                clip: true
                model: launcher.carouselModel
                // Never 0: an empty model gives the PathView a degenerate path that drags the
                // whole column's layout down with it.
                pathItemCount: Math.max(1, Math.min(5, launcher.carouselModel.length))
                snapMode: PathView.SnapToItem
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: Motion.spatialDur
                // Start on whatever is in effect, on creation and on every re-entry — the model
                // changes underneath, so the index must follow.
                Component.onCompleted: currentIndex = launcher.carouselIndex()
                onVisibleChanged: if (visible) currentIndex = launcher.carouselIndex()
                onModelChanged: if (visible) currentIndex = launcher.carouselIndex()
                onCurrentIndexChanged: launcher.carouselPreview(currentIndex)

                // Straight horizontal path; items shrink + fade toward the edges via path attributes.
                path: Path {
                    startX: 0; startY: carousel.height / 2
                    PathAttribute { name: "iscale"; value: 0.68 }
                    PathAttribute { name: "iopacity"; value: 0.0 }
                    PathAttribute { name: "iz"; value: 0 }
                    PathLine { x: carousel.width / 2; y: carousel.height / 2 }
                    PathAttribute { name: "iscale"; value: 1.0 }
                    PathAttribute { name: "iopacity"; value: 1.0 }
                    PathAttribute { name: "iz"; value: 2 }
                    PathLine { x: carousel.width; y: carousel.height / 2 }
                    PathAttribute { name: "iscale"; value: 0.68 }
                    PathAttribute { name: "iopacity"; value: 0.0 }
                    PathAttribute { name: "iz"; value: 0 }
                }

                delegate: Item {
                    id: card
                    required property string modelData
                    required property int index
                    readonly property bool isTheme: launcher.carouselMode === "theme"
                    readonly property bool isFont: launcher.carouselMode === "font"
                    // Themes carry a curated palette; the other two modes have none to show.
                    readonly property var t: card.isTheme ? Themes.map[card.modelData] : null
                    readonly property string thumb: card.isTheme ? "file://" + Themes.dir + "thumbs/" + card.modelData + ".jpg"
                                                  : card.isFont ? "" : "file://" + card.modelData
                    readonly property string title: {
                        if (card.isTheme) return card.t?.title ?? card.modelData;
                        if (card.isFont) return (Config.fontFiles.find(f => f.key === card.modelData)?.label) ?? card.modelData;
                        return card.modelData.split("/").pop();
                    }
                    readonly property bool cur: PathView.isCurrentItem
                    width: 280; height: carousel.height
                    // Defaulted: with an empty model the PathView keeps one delegate unattached to
                    // the path, where the attributes read undefined.
                    scale: PathView.iscale ?? 1
                    opacity: PathView.iopacity ?? 1
                    z: PathView.iz ?? 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        // Preview (16:9), rounded via a mask, with a highlight border. Image-backed
                        // for themes and wallpapers; a type specimen for fonts.
                        Item {
                            id: thumbBox
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 250; height: 141
                            Image {
                                anchors.fill: parent
                                visible: !card.isFont
                                source: card.thumb
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(500, 282)
                                asynchronous: true; cache: true
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: thumbMask
                                    maskThresholdMin: 0.5
                                    maskSpreadAtMin: 1.0
                                }
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: card.isFont
                                radius: 16
                                color: Config.container
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Aa"
                                        color: Config.fg
                                        font.family: Config.fontNames[card.modelData] ?? Config.textFont
                                        font.pixelSize: 52
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "The quick brown fox"
                                        color: Config.dim
                                        font.family: Config.fontNames[card.modelData] ?? Config.textFont
                                        font.pixelSize: 14
                                    }
                                }
                            }
                            Item {
                                id: thumbMask
                                anchors.fill: parent
                                layer.enabled: true
                                visible: false
                                Rectangle { anchors.fill: parent; radius: 16 }
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: 16; color: "transparent"
                                border.width: card.cur ? 2 : 1
                                border.color: card.cur ? (card.t?.pal?.primary ?? Config.accent)
                                                       : (card.t?.pal?.outline ?? Config.outline)
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: card.title
                            textFormat: Text.PlainText   // a filename off the disk
                            color: Config.fg
                            font.family: Config.textFont; font.pixelSize: 15; font.bold: true
                            width: 250; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle
                        }

                        // Colour palette (themes only).
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: card.isTheme
                            spacing: 7
                            Repeater {
                                model: card.isTheme ? [card.t.pal.primary, card.t.pal.secondary,
                                                       card.t.pal.surfaceContainerHigh, card.t.pal.surfaceText]
                                                    : []
                                Rectangle {
                                    required property var modelData
                                    width: 22; height: 22; radius: 11
                                    color: modelData ?? "#888888"
                                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
                                }
                            }
                        }

                        // Wallpapers only apply on Enter — say so, since every other mode is live.
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: launcher.carouselMode === "wallpaper" && card.cur
                            text: "⏎ apply and regenerate the palette"
                            color: Config.dim
                            font.family: Config.textFont; font.pixelSize: 12
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        // A click on the centred card commits; anything else just brings it in.
                        onClicked: {
                            if (card.cur) launcher.launchCurrent();
                            else carousel.currentIndex = card.index;
                        }
                    }
                }
            }

            // Search field — bottom of the panel; magnifier left, clear right, inner padding.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 50
                radius: 14
                color: Config.container

                MatIcon {
                    id: searchIcon
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 16
                    text: "search"; font.pixelSize: 20; color: Config.dim
                }
                TextInput {
                    id: search
                    anchors.left: searchIcon.right; anchors.leftMargin: 12
                    anchors.right: clearBtn.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    verticalAlignment: TextInput.AlignVCenter
                    color: Config.fg
                    font.family: Config.textFont; font.pixelSize: 15
                    clip: true
                    focus: true
                    onTextChanged: appList.currentIndex = 0
                    Keys.onDownPressed: launcher.step(1)
                    Keys.onUpPressed: launcher.step(-1)
                    // Ctrl+J/K for down/up and Ctrl+H/L for left/right, so the hands stay on the
                    // home row; Ctrl is required because bare hjkl must stay typeable. H/L are
                    // gated on isCarousel like the arrows below — sideways means nothing in a
                    // vertical list, and leaving them unaccepted keeps Qt's Ctrl+H (delete
                    // previous character) working.
                    Keys.onPressed: e => {
                        if (!(e.modifiers & Qt.ControlModifier)) return;
                        if (e.key === Qt.Key_J) { launcher.step(1); e.accepted = true; }
                        else if (e.key === Qt.Key_K) { launcher.step(-1); e.accepted = true; }
                        else if (launcher.isCarousel && e.key === Qt.Key_H) { launcher.step(-1); e.accepted = true; }
                        else if (launcher.isCarousel && e.key === Qt.Key_L) { launcher.step(1); e.accepted = true; }
                    }
                    Keys.onReturnPressed: launcher.launchCurrent()
                    Keys.onEnterPressed: launcher.launchCurrent()
                    // In a carousel, left/right flip it (instead of moving the text cursor).
                    Keys.onLeftPressed: e => { if (launcher.isCarousel) { launcher.step(-1); e.accepted = true; } }
                    Keys.onRightPressed: e => { if (launcher.isCarousel) { launcher.step(1); e.accepted = true; } }
                    Keys.onEscapePressed: Shell.launcherVisible = false
                    // Delete drops the highlighted clipboard entry in place, so a password that
                    // landed in the history can be pruned on the spot.
                    Keys.onDeletePressed: e => {
                        if (!launcher.isClip) return;
                        const item = launcher.filtered[appList.currentIndex];
                        if (!item?.clipEntry) return;
                        Clip.remove(Clip.entries.indexOf(item.clipEntry));
                        e.accepted = true;
                    }

                    Text {
                        id: hint
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        visible: search.text.length === 0
                        text: "apps · > commands · # clipboard · = calc · $ run · : emoji"
                        color: Config.dim
                        font.family: Config.textFont; font.pixelSize: 15
                    }
                }
                // Clear button (shown once there's a query).
                Rectangle {
                    id: clearBtn
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right; anchors.rightMargin: 10
                    width: 30; height: 30; radius: 15
                    visible: search.text.length > 0
                    color: clearMa.containsMouse ? Config.bg : "transparent"
                    MatIcon { anchors.centerIn: parent; text: "close"; font.pixelSize: 18; color: Config.dim }
                    MouseArea {
                        id: clearMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { search.text = ""; search.forceActiveFocus(); }
                    }
                }
            }
        }
    }
}
