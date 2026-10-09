-- nothingshell — Hyprland integration, for a Lua config (Hyprland 0.55+).
--
--   require("~/.config/quickshell/nothingshell/hypr/nothingshell")
--
-- at the end of your hyprland.lua, or copy the lines you want. The same wiring as
-- nothingshell.conf, which is what a hyprland.conf sources instead. Nothing here configures
-- Hyprland itself — it is only the wiring between the compositor and the shell.

local qs = "qs -c nothingshell"

-- --- Startup -----------------------------------------------------------------------------
-- The baked shaders come with the clone, so there is nothing to build before starting.
hl.on("hyprland.start", function()
    hl.exec_cmd(qs)
end)

-- --- Layer rules -------------------------------------------------------------------------
-- The shell animates its own panels; letting Hyprland animate the layer surfaces as well fights
-- it (the bar slides while the frame behind it eases separately).
hl.layer_rule({
    name    = "nothingshell-no-anim",
    match   = { namespace = "^(quickshell)$" },
    no_anim = true,
})

-- --- Shell keybinds ----------------------------------------------------------------------
-- The launcher: apps, and prefixes for commands (>), clipboard (#), calculator (=), a shell
-- command ($) and emoji (:).
hl.bind("SUPER + space", hl.dsp.exec_cmd(qs .. " ipc call launcher toggle"))
-- Open it straight into a mode, e.g. the theme carousel.
-- hl.bind("SUPER + SHIFT + space", hl.dsp.exec_cmd(qs .. " ipc call launcher open '>theme'"))

-- The lock screen. The session menu has no binding on purpose — it is the power button at the
-- bottom of the bar, which opens on hover, and one fewer key taken out of your config. Bind it
-- yourself if you want one: qs -c nothingshell ipc call session toggle
hl.bind("SUPER + ALT + L", hl.dsp.exec_cmd(qs .. " ipc call lock lock"))

-- Settings window, optionally deep-linked to a page id (see modules/settings/PageRegistry.qml).
hl.bind("SUPER + N", hl.dsp.exec_cmd(qs .. " ipc call settings toggle"))
-- hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd(qs .. " ipc call settings open appearance"))

-- --- Panels without a pointer --------------------------------------------------------------
-- The same hover-opened surfaces, on keys.
-- hl.bind("SUPER + D",   hl.dsp.exec_cmd(qs .. " ipc call dashboard toggle"))
-- hl.bind("SUPER + Tab", hl.dsp.exec_cmd(qs .. " ipc call overview toggle"))
-- One popout by name: volume, rec, brightness, network, bluetooth, vpn, traymenu, power.
-- hl.bind("SUPER + W", hl.dsp.exec_cmd(qs .. " ipc call bar popout network"))

-- Media keys through MPRIS, so playerctl is not needed.
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(qs .. " ipc call media playpause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(qs .. " ipc call media playpause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(qs .. " ipc call media next"),      { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(qs .. " ipc call media previous"),  { locked = true })

-- --- Screenshots and recording -----------------------------------------------------------
-- The shell owns the whole flow: it takes its own panels out of the frame first, remembers the
-- format/fps/audio settings, and drives pause and stop from the bar.
hl.bind("Print",                 hl.dsp.exec_cmd(qs .. " ipc call capture shot region"))
hl.bind("CTRL + Print",          hl.dsp.exec_cmd(qs .. " ipc call capture shot screen"))
hl.bind("SUPER + Print",         hl.dsp.exec_cmd(qs .. " ipc call capture panel"))
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd(qs .. " ipc call capture toggle"))
hl.bind("SUPER + ALT + Print",   hl.dsp.exec_cmd(qs .. " ipc call capture pause"))
-- Works with the shell stopped, which is the point of keeping it.
hl.bind("SUPER + CTRL + Print",  hl.dsp.exec_cmd([[sh -c 'grim -g "$(slurp)" - | wl-copy']]))

-- --- Clipboard history --------------------------------------------------------------------
-- The history skips anything a password manager marks as a secret, but nothing marks a password
-- typed into a form by hand. `pause` stops recording without discarding what is already there.
-- hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd(qs .. " ipc call clipboard toggle"))
-- hl.bind("SUPER + CTRL + V",  hl.dsp.exec_cmd(qs .. " ipc call clipboard clear"))

-- --- Game mode -----------------------------------------------------------------------------
-- Drops animations, blur, shadows, gaps and rounding, and suppresses notifications and idle.
-- Leaving it re-runs `hyprctl reload`, which restores whatever your config says.
-- hl.bind("SUPER + G", hl.dsp.exec_cmd(qs .. " ipc call gamemode toggle"))

-- --- Written by the shell ------------------------------------------------------------------
-- Settings > Displays and Settings > Language & input regenerate these two files in full and
-- apply the change live. Do not hand-edit them: the next change from the settings window
-- overwrites the file wholesale. Neither exists until you open its page, which pcall shrugs off.
-- Require this file LAST in hyprland.lua, so they win over your own monitor and input settings.
local generated = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/nothingshell/hypr/"
pcall(require, generated .. "monitors")
pcall(require, generated .. "input")
