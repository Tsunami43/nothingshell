#!/usr/bin/env bash
# Focus the Hyprland window that owns the process tree containing $1 (a notification's sender-pid).
# Walks up the parent-pid chain until a pid matches a Hyprland window's pid, then focuses it — this
# switches to the window's workspace too. Works for terminal apps (e.g. a CLI inside ghostty) whose
# notification is sent by the child process, not the window.
p="${1:-0}"
[ "$p" -gt 1 ] 2>/dev/null || exit 0

mapfile -t wins < <(hyprctl clients -j 2>/dev/null | grep -oE '"pid": *[0-9]+' | grep -oE '[0-9]+')

for _ in $(seq 40); do
    [ "$p" -le 1 ] && break
    for w in "${wins[@]}"; do
        if [ "$w" = "$p" ]; then
            hyprctl dispatch focuswindow "pid:$p" >/dev/null 2>&1
            exit 0
        fi
    done
    # parent pid = 2nd field after the (possibly paren/space-laden) comm in /proc/<p>/stat
    p=$(sed 's/.*) //' "/proc/$p/stat" 2>/dev/null | awk '{print $2}')
    [ -z "$p" ] && break
done
exit 0
