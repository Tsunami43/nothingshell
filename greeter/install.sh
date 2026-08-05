#!/bin/bash
# Point greetd at this quickshell greeter (run as root: sudo ./install.sh).
# Installs the compositor config + session command, takes a root-owned copy of the QML the
# greeter executes, prepares a writable state dir for the `greeter` account, and rewrites
# greetd's default_session command — keeping a timestamped backup of /etc/greetd/config.toml
# so the previous greeter can be restored.
#
# RE-RUN THIS after changing anything under quickshell/: the greeter runs from the copy below,
# not from the live tree, so edits do not reach the login screen until it is refreshed.
#
# `sudo ./install.sh --uninstall` undoes all of it: greetd's config goes back to the backup from
# before this greeter existed, and the copy is removed. Run it BEFORE deleting the checkout —
# this script lives inside it.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
CONF=/etc/greetd/config.toml
CACHE=/var/cache/nothingshell-greeter
# Not /etc: this is 17MB of QML, fonts and shaders, which is data, not configuration.
SHELL_DIR=/var/lib/nothingshell-greeter

if [ "$(id -u)" -ne 0 ]; then
    echo "run as root: sudo $0" >&2
    exit 1
fi

# --uninstall: put greetd back the way it was and take the copy away again.
#
# Picking the backup to restore is the whole reason this is a script and not a line in the
# README. Every run of this installer makes one, including runs when nothingshell was ALREADY
# installed — so the newest backup is usually a config that points right back here, and
# restoring it is a no-op that looks like a fix. What is wanted is the newest backup from
# before this greeter existed, which is the newest one whose command is not our session.sh.
if [ "${1:-}" = "--uninstall" ]; then
    restore=""
    for b in $(ls -t "$CONF".bak-* 2>/dev/null); do
        grep -q '^command = "/etc/greetd/session.sh"' "$b" || { restore="$b"; break; }
    done

    if [ -n "$restore" ]; then
        cp -a "$restore" "$CONF"
        echo "restored $CONF from $restore"
    else
        echo "no backup from before nothingshell was installed — $CONF is left as it is." >&2
        echo "point its command = line at your previous greeter by hand (agreety, tuigreet, …)," >&2
        echo "or greetd will start a login screen that is no longer there." >&2
    fi

    rm -rf "$SHELL_DIR" "$CACHE" /etc/greetd/hyprland.conf /etc/greetd/session.sh
    echo "removed $SHELL_DIR, $CACHE, /etc/greetd/hyprland.conf, /etc/greetd/session.sh"
    echo "the timestamped backups are left alone; delete them yourself once you are happy."
    echo
    echo "apply it with:  sudo systemctl restart greetd    # kills the current graphical session!"
    exit 0
fi

PROJECT="$(dirname "$SRC")"                   # the checkout, which is the shell's config root
WALLPAPERS="$PROJECT/assets/wallpapers"

# The greeter must not run QML straight out of the checkout. That is code executed by another
# account, before anyone has logged in, from a directory the user can write — so anything that
# could write to the user's files would get to run as `greeter` at boot. The code is copied
# here instead, root-owned and read-only to everyone else.
#
# The wallpapers are the exception: 200MB of video that would double on every install, and
# video decoded by ffmpeg is a far smaller thing to hand an attacker than arbitrary QML. They
# stay in the user's tree and are linked back in. Without the ACL below the link simply
# cannot be read and the greeter falls back to a flat background — no longer a hard failure.
rm -rf "$SHELL_DIR"
install -d -m 755 "$SHELL_DIR"
# The whole config root, minus the video. greeter.qml lives in it as a second entry point, so
# there is nothing to assemble: what greetd starts is one file inside a normal copy of the shell.
tar -C "$PROJECT" -cf - --exclude='assets/wallpapers' --exclude='.git' \
    assets components modules services greeter hypr \
    shell.qml greeter.qml qmldir Config.qml Themes.qml Motion.qml Paths.qml colorutil.js gen-theme.py \
    | tar -C "$SHELL_DIR" -xf -
