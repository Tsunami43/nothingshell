#!/bin/sh
# Compile every *.frag next to this script into the *.qsb that ShaderEffect loads
# (Qt Quick only accepts the baked container, never GLSL source). Recompiles just the
# stale ones, so it is cheap to run on every login — see hypr/hyprland.conf.
#
# The .qsb files are build output and are not tracked in git, so this has to run before
# the shell does. qsb ships in qt6-shadertools and is not on PATH; without it the shader
# surfaces (the frame) cannot be drawn at all, hence the loud message.
#
# Editing a .frag needs this script AND a full restart of the shell. A QML hot-reload
# rebuilds the ShaderEffect, but the process keeps the shader it already compiled, so the
# new uniforms silently read as zero — which looks like the QML being wrong rather than
# the shader being stale.
set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
qsb=/usr/lib/qt6/bin/qsb

[ -x "$qsb" ] || { echo "build-shaders: $qsb not found (install qt6-shadertools)" >&2; exit 0; }

for frag in "$dir"/*.frag; do
    [ -e "$frag" ] || continue
    out="$frag.qsb"
    [ -e "$out" ] && [ "$out" -nt "$frag" ] && continue
    # Same six targets the checked-in files were built with: SPIR-V, GLSL 100es/120/150,
    # HLSL 50, MSL 12.
    "$qsb" --glsl "100es,120,150" --hlsl 50 --msl 12 -o "$out" "$frag"
    echo "build-shaders: rebuilt $(basename "$out")"
done
