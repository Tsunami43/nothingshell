pragma Singleton

// App-wide theme palette (live matugen), persisted state, fonts and shared constants.
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "colorutil.js" as CU

Singleton {
    id: root

    // Resolved from this file, not the running shell root: the greeter imports this tree from
    // *its* root, where Quickshell.shellDir would point at the greeter and lose every asset below.
    readonly property string dir: Qt.resolvedUrl(".").toString().replace("file://", "") + "/"

    // --- Persisted state (settings.json, next to this file) ---
    // The JSON file IS the store: every alias points straight at a JsonAdapter property, so any
    // value set in the shell lands on disk and can be hand-edited while it runs. PersistentProperties
    // only survives a hot-reload — restarting quickshell reverted theme, font and capture defaults.
    //
    // It lives under $XDG_CONFIG_HOME/nothingshell, not beside this file: the tree may be installed
    // read-only (the Nix store) and an update must not overwrite what the user set. See Paths.qml.
    property alias dnd: cfg.dnd
    property alias schemeType: cfg.schemeType           // matugen --type
    property alias wallpaper: cfg.wallpaper
    property alias autoLock: cfg.autoLock
    property alias autoLockTimeout: cfg.autoLockTimeout // seconds idle before the lock screen
    property alias dpmsTimeout: cfg.dpmsTimeout         // seconds idle before displays sleep (0 = never)
    property alias appUsage: cfg.appUsage               // { desktopId: launchCount }
    property alias activeTheme: cfg.activeTheme
    property alias autoColors: cfg.autoColors           // colours follow the wallpaper (Material You) vs curated preset
    property alias autoLight: cfg.autoLight             // in auto mode: light scheme vs dark
    property alias motionScale: cfg.motionScale         // global animation speed multiplier (Motion.scale)
    property alias vpnProviders: cfg.vpnProviders       // [{name,iface,connectCmd,disconnectCmd}]
    property alias vpnSelected: cfg.vpnSelected         // name of the active provider
    property alias fontPreset: cfg.fontPreset           // text face: a key from fontFiles
    // --- Bar modules (which widgets the vertical bar shows) ---
    property alias barWorkspaces: cfg.barWorkspaces
    property alias barWindow: cfg.barWindow             // active-window icon + vertical title
    property alias barTray: cfg.barTray
    property alias barClock: cfg.barClock
    property alias barClock12h: cfg.barClock12h
    property alias barVolume: cfg.barVolume
    property alias barBrightness: cfg.barBrightness
    property alias barKeyboard: cfg.barKeyboard
    property alias barBattery: cfg.barBattery
    property alias barControls: cfg.barControls         // network / bluetooth / VPN pill
    // --- Dashboard ---
    property alias dashTab: cfg.dashTab                 // tab index the dashboard opens on
    // --- Overview (hover the right edge) ---
    property alias overviewWidth: cfg.overviewWidth     // panel width in px
    property alias overviewThumbs: cfg.overviewThumbs   // live window thumbnails vs icon cards
    property alias overviewRefreshMs: cfg.overviewRefreshMs  // how often an open panel re-grabs stills
    // --- Launcher ---
    property alias launcherMax: cfg.launcherMax         // result cap
    property alias launcherSearchUrl: cfg.launcherSearchUrl
    property alias launcherDangerous: cfg.launcherDangerous  // offer reboot/shut down/log out under ">"
    // --- Clipboard history ("#" in the launcher) ---
    property alias clipboardEnabled: cfg.clipboardEnabled    // run the wl-paste watcher at all
    property alias clipboardMax: cfg.clipboardMax            // entries kept (memory only, never written to disk)
    // --- Notifications ---
    property alias notifTimeout: cfg.notifTimeout       // toast dwell (ms)
    property alias notifSuppressFullscreen: cfg.notifSuppressFullscreen
    property alias notifSuppressGame: cfg.notifSuppressGame
    property alias notifMuted: cfg.notifMuted           // app names whose toasts are skipped
    // --- Capture (screenshots + screen recording), see services/Capture.qml ---
    property alias capMode: cfg.capMode                 // last panel mode: shot | rec
    property alias capSource: cfg.capSource             // last source: screen | region
    property alias recFormat: cfg.recFormat             // container: mkv | mp4 | webm
    property alias recFps: cfg.recFps
    property alias recAudio: cfg.recAudio               // none | desktop | mic | both
    property alias recQuality: cfg.recQuality           // medium | high | very_high | ultra
    property alias recCursor: cfg.recCursor
    property alias recCopyPath: cfg.recCopyPath         // copy the file path once it stops
    property alias recDir: cfg.recDir
    property alias shotCopy: cfg.shotCopy               // put the image on the clipboard
    property alias shotSave: cfg.shotSave               // write a file (off = clipboard only)
    property alias shotCursor: cfg.shotCursor
    property alias shotDir: cfg.shotDir

    // Debounced: a settings text field re-binds on every keystroke and each write bounces back
    // through watchChanges.
    Timer { id: saveDebounce; interval: 250; onTriggered: store.writeAdapter() }
    FileView {
        id: store
        path: Paths.settingsFile
        // Synchronous: palette, font and wallpaper all bind to these, so an async load would
        // paint a frame of defaults before snapping to the stored theme.
        blockLoading: true
        watchChanges: true
        // A missing file is the first-run case, not an error worth logging.
        printErrors: false
        onFileChanged: store.reload()
        onAdapterUpdated: saveDebounce.restart()
        // Nothing on disk yet -- write the defaults out so there is a file to hand-edit.
        onLoadFailed: store.writeAdapter()
        adapter: JsonAdapter {
            id: cfg
            property bool dnd: false
            property string schemeType: "scheme-tonal-spot"
            // Empty until something is picked. Pointing it at the copy the shell makes of the
            // current pick meant a fresh install opened with two "cannot open" warnings for a
            // file nothing had written yet.
            property string wallpaper: ""
            property bool autoLock: false
            property int autoLockTimeout: 300
            property int dpmsTimeout: 0
            property var appUsage: ({})
            property string activeTheme: "hallownest"   // one of Themes.order
            property bool autoColors: false
            property bool autoLight: false
            property real motionScale: 1.0
            property var vpnProviders: []
            property string vpnSelected: ""
            property string fontPreset: "departure"
            property bool barWorkspaces: true
            property bool barWindow: true
            property bool barTray: true
            property bool barClock: true
            property bool barClock12h: false
            property bool barVolume: true
            property bool barBrightness: true
            property bool barKeyboard: true
            property bool barBattery: true
            property bool barControls: true
            property int dashTab: 0
            property int overviewWidth: 380
            property bool overviewThumbs: true
            property int overviewRefreshMs: 1500
            property int launcherMax: 50
            property string launcherSearchUrl: "https://duckduckgo.com/?q="
            property bool launcherDangerous: true
            property bool clipboardEnabled: true
            property int clipboardMax: 100
            property int notifTimeout: 5000
            property bool notifSuppressFullscreen: true
            property bool notifSuppressGame: true
            property var notifMuted: []
            property string capMode: "shot"
            property string capSource: "region"
            // Matroska, not mp4: written incrementally, so a recording killed by a crash is still
            // playable where an mp4 cut off before its moov atom is not. mp4 is one click away.
            property string recFormat: "mkv"
            property int recFps: 60
            property string recAudio: "desktop"
            property string recQuality: "very_high"
            property bool recCursor: true
            property bool recCopyPath: false
            // Empty means "wherever XDG says videos go", resolved in Capture — a machine whose
            // user directories are not English, or not under $HOME, should not need a settings edit.
            property string recDir: ""
            property bool shotCopy: true
            property bool shotSave: true
            property bool shotCursor: false
            property string shotDir: ""
        }
    }

    // Live Material You: matugen writes assets/theme.json (see Wallpaper.set) and this follows it
    // when autoColors is on, reloading whenever the file changes.
    property var themeObj: null
    function reloadTheme() { try { root.themeObj = JSON.parse(themeFile.text()); } catch (e) { root.themeObj = null; } }
    FileView {
        id: themeFile
        path: Paths.themeFile
        watchChanges: true
        // Absent until matugen has run at least once, which for anyone who never turns on auto
        // colours is forever — a first start should not open with a read error for a file the
        // shell only optionally wants.
        printErrors: false
        onLoaded: root.reloadTheme()
        onFileChanged: { themeFile.reload(); root.reloadTheme(); }
    }

    // --- Active curated theme (palette + video wallpaper + light/dark) ---
    readonly property var preset: Themes.map[activeTheme] ?? Themes.map[Themes.order[0]]
    readonly property bool lightMode: autoColors ? autoLight : preset.light
    // The theme's looping video (wallpaper + lock background). None in auto mode, where the
    // static Config.wallpaper shows through.
    readonly property string videoWallpaper: autoColors ? "" : preset.wallpaper
    // Bump an app's launch count (frequency sorting in the launcher).
    function bumpAppUsage(id) {
        if (!id) return;
        // Copy, don't mutate: an in-place edit fires no change signal, so it is never written out.
        const u = Object.assign({}, cfg.appUsage);
        u[id] = (u[id] || 0) + 1;
        cfg.appUsage = u;
    }
    readonly property var appUsageMap: cfg.appUsage ?? ({})

    // --- Palette ---
    // Anchors are hand-picked per theme (Themes.qml) or mapped from matugen (theme.json);
    // everything "derived" is computed here, so adding a theme stays a 14-line edit. A missing
    // anchor falls through to its derivation, which keeps older sources working.
    //
    // Every derivation branches on lightMode: light brightens toward white, dark tints upward
    // toward its own text colour (Material's surface tint, keeping the hue), and shadows differ
    // in both hue and weight.

    // Source: dynamic from the wallpaper (theme.json) when autoColors is on, else the preset.
    readonly property var autoBlock: (autoColors && themeObj) ? (autoLight ? themeObj.light : themeObj.dark) : null
    readonly property var rawPal: autoBlock ? ({
        background:            autoBlock.background,
        surface:              autoBlock.surface,
        surfaceContainerHigh: autoBlock.surfaceContainerHigh,
        outline:              autoBlock.outline,
        dim:                  autoBlock.surfaceVariantText,
        surfaceText:          autoBlock.surfaceText,
        primary:              autoBlock.primary,
        secondary:            autoBlock.secondary,
        error:                autoBlock.error,
        onPrimary:            autoBlock.onPrimary ?? autoBlock.primaryText
    }) : preset.pal

    // --- Anchors ---
    readonly property color bg:        rawPal.background           ?? "#0d1117"
    readonly property color surface:   rawPal.surface              ?? "#161b22"
    readonly property color container: rawPal.surfaceContainerHigh ?? "#21262d"
    readonly property color outline:   rawPal.outline              ?? "#30363d"
    readonly property color dim:       rawPal.dim                  ?? "#7d8590"
    readonly property color fg:        rawPal.surfaceText          ?? "#e6edf3"
    readonly property color accent:    rawPal.primary              ?? "#ff8c7a"
    readonly property color tertiary:  rawPal.secondary            ?? "#ff7b72"
    readonly property color error:     rawPal.error                ?? "#ff7b72"
    // Semantic anchors, hue-rotated when a source omits them, so a nine-key palette still works.
    readonly property color success:   rawPal.success  ?? CU.hueAt(root.accent, 0.36, 0.42)
    readonly property color warning:   rawPal.warning  ?? CU.hueAt(root.accent, 0.10, 0.62)
    readonly property color info:      rawPal.info     ?? CU.hueAt(root.accent, 0.58, 0.48)
    // Text and icons on an accent fill. An anchor, not a pure derivation: daybreak's accent
    // formally prefers the dark surfaceText, but a filled button there wants white.
    // NOT named onAccent — QML silently drops the binding of any "on"+capital property (it
    // collides with signal-handler syntax); it declares fine and reads back as transparent
    // black, so the failure is invisible until something renders. The JSON key stays
    // `onPrimary`, a plain dict key, matching what matugen emits.
    readonly property color accentText: rawPal.onPrimary ?? CU.readable(root.accent, root.bg, root.fg, 4.5)

    // --- Derived: elevation poles (which way "up" and "down" travel in this mode) ---
    readonly property color poleHi: lightMode ? "#ffffff"    : root.fg
    readonly property color poleLo: lightMode ? root.outline : root.bg

    // --- Derived: surfaces ---
    readonly property color surfaceLow:    CU.step(root.surface,   -1, root.poleHi, root.poleLo)
    readonly property color containerHigh: CU.step(root.container, +1, root.poleHi, root.poleLo)
    // The translucent pill/card that floats over the frame and the video wallpaper.
    readonly property color containerSoft: CU.alpha(root.container, lightMode ? 0.72 : 0.55)

    // --- Derived: accent family ---
    readonly property color accentHover:   CU.mix(root.accent, root.fg, 0.10)
    readonly property color accentPressed: CU.mix(root.accent, root.bg, 0.12)
    readonly property color accentTextDim: CU.alpha(root.accentText, 0.70)
    // Backing plate for an icon sitting on an accent-filled row.
    readonly property color accentPlate:   CU.alpha(root.accentText, 0.18)
    // A destructive affordance is not a failure: this warns what a click will do, error reports
    // that something already went wrong.
    readonly property color danger:        CU.mix(root.error, root.warning, 0.15)

    // --- Derived: tinted containers (a wash of the role over the surface) ---
    readonly property color accentContainer:  CU.alpha(root.accent,  lightMode ? 0.18 : 0.22)
    readonly property color errorContainer:   CU.alpha(root.error,   lightMode ? 0.16 : 0.22)
    readonly property color successContainer: CU.alpha(root.success, lightMode ? 0.16 : 0.22)
    readonly property color warningContainer: CU.alpha(root.warning, lightMode ? 0.16 : 0.22)
    readonly property color infoContainer:    CU.alpha(root.info,    lightMode ? 0.16 : 0.22)

    // --- Derived: text tiers ---
    // Its own tier: dim already carries secondary text, so reusing it makes the two identical
    // (the tray menu had to invent a second tier out of outline).
    readonly property color fgDisabled: CU.alpha(root.fg, 0.38)

    // --- Derived: lines and edges ---
    readonly property color outlineVariant: CU.alpha(root.outline, 0.5)
    readonly property color outlineStrong:  CU.mix(root.outline, root.fg, 0.28)
    readonly property color focusRing:      root.accent
    // The frame's raised edge and its only depth cue (see modules/Frame.qml). Dark themes get a
    // lit rim; light ones have no headroom to brighten into — a highlight measures ~1.05:1 — so
    // they take a darker contact line the way print does. Both land near 2.4:1 and 4.3:1.
    readonly property color bevel: lightMode ? CU.mix(root.outline, root.fg, 0.45)
                                             : root.outlineStrong

    // --- Derived: depth ---
    // Never Qt.darker(): on a near-black bg it hands back a *lighter* grey. An absolute
    // luminance target keeps the hue and stays under the surface at both ends of the range.
    readonly property color shadow: rawPal.shadow
        ?? (lightMode ? CU.tone(CU.mix(root.fg, root.accent, 0.12), 0.015)
                      : CU.tone(root.bg, 0.006))
    // A light theme cannot carry the same shadow weight without looking grubby.
    readonly property real  shadowStrength: lightMode ? 0.42 : 1.0
    readonly property color scrim:      CU.alpha(root.shadow, lightMode ? 0.30 : 0.38)
    readonly property color scrimHeavy: CU.alpha(root.shadow, lightMode ? 0.46 : 0.58)
    // Halo behind text drawn straight on the wallpaper: dark text needs a light halo.
    readonly property color textHalo: lightMode ? CU.tone(root.bg, 0.90) : root.shadow

    // --- Derived: controls ---
    // One track for sliders and progress alike, one off-track for every switch.
    readonly property color track:          root.container
    readonly property color switchTrackOff: root.container

    // --- Derived: interaction state layers ---
    // Opacities rather than colours, so StateLayer's callers keep overriding `tint` freely.
    readonly property real hoverOpacity:  lightMode ? 0.07 : 0.09
    readonly property real pressOpacity:  lightMode ? 0.12 : 0.15
    readonly property real rippleOpacity: lightMode ? 0.13 : 0.16
    readonly property real focusOpacity:  lightMode ? 0.10 : 0.12

    // --- Derived: data colours ---
    // Five categorical slots, so the dashboard's rings stop reading as one flat accent. Even
    // fifths of the accent's hue rather than the semantic roles: info shares a hue family with
    // a blue accent and success with a green one, which blurred two gauges in seven of ten
    // themes. Slot 0 is the accent untouched, so the ramp opens on the theme's own colour.
    readonly property var series: [root.accent,
                                   CU.hueRotate(root.accent, 0.2),
                                   CU.hueRotate(root.accent, 0.4),
                                   CU.hueRotate(root.accent, 0.6),
                                   CU.hueRotate(root.accent, 0.8)]
    // Threshold tint for a 0..1 load figure. `base` is the gauge's own slot, so idle meters stay
    // distinguishable and only converge on the shared warning and error under load.
    function severity(t, base, warnAt, critAt) {
        if (t >= (critAt === undefined ? 0.9 : critAt)) return root.error;
        if (t >= (warnAt === undefined ? 0.75 : warnAt)) return root.warning;
        return base === undefined ? root.accent : base;
    }

    // --- Fonts and shared constants ---
    // Faces are bundled in assets/fonts, so the shell looks the same where none are installed
    // system-wide. The folder is scanned, not listed: dropping a .ttf/.otf in adds a text face.
    // The icon face never changes — no pixel icon set exists to swap in.
    readonly property real popFillet: 30
    readonly property real popCorner: 18
    readonly property string iconFile: "MaterialSymbolsRounded"

    // [{ file, key, label }] — key is the filename without extension, label a readable form.
    // fontAll is everything loaded; fontFiles is what the settings page and launcher offer.
    // Companion faces (an -Italic sibling) stay out of the second list: they must be loaded for
    // italics to render, but picking one as the base face would slant the whole shell.
    property var fontAll: []
    readonly property var fontFiles: fontAll.filter(f => !/-(italic|oblique)$/i.test(f.key))
    // key -> resolved family name, filled in as each FontLoader reports Ready.
    property var fontNames: ({})
    // The old presets were short names — keep `ipc call font set inter` and pre-scan
    // settings.json files resolving.
    readonly property var fontAliases: ({ inter: "InterVariable", departure: "DepartureMono-Regular" })
    readonly property string fontKey: fontAliases[fontPreset] ?? fontPreset
    // Falls back to the eagerly-loaded default face: the scan is a subprocess, so fontNames is
    // empty for the first few frames and every label would otherwise land on the system default.
    readonly property string textFont: fontNames[fontKey] ?? departureFont.name
    readonly property string iconFont: msFont.name

    FontLoader { id: msFont; source: Qt.resolvedUrl("assets/fonts/" + root.iconFile + ".ttf") }
    FontLoader { id: departureFont; source: Qt.resolvedUrl("assets/fonts/DepartureMono-Regular.otf") }

    // "DepartureMono-Regular" -> "Departure Mono Regular", "InterVariable" -> "Inter Variable".
    function prettyFontName(base) {
        return base.replace(/[-_]+/g, " ").replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/\s+/g, " ").trim();
    }
    Process {
        id: fontScan
        running: true
        // The directory goes in as $1, never spliced into the script: quoting it inline breaks the
        // moment the config tree sits under a path containing an apostrophe.
        command: ["sh", "-c", "ls -1 \"$1\" | grep -iE '\\.(ttf|otf)$'", "sh", Paths.fontsDir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.fontAll = text.trim().split("\n").filter(l => l.length > 0).map(l => {
                    const key = l.replace(/\.(ttf|otf)$/i, "");
                    return { file: l, key: key, label: root.prettyFontName(key) };
                }).filter(f => f.key !== root.iconFile);
            }
        }
    }
    Instantiator {
        model: root.fontAll
        delegate: FontLoader {
            source: Qt.resolvedUrl("assets/fonts/" + modelData.file)
            onNameChanged: {
                if (!name) return;
                const m = Object.assign({}, root.fontNames);
                m[modelData.key] = name;
                root.fontNames = m;
            }
        }
    }
}
