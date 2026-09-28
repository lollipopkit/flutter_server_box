#!/usr/bin/env python3
"""Draft a ServerBox palette from a VS Code color theme.

    python3 port_vscode.py theme.json [--mode dark|light]

Reads the theme's `colors` (JSON with // and /* */ comments and trailing commas
allowed), maps them to ColorScheme roles as references/porting.md describes,
flattens translucent colors onto the background, fills a monotonic surface
ladder where the theme has fewer shades, and prints a `[colors.palette.<mode>]`
block followed by the contrast of every text pair. The block is a draft: read
it, fix what the contrast report flags, and preview it.
"""

from __future__ import annotations

import argparse
import colorsys
import json
import re
import sys
from pathlib import Path


def load_jsonc(text: str) -> dict:
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\":
                out.append(text[i + 1])
                i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
            out.append(c)
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        elif text.startswith("/*", i):
            i = text.index("*/", i) + 2
            continue
        else:
            out.append(c)
        i += 1
    cleaned = re.sub(r",(\s*[}\]])", r"\1", "".join(out))
    return json.loads(cleaned)


def parse(hex_: str | None) -> tuple[int, int, int, float] | None:
    if not hex_ or not isinstance(hex_, str) or not hex_.startswith("#"):
        return None
    h = hex_[1:]
    if len(h) in (3, 4):
        h = "".join(ch * 2 for ch in h)
    if len(h) == 6:
        h += "ff"
    if len(h) != 8:
        return None
    r, g, b, a = (int(h[i : i + 2], 16) for i in (0, 2, 4, 6))
    return r, g, b, a / 255


def flatten(c, bg):
    r, g, b, a = c
    br, bgc, bb, _ = bg
    return (round(a * r + (1 - a) * br), round(a * g + (1 - a) * bgc), round(a * b + (1 - a) * bb), 1.0)


def argb(c) -> int:
    r, g, b, _ = c
    return 0xFF000000 | (r << 16) | (g << 8) | b


def shift(c, amount: float):
    """Move lightness by `amount` (−1..1), keeping hue and saturation."""
    r, g, b, a = c
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    l = min(1.0, max(0.0, l + amount))
    r2, g2, b2 = colorsys.hls_to_rgb(h, l, s)
    return (round(r2 * 255), round(g2 * 255), round(b2 * 255), a)


def lightness(c) -> float:
    return colorsys.rgb_to_hls(c[0] / 255, c[1] / 255, c[2] / 255)[1]


def lum(c) -> float:
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4

    return 0.2126 * ch(c[0]) + 0.7152 * ch(c[1]) + 0.0722 * ch(c[2])


def contrast(a, b) -> float:
    x, y = sorted((lum(a), lum(b)), reverse=True)
    return (x + 0.05) / (y + 0.05)


