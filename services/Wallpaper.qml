pragma Singleton

// Wallpaper list + setting one (persists to Config, regenerates the Material palette via matugen).
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root
    property var list: []

    // Your own folder, and only that. The project ships the looping videos its themes are built
    // around; still images are personal, so there is nothing to bundle and nothing to redistribute.
    readonly property string userDir: Paths.pictures + "/wallpapers"

    Component.onCompleted: scanProc.running = true
    function rescan() { scanProc.running = true; }

    Process {
        id: scanProc
        // The directory goes in as an argument, never spliced into the script, so a space or an
        // apostrophe in the path cannot break it. The copy the shell makes of the current pick is
        // filtered out — it is the same image under another name.
        command: ["sh", "-c",
            'ls -1 "$1"/*.jpg "$1"/*.jpeg "$1"/*.png "$1"/*.webp 2>/dev/null | grep -v static-wallpaper',
            "sh", root.userDir]
        stdout: StdioCollector {
            id: scanOut
            onStreamFinished: { root.list = scanOut.text.trim().split("\n").filter(Boolean); }
        }
    }

    // matugen → gen-theme.py → assets/theme.json, which Config watches and recolours from live.
    // Written to a temp file and renamed so a half-written palette is never read.
    function regen(src) {
        if (!src) return;
        Quickshell.execDetached(["sh", "-c",
            'matugen image "$1" --type "$2" --prefer saturation --json hex '
            + '| python3 "$3" > "$4.tmp" && mv "$4.tmp" "$4"',
            "sh", src, Config.schemeType, Paths.genThemeScript, Paths.themeFile]);
    }

    function set(path) {
        Config.wallpaper = "file://" + path;
        // Keep a copy under a fixed name: the config's default points at it, and it survives the
        // source image being moved or renamed. mkdir -p because a fresh account has no such folder.
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$(dirname "$2")" && cp "$1" "$2"',
            "sh", path, Paths.currentWallpaper]);
        root.regen(path);
    }

    // Re-run matugen on the current wallpaper (e.g. after changing the scheme type).
    function regenTheme() { root.regen((Config.wallpaper || "").replace("file://", "")); }
}
