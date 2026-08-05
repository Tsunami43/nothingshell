pragma Singleton

// Every path the shell reads or writes, in one place.
//
// Two kinds live here and they are kept apart on purpose:
//
//   * things that SHIP — shaders, scripts, fonts, wallpapers. Resolved from this file's own
//     location, so the tree works wherever it is checked out, installed or symlinked, and under
//     whatever name `qs -c <name>` was given.
//   * things that BELONG TO THE USER — settings, the generated palette, the Hyprland fragments
//     the settings window writes. These follow the XDG base directories and never land inside the
//     tree, so a clone can be pulled over or thrown away without taking anyone's settings with it.
//
// No home directory is spelled out by hand anywhere else in the tree. Half a dozen services used
// to carry their own hardcoded paths, which meant the shell only ever worked on the machine it
// was written on, under the name it happened to have that week.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // The name this desktop calls itself: the quickshell config name, the directories below, and
    // anything it leaves elsewhere — so everything it owns is greppable by one word.
    readonly property string appName: "nothingshell"

    // --- Shipped with the tree ------------------------------------------------------------
    // The trailing slash is added by hand: Qt.resolvedUrl(".") comes back without one, and every
    // path below is built by concatenation.
    readonly property string shellDir: Qt.resolvedUrl(".").toString().replace("file://", "") + "/"
    readonly property string assetsDir: root.shellDir + "assets"
    readonly property string fontsDir: root.assetsDir + "/fonts"
    readonly property string wallpapersDir: root.assetsDir + "/wallpapers"
    readonly property string genThemeScript: root.shellDir + "gen-theme.py"
    readonly property string focusSenderScript: root.assetsDir + "/focus-sender.sh"
    readonly property string cavaConfig: root.assetsDir + "/cava.conf"

    // --- XDG base directories ---------------------------------------------------------------
    readonly property string home: Quickshell.env("HOME")
    // The user's own media directories, which are not always under $HOME and not always English —
    // xdg-user-dirs exports these into the session.
    readonly property string pictures: Quickshell.env("XDG_PICTURES_DIR") || (root.home + "/Pictures")
    readonly property string videos: Quickshell.env("XDG_VIDEOS_DIR") || (root.home + "/Videos")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (root.home + "/.local/state")
    // Falls back to /tmp: XDG_RUNTIME_DIR is normally set by the session, but the greeter and a
    // shell started from a bare TTY are exactly the cases where it may not be.
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    // --- The user's own -----------------------------------------------------------------------
    readonly property string configDir: root.configHome + "/" + root.appName
    readonly property string stateDir: root.stateHome + "/" + root.appName
    // The store. Hand-editable while the shell runs — it watches this file and applies changes live.
    readonly property string settingsFile: root.configDir + "/settings.json"
    // matugen's output. Generated, never authored, and reproducible from the wallpaper at any
    // time — so it belongs in state, not among the things a person edits or backs up.
    readonly property string themeFile: root.stateDir + "/theme.json"
    // Hyprland fragments the settings window regenerates in full (displays, keyboard layouts).
    // Source them from hyprland.conf; see hypr/nothingshell.conf.
    readonly property string hyprDir: root.configDir + "/hypr"
    readonly property string monitorsConf: root.hyprDir + "/monitors.conf"
    readonly property string inputConf: root.hyprDir + "/input.conf"
    // Where the picked still is copied under a fixed name, for anything outside the shell that
    // wants to know what the wallpaper is.
    readonly property string currentWallpaper: root.pictures + "/wallpapers/static-wallpaper.png"
    // stderr of the detached recorder — the one thing a failed launch can still report.
    readonly property string captureLog: root.runtimeDir + "/" + root.appName + "-capture.log"

    // The directories above have to exist before anything writes into them, and neither FileView
    // nor a shell redirect creates a parent. One mkdir at startup covers every writer.
    //
    // The two Hyprland fragments are touched into existence in the same breath. They are written
    // for real only once someone opens Settings > Displays or Language & input, but the `source =`
    // lines that pick them up live in hyprland.conf from the start, and a missing file there is a
    // hard error in Hyprland. An empty fragment is a valid one; the settings window overwrites it.
    Component.onCompleted: mkdirs.running = true
    Process {
        id: mkdirs
        command: ["sh", "-c", 'mkdir -p "$1" "$2" "$3" && touch "$4" "$5"', "sh",
            root.configDir, root.hyprDir, root.stateDir, root.monitorsConf, root.inputConf]
    }
}
