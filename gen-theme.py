#!/usr/bin/env python3
"""Transform `matugen image … --json hex` output into the shell's theme.json format.

Reads matugen JSON on stdin, writes theme.json (with `dark` and `light` blocks whose
keys match what shell.qml reads) on stdout.
"""
import json
import sys

# shell theme.json key  ->  matugen role name
#
# success / warning / info are deliberately absent. They used to be mapped to matugen's
# tertiary and secondary, but those are hue rotations of whatever dominates the wallpaper,
# so a "warning" taken from green wallpaper came out green. Config synthesises them from the
# primary instead, which at least guarantees a green, an amber and a blue.
MAP = {
    "primary": "primary",
    "onPrimary": "on_primary",
    "primaryText": "on_primary",   # legacy name, kept so an un-regenerated theme.json loads
    "primaryContainer": "primary_container",
    "secondary": "secondary",
    "surface": "surface",
    "surfaceText": "on_surface",
    "surfaceVariant": "surface_variant",
    "surfaceVariantText": "on_surface_variant",
    "surfaceTint": "surface_tint",
    "background": "background",
    "backgroundText": "on_background",
    "outline": "outline",
    "surfaceContainer": "surface_container",
    "surfaceContainerHigh": "surface_container_high",
    "surfaceContainerHighest": "surface_container_highest",
    "error": "error",
}


def block(colors, mode):
    out = {}
    for key, role in MAP.items():
        try:
            out[key] = colors[role][mode]["color"]
        except (KeyError, TypeError):
            pass
    return out


def main():
    data = json.load(sys.stdin)
    colors = data["colors"]
    theme = {
        "name": "matugen-dynamic",
        "dark": block(colors, "dark"),
        "light": block(colors, "light"),
    }
    json.dump(theme, sys.stdout, indent=2)


if __name__ == "__main__":
    main()
