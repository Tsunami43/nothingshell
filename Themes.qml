pragma Singleton

// Curated theme presets: a looping video wallpaper plus the palette that drives the whole
// shell. A palette carries only anchors; Config derives the other twenty-odd roles.
//   Structural: background / surface / surfaceContainerHigh / outline / dim / surfaceText
//   Accent:     primary / secondary, plus onPrimary for text on a primary fill
//   Semantic:   success / warning / info / error
//   Depth:      shadow, the tone every drop shadow and scrim is built from
// Only the structural six are required — Config rotates the semantics off the primary, picks
// onPrimary by contrast and derives shadow from the background. They are spelled out anyway:
// a hue taken from the theme's own palette or wallpaper beats a rotation.
import QtQuick
import Quickshell

Singleton {
    // Resolved from this file, not from the running shell root — the greeter imports this tree
    // from its own root and must still find the clips here. Paths would be a cycle.
    readonly property string dir: Qt.resolvedUrl("assets/wallpapers").toString().replace("file://", "") + "/"

    // Selection order (also used by the sidebar cycler).
    readonly property var order: ["hallownest", "overgrowth", "daybreak", "downpour",
                                  "sakura", "cyberpunk", "emerald", "glacier", "mocha", "nightfall"]

    readonly property var map: ({
        // pixel-hollowknight — near-black void, warm amber glow, one cold white flare.
        // The pale blue is that flare; the amber the wallpaper is soaked in is the secondary.
        "hallownest": {
            title: "Hallownest",
            light: false,
            wallpaper: dir + "hallownest.mp4",
            pal: {
                background: "#0b0d12", surface: "#141821", surfaceContainerHigh: "#1f2532",
                outline: "#39414f", dim: "#7c8698", surfaceText: "#e7ebf3",
                primary: "#b3d0ea", secondary: "#d99a52", error: "#e06c75",
                onPrimary: "#0b0d12",
                success: "#7fb98a", warning: "#e8b04a", info: "#8fb8dd",
                shadow: "#05070a"
            }
        },
        // last-of-us — golden sunset through a window, green ivy, dark interior.
        // Gruvbox-rooted, but the dominant light in frame is gold, not lime.
        "overgrowth": {
            title: "Overgrowth",
            light: false,
            wallpaper: dir + "overgrowth.mp4",
            pal: {
                background: "#1a1a18", surface: "#252420", surfaceContainerHigh: "#37332c",
                outline: "#504945", dim: "#928374", surfaceText: "#ebdbb2",
                primary: "#e8a94a", secondary: "#8ab04b", error: "#fb4934",
                onPrimary: "#1a1a18",
                success: "#a9c05f", warning: "#d9822f", info: "#83a598",
                shadow: "#0c0c0a"
            }
        },
        // pixel-munchlax — bright daylight: saturated sky, grass, a yellow flower.
        // A light theme: semantics darkened for near-white, shadow a deep slate (black reads as
        // dirt here).
        "daybreak": {
            title: "Daybreak",
            light: true,
            wallpaper: dir + "daybreak.mp4",
            pal: {
                background: "#f4f5f7", surface: "#ffffff", surfaceContainerHigh: "#e9ecf1",
                outline: "#ccd2dc", dim: "#79808c", surfaceText: "#1b1e26",
                primary: "#3f72c4", secondary: "#5aa63c", error: "#d64c4c",
                onPrimary: "#ffffff",
                success: "#3f9e52", warning: "#a8701a", info: "#2f80c4",
                shadow: "#2a3340"
            }
        },
        // pixel-rainyroom — tokyo night. dim is lifted off the upstream comment colour,
        // which is tuned for syntax highlighting and too faint for secondary UI text.
        "downpour": {
            title: "Downpour",
            light: false,
            wallpaper: dir + "downpour.mp4",
            pal: {
                background: "#1a1b26", surface: "#24283b", surfaceContainerHigh: "#2f334d",
                outline: "#414868", dim: "#7a83ad", surfaceText: "#c0caf5",
                primary: "#7aa2f7", secondary: "#bb9af7", error: "#f7768e",
                onPrimary: "#1a1b26",
                success: "#9ece6a", warning: "#e0af68", info: "#7dcfff",
                shadow: "#0a0b12"
            }
        },
        // pixel-sakura — pale misty sky, slate-blue city, cherry blossom, a red sun.
        // Light because the wallpaper is; a dark panel fought the image. The blossom pink is
        // deepened until it carries white.
        "sakura": {
            title: "Sakura",
            light: true,
            wallpaper: dir + "sakura.mp4",
            pal: {
                background: "#eef0f4", surface: "#f8f9fc", surfaceContainerHigh: "#e2e6ee",
                outline: "#c3cad8", dim: "#6d7789", surfaceText: "#232a38",
                primary: "#b8496e", secondary: "#5b6b8a", error: "#d1495b",
                onPrimary: "#ffffff",
                success: "#5a8a68", warning: "#a8701a", info: "#3f6b9e",
                shadow: "#3a4155"
            }
        },
        // pixel-cyberpunk — cyan neon and magenta on a navy-teal industrial deck.
        // Semantics hand-picked: rotating off this cyan gives a poisonous green and returns the
        // primary itself as info.
        "cyberpunk": {
            title: "Cyberpunk",
            light: false,
            wallpaper: dir + "cyberpunk.mp4",
            pal: {
                background: "#080d14", surface: "#111722", surfaceContainerHigh: "#1a2130",
                outline: "#2a3245", dim: "#6b7394", surfaceText: "#d8e0ff",
                primary: "#5ce5e6", secondary: "#ff4766", error: "#f7768e",
                onPrimary: "#080d14",
                success: "#3ddc97", warning: "#ffb454", info: "#54a0ff",
                shadow: "#00060c"
            }
        },
        // pixel-emerald — bright scene: grass, cyan water, warm sand, open sky.
        // Dark chrome over a bright wallpaper, hues from the frame. success sits clear of the
        // green primary: both land in the ring ramp and match at equal lightness.
        "emerald": {
            title: "Emerald",
            light: false,
            wallpaper: dir + "emerald.mp4",
            pal: {
                background: "#0e1613", surface: "#16211c", surfaceContainerHigh: "#1f2e27",
                outline: "#2e4239", dim: "#6d8a7d", surfaceText: "#dcefe5",
                primary: "#4ecb71", secondary: "#3fb8c9", error: "#e06c75",
                onPrimary: "#0e1613",
                success: "#7ee08f", warning: "#e8b355", info: "#5fb3e0",
                shadow: "#060d0a"
            }
        },
        // winter — nord, misty snow over dark pines. dim is lifted off nord3, which is a
        // comment grey and does not carry secondary text on the raised containers.
        "glacier": {
            title: "Glacier",
            light: false,
            wallpaper: dir + "glacier.mp4",
            pal: {
                background: "#2b323d", surface: "#3b4252", surfaceContainerHigh: "#434c5e",
                outline: "#4c566a", dim: "#96a2b8", surfaceText: "#eceff4",
                primary: "#88c0d0", secondary: "#81a1c1", error: "#bf616a",
                onPrimary: "#2b323d",
                success: "#a3be8c", warning: "#ebcb8b", info: "#8fbcbb",
                shadow: "#161b22"
            }
        },
        // pixel-coffee — catppuccin mocha: violet brick, amber lantern.
        // Surface order restored to mantle < base < surface0 — its surface sat darker than its
        // background, inverting every derived depth tier.
        "mocha": {
            title: "Mocha",
            light: false,
            wallpaper: dir + "mocha.mp4",
            pal: {
                background: "#181825", surface: "#1e1e2e", surfaceContainerHigh: "#313244",
                outline: "#45475a", dim: "#7f849c", surfaceText: "#cdd6f4",
                primary: "#fab387", secondary: "#cba6f7", error: "#f38ba8",
                onPrimary: "#181825",
                success: "#a6e3a1", warning: "#f9e2af", info: "#89b4fa",
                shadow: "#11111b"
            }
        },
        // pixel-night-city — violet night skyline, magenta and pink neon.
        "nightfall": {
            title: "Nightfall",
            light: false,
            wallpaper: dir + "nightfall.mp4",
            pal: {
                background: "#100e1c", surface: "#191630", surfaceContainerHigh: "#231f3c",
                outline: "#2e3350", dim: "#6a7099", surfaceText: "#d5dbf5",
                primary: "#a78bfa", secondary: "#f472b6", error: "#f7768e",
                onPrimary: "#100e1c",
                success: "#5eead4", warning: "#fbbf24", info: "#60a5fa",
                shadow: "#06050d"
            }
        }
    })
}
