#!/bin/sh
# greetd's session command (installed to /etc/greetd/session.sh).
# The `greeter` account's home is /, which is read-only for it, so point every XDG
# state dir at a writable cache before starting the compositor + greeter shell.
set -eu

export XDG_CACHE_HOME=/var/cache/qs-greeter/cache
export XDG_STATE_HOME=/var/cache/qs-greeter/state
export XDG_DATA_HOME=/var/cache/qs-greeter/data
export XDG_CONFIG_HOME=/var/cache/qs-greeter/config
mkdir -p "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"

# Through the watchdog wrapper, same as a normal session — starting Hyprland directly
# makes it draw a "started without start-hyprland" warning overlay on top of the greeter.
exec start-hyprland -- -c /etc/greetd/hyprland.conf