ln -sfn "$WALLPAPERS" "$SHELL_DIR/assets/wallpapers"
chown -R root:root "$SHELL_DIR"
chmod -R go-w "$SHELL_DIR"

# Which account to log in and what to start for it — the two things that cannot be guessed from
# the code. The user is whoever ran sudo; the session command is the Exec of the installed
# wayland session, preferring Hyprland since that is what the shell is built against. An existing
# greeter.json in the checkout wins: someone who wrote one meant it.
if [ -f "$SRC/greeter.json" ]; then
    install -m 644 "$SRC/greeter.json" "$SHELL_DIR/greeter/greeter.json"
    echo "greeter.json: taken from the checkout"
else
    GREET_USER="${SUDO_USER:-}"
    if [ -z "$GREET_USER" ]; then
        echo "cannot tell which account to log in: run this with sudo, or write greeter.json" >&2
        echo "yourself from greeter.json.example." >&2
        exit 1
    fi
    SESSION_EXEC=""
    for d in /usr/share/wayland-sessions/hyprland.desktop /usr/share/wayland-sessions/*.desktop; do
        [ -f "$d" ] || continue
        SESSION_EXEC="$(sed -n 's/^Exec=//p' "$d" | head -1)"
        [ -n "$SESSION_EXEC" ] && break
    done
    [ -n "$SESSION_EXEC" ] || SESSION_EXEC=Hyprland
    # Exec is a command line; turn its words into a JSON array without pulling in a JSON tool.
    ARGV="$(printf '%s\n' "$SESSION_EXEC" | awk '{for(i=1;i<=NF;i++) printf "%s\"%s\"", (i>1?", ":""), $i}')"
    cat > "$SHELL_DIR/greeter/greeter.json" <<JSON
{
  "user": "$GREET_USER",
  "command": [$ARGV],
  "environment": ["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=Hyprland"]
}
JSON
    chmod 644 "$SHELL_DIR/greeter/greeter.json"
    echo "greeter.json: user=$GREET_USER session=$SESSION_EXEC"
    echo "              (edit $SHELL_DIR/greeter/greeter.json to change it, or keep one in the checkout)"
fi

if ! sudo -u greeter test -r "$WALLPAPERS"; then
    echo "note: the 'greeter' user cannot reach $WALLPAPERS, so the login screen will have no"
    echo "      video background. To grant just that path:"
    echo "  setfacl -R -m g:greeter:rX $WALLPAPERS"
    echo "  and traversal (x) on every directory above it, up to and including your home."
fi

install -Dm644 "$SRC/hyprland.conf" /etc/greetd/hyprland.conf
# The greeter runs as its own account, so it cannot expand the path itself — bake the real
# location of the installed copy into the config.
sed -i "s|@GREETER_ENTRY@|$SHELL_DIR/greeter.qml|" /etc/greetd/hyprland.conf
install -Dm755 "$SRC/session.sh"    /etc/greetd/session.sh

install -d -o greeter -g greeter -m 755 "$CACHE"

BACKUP="$CONF.bak-$(date +%Y%m%d-%H%M%S)"
cp -a "$CONF" "$BACKUP"

# Replace only the command line inside [default_session]; user/vt stay untouched.
sed -i 's|^command = .*|command = "/etc/greetd/session.sh"|' "$CONF"

echo "installed. greetd now starts: $(grep '^command = ' "$CONF")"
echo "shell copied to: $SHELL_DIR (re-run this script after editing the shell)"
echo "backup: $BACKUP"
echo
echo "test it without rebooting from a spare VT (Ctrl+Alt+F2, log in, then):"
echo "  sudo systemctl restart greetd    # kills the current graphical session!"
echo "rollback:"
echo "  sudo cp $BACKUP $CONF && sudo systemctl restart greetd"
