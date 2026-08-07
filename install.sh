#!/bin/bash
# nothingshell — the parts of installing it that a clone cannot do by itself.
#
# Cloning this repository into ~/.config/quickshell/nothingshell IS the installation: the tree is
# the quickshell config, the shaders come baked, there is nothing to build. What is left over is
# everything outside the tree — the packages, the one `source =` line in hyprland.conf, and
# starting the thing — and that is all this script does. It is a convenience, not a package
# manager: run it or do the four steps by hand from the README, the result is the same.
#
#   ./install.sh              ask before each step
#   ./install.sh -y           assume yes (also what happens with no terminal to ask at)
#   ./install.sh --no-deps    skip the packages, do the rest
#   ./install.sh --no-start   install, but do not launch the shell
#
# Never run this with sudo. It writes into your home, and a root-owned ~/.config is a mess to
# undo. The one part that does need root — the login screen — is a separate script you run
# yourself afterwards; it is only mentioned at the end here, never invoked.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DEST="$CONFIG_HOME/quickshell/nothingshell"
HYPR_CONF="$CONFIG_HOME/hypr/hyprland.conf"
SOURCE_LINE="source = $DEST/hypr/nothingshell.conf"

ASSUME_YES=0
DO_DEPS=1
DO_START=1

for arg in "$@"; do
    case "$arg" in
        -y|--yes)   ASSUME_YES=1 ;;
        --no-deps)  DO_DEPS=0 ;;
        --no-start) DO_START=0 ;;
        -h|--help)  sed -n '2,17p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *)          echo "unknown option: $arg (try --help)" >&2; exit 1 ;;
    esac
done

if [ "$(id -u)" -eq 0 ]; then
    echo "do not run this as root — it installs into your own home directory." >&2
    echo "(the packages step asks for sudo on its own, and the greeter has its own script.)" >&2
    exit 1
fi

say()  { printf '\n\033[1m==>\033[0m %s\n' "$1"; }
note() { printf '    %s\n' "$1"; }

# Default yes, so that -y and a pipe with no terminal behave the same as pressing enter.
ask() {
    [ "$ASSUME_YES" -eq 1 ] && return 0
    [ -t 0 ] || return 0
    local reply
    read -r -p "    $1 [Y/n] " reply
    case "$reply" in [nN]*) return 1 ;; *) return 0 ;; esac
}

# --- Packages -------------------------------------------------------------------------------
# Only Arch is automated, because the package names below are Arch's. Everywhere else the honest
# thing is to print what is needed and let the person translate it — a wrong guess at a Debian
# name installs the wrong thing silently.
#
# Five are required; everything after them backs exactly one feature and its absence costs only
# that feature, so a package that is missing from the repositories is a note, not a failure.
REQUIRED=(quickshell hyprland qt6-shadertools qt6-declarative qt6-multimedia)
OPTIONAL=(networkmanager bluez-utils wl-clipboard grim slurp libnotify python cava ddcutil
          brightnessctl xdg-utils pciutils upower otf-atkinsonhyperlegiblemono-nerd)
AUR=(gpu-screen-recorder matugen)

