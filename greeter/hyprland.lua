-- Compositor config for the greetd greeter on Hyprland 0.55+ (installed to /etc/greetd/hyprland.lua;
-- install.sh picks hyprland.conf instead for older builds). It runs as the `greeter` user and hosts
-- nothing but the quickshell greeter surface.

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- install.sh rewrites the placeholder to wherever this config tree actually lives — the
-- `greeter` account has its own $HOME, so the path has to be absolute here.
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -p @GREETER_ENTRY@")
end)

hl.config({
    -- Same keyboard setup as the user session, so the password is typed with the expected layout.
    input = {
        kb_layout          = "us,ru",
        kb_options         = "grp:caps_toggle",
        numlock_by_default = true,
        follow_mouse       = 1,
    },
    general = {
        border_size = 0,
        gaps_in     = 0,
        gaps_out    = 0,
    },
    decoration = {
        rounding = 0,
        blur     = { enabled = false },
    },
    animations = {
        enabled = false,
    },
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = "rgb(000000)",
    },
})

-- Escape hatch: quit the compositor so greetd restarts the greeter if it ever wedges.
hl.bind("CTRL + ALT + Delete", hl.dsp.exit())