def on_color(bg, preferred):
    """`preferred` if it reads on `bg`, else black or white, whichever reads."""
    if preferred and contrast(preferred, bg) >= 4.5:
        return preferred
    black, white = (0, 0, 0, 1.0), (255, 255, 255, 1.0)
    return black if contrast(black, bg) >= contrast(white, bg) else white


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("theme")
    ap.add_argument("--mode", choices=["dark", "light"])
    args = ap.parse_args()

    data = load_jsonc(Path(args.theme).read_text("utf-8"))
    colors = {k: parse(v) for k, v in (data.get("colors") or {}).items()}
    colors = {k: v for k, v in colors.items() if v}
    tokens = data.get("tokenColors") or []
    mode = args.mode or ("light" if data.get("type") == "light" else "dark")
    dark = mode == "dark"
    sign = 1 if dark else -1  # "raise" = lighter in dark mode, darker in light

    def pick(*keys, bg=None):
        for k in keys:
            if k in colors:
                c = colors[k]
                return flatten(c, bg) if bg and c[3] < 1 else c
        return None

    def token(*scopes):
        # An exact scope first: `keyword` rather than whichever
        # `keyword.operator.…` rule happens to come first.
        for exact in (True, False):
            for x in scopes:
                for t in tokens:
                    sc = t.get("scope")
                    sc = [s.strip() for s in sc.split(",")] if isinstance(sc, str) else (sc or [])
                    if any(s == x or (not exact and s.startswith(x + ".")) for s in sc):
                        c = parse((t.get("settings") or {}).get("foreground"))
                        if c:
                            return c
        return None

    def chroma(c) -> float:
        h, l, s_ = colorsys.rgb_to_hls(c[0] / 255, c[1] / 255, c[2] / 255)
        return s_ * min(l, 1 - l)

    def blend(c, amount):
        return flatten((c[0], c[1], c[2], amount), surface)

    surface = pick("editor.background") or ((30, 30, 30, 1.0) if dark else (255, 255, 255, 1.0))
    fg = pick("editor.foreground", "foreground", bg=surface) or on_color(surface, None)
    # The accent is the most colorful of the places a theme puts one; many
    # themes use a gray focusBorder or button, which is not what the theme
    # looks like.
    candidates = [
        pick(k, bg=surface)
        for k in ("focusBorder", "button.background", "textLink.foreground",
                  "activityBarBadge.background", "progressBar.background",
                  "tab.activeBorderTop", "statusBarItem.remoteBackground")
    ] + [token("entity.name.function", "support.function")]
    candidates = [c for c in candidates if c]
    accent = max(candidates, key=chroma) if candidates else None
    if accent is None or chroma(accent) < 0.08:
        accent = shift(surface, 0.4 * sign)
    secondary = token("keyword", "storage") or pick("badge.background", bg=surface) or accent
    tertiary = token("string") or token("constant.numeric") or secondary
    error = pick("errorForeground", "editorError.foreground", bg=surface) or ((0xF2, 0x4C, 0x4C, 1.0) if dark else (0xB3, 0x26, 0x1E, 1.0))
    muted = pick("descriptionForeground", bg=surface)
    if muted is None or abs(lightness(muted) - lightness(fg)) < 0.03:
        muted = token("comment") or shift(fg, -0.25 * sign)

    # The surface ladder: take the theme's shades where it has them, then force
    # the order the app relies on, stepping 2% lightness where it has none.
    lowest = pick("sideBar.background", "activityBar.background", bg=surface) or shift(surface, -0.03 * sign)
    if (lightness(lowest) - lightness(surface)) * sign > 0:
        lowest = shift(surface, -0.03 * sign)
    ladder = [surface]
    for keys in (("sideBar.background",), ("editorWidget.background", "editorGroupHeader.tabsBackground"), ("menu.background", "list.hoverBackground"), ("input.background", "dropdown.background")):
        c = pick(*keys, bg=surface)
        prev = ladder[-1]
        if c is None or (lightness(c) - lightness(prev)) * sign <= 0:
            c = shift(prev, 0.02 * sign)
        ladder.append(c)
    _, low, container, high, highest = ladder
    bright = shift(surface, 0.08 * sign)

    # Secondary text below 4.5:1 is common in upstream themes; move it until it
    # reads, keeping its hue.
    # Checked on the container too: tiles and cards put it there.
    for _ in range(40):
        if min(contrast(muted, surface), contrast(muted, container)) >= 4.5:
            break
        muted = shift(muted, 0.02 * sign)

    # Containers are the accent as a fill: a theme's selection colors are
    # usually gray, and a selected tile should read as the accent.
    sel = blend(accent, 0.22 if dark else 0.16)
    inactive = blend(accent, 0.14 if dark else 0.10)
    divider = pick("panel.border", "editorGroup.border", "sideBar.border", bg=surface) or shift(surface, 0.08 * sign)
    outline = pick("input.border", bg=surface) or shift(muted, -0.1 * sign)
    for _ in range(40):
        if contrast(outline, surface) >= 3:
            break
        outline = shift(outline, 0.02 * sign)

    roles = {
        "primary": accent,
        "onPrimary": on_color(accent, pick("button.foreground")),
        "primaryContainer": sel,
        "onPrimaryContainer": on_color(sel, pick("list.activeSelectionForeground") or fg),
        "secondary": secondary,
        "onSecondary": on_color(secondary, surface),
        "secondaryContainer": inactive,
        "onSecondaryContainer": on_color(inactive, fg),
        "tertiary": tertiary,
        "onTertiary": on_color(tertiary, surface),
        "surface": surface,
        "surfaceDim": surface if dark else shift(surface, -0.06),
        "surfaceBright": bright if dark else surface,
        "surfaceContainerLowest": lowest,
        "surfaceContainerLow": low,
        "surfaceContainer": container,
        "surfaceContainerHigh": high,
        "surfaceContainerHighest": highest,
        "onSurface": fg,
        "onSurfaceVariant": muted,
        "outline": outline,
        "outlineVariant": divider,
        "error": error,
        "onError": on_color(error, surface),
    }

    name = data.get("name") or Path(args.theme).stem
    print(f"# Drafted from {name} ({mode}) by port_vscode.py; review before use.")
    print(f"[colors.palette.{mode}]")
    for role, c in roles.items():
        print(f"{role} = 0x{argb(c):08X}")
    print("surfaceTint = 0x00000000")
    print(f"\n# seed = 0x{argb(accent):08X}")

    print("\n# contrast")
    for f, b, need in [
        ("onSurface", "surface", 4.5), ("onSurface", "surfaceContainerHighest", 4.5),
        ("onSurfaceVariant", "surface", 4.5), ("onPrimary", "primary", 4.5),
        ("onPrimaryContainer", "primaryContainer", 4.5),
        ("onSecondaryContainer", "secondaryContainer", 4.5),
        ("onError", "error", 4.5), ("outline", "surface", 3.0),
    ]:
        r = contrast(roles[f], roles[b])
        print(f"# {'ok ' if r >= need else 'LOW'} {f} on {b}: {r:.2f}:1")
    return 0


if __name__ == "__main__":
    sys.exit(main())