install_packages() {
    if ! command -v pacman >/dev/null 2>&1; then
        say "Dependencies"
        note "Not an Arch system, so nothing is installed for you. Install these, by whatever"
        note "name your distribution gives them:"
        note ""
        note "  required: ${REQUIRED[*]}"
        note "  optional: ${OPTIONAL[*]} ${AUR[*]}"
        note ""
        note "The first five are required. quickshell 0.3.0 and Hyprland 0.55 are the versions"
        note "this is built against. Everything else backs one feature and costs only that one."
        ask "Continue without installing them?" || exit 1
        return
    fi

    say "Dependencies (pacman)"
    # Split by what your repositories actually carry, rather than handing pacman a list it will
    # reject wholesale over one name. quickshell in particular is in the official repos on some
    # setups and the AUR on others.
    local have=() missing=()
    for pkg in "${REQUIRED[@]}" "${OPTIONAL[@]}"; do
        if pacman -Si "$pkg" >/dev/null 2>&1 || pacman -Qi "$pkg" >/dev/null 2>&1; then
            have+=("$pkg")
        else
            missing+=("$pkg")
        fi
    done

    if [ "${#have[@]}" -gt 0 ]; then
        note "pacman -S --needed ${have[*]}"
        if ask "Install these?"; then
            sudo pacman -S --needed "${have[@]}"
        fi
    else
        note "None of these are in your repositories — is the package database synced?"
    fi

    # The AUR half: whatever the repositories did not have, plus the two that are AUR-only by
    # nature. No helper is installed on your behalf — if there is none, the names get printed.
    local aur=("${missing[@]}" "${AUR[@]}")
    local helper=""
    for h in paru yay pikaur trizen; do
        command -v "$h" >/dev/null 2>&1 && { helper="$h"; break; }
    done
    if [ -n "$helper" ]; then
        note ""
        note "$helper -S --needed ${aur[*]}"
        if ask "Install these from the AUR?"; then
            "$helper" -S --needed "${aur[@]}" || note "some AUR builds failed — see above"
        fi
    else
        note ""
        note "No AUR helper found. These are AUR-only and stay uninstalled:"
        note "  ${aur[*]}"
        note "gpu-screen-recorder backs recording, matugen backs wallpaper-derived palettes."
    fi

    # Two things pacman cannot arrange, both from the README's list of surprises.
    if command -v ddcutil >/dev/null 2>&1 && ! id -nG | grep -qw i2c; then
        note ""
        note "ddcutil is installed but your user is not in the 'i2c' group, so every external"
        note "monitor brightness read will fail silently and the widget will hide itself:"
        note "  sudo modprobe i2c-dev && sudo usermod -aG i2c $USER   (then log out and back in)"
    fi

    # The laptop half: writing the backlight needs the 'video' group the udev rule grants to.
    if ls /sys/class/backlight/* >/dev/null 2>&1 && ! id -nG | grep -qw video; then
        note ""
        note "This machine has a backlight but your user is not in the 'video' group, so the"
        note "brightness widget will read but not write:"
        note "  sudo usermod -aG video $USER   (then log out and back in)"
    fi
}

# --- The clone ------------------------------------------------------------------------------
# quickshell resolves `qs -c nothingshell` to $XDG_CONFIG_HOME/quickshell/nothingshell, so the
# tree has to be at that path. If this script is already running from there — the normal case,
# cloned straight to the right place — there is nothing to do.
place_clone() {
    say "Config location"
    if [ "$SRC" = "$DEST" ]; then
        note "Already at $DEST — nothing to move."
        return
    fi

    if [ -e "$DEST" ]; then
        note "Something is already at $DEST, and this script will not touch it."
        note "That is where quickshell looks for the config, so either it is already the"
        note "installation (then just pull in it), or move it aside first."
        note "This checkout stays where it is: $SRC"
        return
    fi

    # Clone from the same remote this checkout came from, so `git pull` keeps working in the
    # installed copy. A tree with no remote — a tarball, or someone's local-only work — gets
    # copied instead, which installs but does not update.
    local origin=""
    if git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1; then
        origin="$(git -C "$SRC" remote get-url origin 2>/dev/null || true)"
    fi

    if [ -n "$origin" ]; then
        note "Cloning $origin into $DEST"
        ask "Do that?" || return
        mkdir -p "$(dirname "$DEST")"
        # A failed clone is the end of the run, not something to carry on past: the next step
        # would write a `source =` line pointing at a directory that does not exist, and a
        # missing sourced file is a hard error in Hyprland — a broken config in exchange for a
        # failed download.
        if ! git clone "$origin" "$DEST"; then
            rm -rf "$DEST"
            echo >&2
            echo "could not clone $origin into $DEST." >&2
            echo "clone it yourself (the README's one-liner), then re-run this from there." >&2
            exit 1
        fi
    else
        note "This checkout has no origin remote, so it will be copied to $DEST rather than"
        note "cloned. Updating it later means copying again, not 'git pull'."
        ask "Copy it?" || return
        mkdir -p "$(dirname "$DEST")"
        cp -a "$SRC" "$DEST"
    fi
}

# --- Hyprland -------------------------------------------------------------------------------
# One line, appended once. The file it points at claims SUPER+Space, SUPER+N and the Print keys,
# which is why this asks rather than assumes — a binding you already use would be shadowed by it,
# and Hyprland gives no warning when that happens.
wire_hyprland() {
    say "Hyprland"
    if [ ! -f "$HYPR_CONF" ]; then
        note "No $HYPR_CONF here. Add this line to yours, wherever it lives:"
        note "  $SOURCE_LINE"
        return
    fi
    if grep -qF "hypr/nothingshell.conf" "$HYPR_CONF"; then
        note "Already sourced from $HYPR_CONF."
        return
    fi

    note "This appends to $HYPR_CONF:"
    note "  $SOURCE_LINE"
    note ""
    note "It claims SUPER+Space (launcher), SUPER+N (settings) and the"
    note "Print keys. Read $DEST/hypr/nothingshell.conf first if you have bindings there."
    if ask "Append it?"; then
        cp -a "$HYPR_CONF" "$HYPR_CONF.bak-$(date +%Y%m%d-%H%M%S)"
        printf '\n# nothingshell\n%s\n' "$SOURCE_LINE" >> "$HYPR_CONF"
        note "Appended. A backup of the previous file sits next to it."
        command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] \
            && hyprctl reload >/dev/null && note "hyprctl reload: done"
    else
        note "Skipped. The shell still runs; the keybinds just are not bound."
    fi
}

# --- Start ----------------------------------------------------------------------------------
start_shell() {
    say "Starting"
    if ! command -v qs >/dev/null 2>&1; then
        note "quickshell (qs) is not on PATH, so there is nothing to start yet."
        note "Install it, then: qs -c nothingshell -d"
        return
    fi
    if [ -z "${WAYLAND_DISPLAY:-}" ]; then
        note "No Wayland session here (WAYLAND_DISPLAY is unset). Inside Hyprland, run:"
        note "  qs -c nothingshell -d"
        return
    fi

    if ask "Start it now (replacing any running instance)?"; then
        qs -c nothingshell kill >/dev/null 2>&1 || true
        qs -c nothingshell -d
        note "Started. 'qs -c nothingshell log' is its log; errors say ERROR: and name the line."
    fi
}

[ "$DO_DEPS" -eq 1 ] && install_packages
place_clone
wire_hyprland
[ "$DO_START" -eq 1 ] && start_shell

say "Done"
note "Settings:  SUPER+N, or the launcher's Settings entry"
note "IPC:       qs -c nothingshell ipc show"
note "Update:    cd $DEST && git pull   (quickshell reloads as files change)"
note ""
note "The login screen is optional, separate, and needs root — it takes a copy of the shell"
note "rather than reading your checkout. If you want it:"
note "  sudo $DEST/greeter/install.sh"
