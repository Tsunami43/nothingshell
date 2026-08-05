pragma Singleton

// Pushes the shell's palette into Hyprland: window/group borders and the compositor's
// own background colour follow the active theme. Applied with `hyprctl keyword` and nothing
// else — whatever colours your own config sets stay in the file untouched, and the
// `configreloaded` event below re-applies the live theme on top of them.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

Singleton {
    id: root

    // QML colours stringify as #rrggbb (or #aarrggbb); Hyprland wants rgb()/rgba()
    // with the alpha last.
    function hyprColor(c) {
        const s = String(c);
        return s.length === 9 ? `rgba(${s.slice(3)}${s.slice(1, 3)})` : `rgb(${s.slice(1)})`;
    }

    // Hyprland takes rgba(RRGGBBAA); build one from a colour plus an explicit alpha.
    function hyprColorAlpha(c, a) {
        const s = String(c);
        const rgb = s.length === 9 ? s.slice(3) : s.slice(1);
        return `rgba(${rgb}${Math.round(Math.max(0, Math.min(1, a)) * 255).toString(16).padStart(2, "0")})`;
    }

    // Every colour Hyprland draws chrome with, plus the compositor background
    // and the window drop shadow (tinted with the theme's darkest tone instead of flat black,
    // so windows sit on the same depth as the shell's own shadows).
    function apply() {
        const primary = root.hyprColor(Config.accent);
        const outline = root.hyprColor(Config.outline);
        const error = root.hyprColor(Config.error);
        // The shell's own shadow tone, so windows and panels sit at the same depth.
        const shadowTone = Config.shadow;
        Quickshell.execDetached(["hyprctl", "--batch",
            `keyword decoration:shadow:color ${root.hyprColorAlpha(shadowTone, 0.8)} ; ` +
            `keyword decoration:shadow:color_inactive ${root.hyprColorAlpha(shadowTone, 0.5)} ; ` +
            `keyword general:col.active_border ${primary} ; ` +
            `keyword general:col.inactive_border ${outline} ; ` +
            `keyword group:col.border_active ${primary} ; ` +
            `keyword group:col.border_inactive ${outline} ; ` +
            `keyword group:col.border_locked_active ${error} ; ` +
            `keyword group:col.border_locked_inactive ${outline} ; ` +
            `keyword group:groupbar:col.active ${primary} ; ` +
            `keyword group:groupbar:col.inactive ${outline} ; ` +
            `keyword group:groupbar:col.locked_active ${error} ; ` +
            `keyword group:groupbar:col.locked_inactive ${outline} ; ` +
            `keyword misc:background_color ${root.hyprColor(Config.bg)}`]);
    }

    // Switching a theme changes several colours at once; coalesce into one hyprctl call.
    Timer {
        id: debounce
        interval: 50
        onTriggered: root.apply()
    }
    Connections {
        target: Config
        function onAccentChanged() { debounce.restart(); }
        function onOutlineChanged() { debounce.restart(); }
        function onBgChanged() { debounce.restart(); }
        // A theme can anchor its own shadow, so this moves without bg moving.
        function onShadowChanged() { debounce.restart(); }
    }

    // A config reload (game mode leaving, or Hyprland picking up an edited hyprland.conf)
    // drops the keywords set above, so put them back.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                debounce.restart();
        }
    }
}
