#!/usr/bin/env python3
"""Draw the official themes' icon sets into store/themes/<id>/icons/.

    python3 scripts/theme-icons.py            # every theme below
    python3 scripts/theme-icons.py serverbox.one-dark-pro

One set of glyphs on a 24x24 grid, drawn per theme in that theme's hand:
stroke width, line caps and joins, and how round a corner is. Every key a
package may carry gets a file: `tab.<t>` as an outline, `tab.<t>.selected` in
duotone (the body filled at low opacity under the same outline), and the
`nav.*` symbols as outlines.

The app tints an icon one color (`BlendMode.srcIn`), which keeps each part's
opacity: that is what makes the duotone read. So every part is `currentColor`,
and differences are opacities, never hues. The files are committed; run this
again after changing a glyph or a theme's hand, then republish the themes.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "store" / "themes"


@dataclass(frozen=True)
class Hand:
    stroke: float  # stroke width
    cap: str  # round | square | butt
    join: str  # round | miter
    radius: float  # corner radius of boxes, 0-1 of the default
    fill: float  # duotone fill opacity of a selected tab


HANDS = {
    # Editor-like: medium strokes, modest radius.
    "serverbox.one-dark-pro": Hand(1.75, "round", "round", 1.0, 0.28),
}


def r(h: Hand, base: float) -> float:
    return round(base * h.radius, 2)


# Each glyph returns (outline, body): SVG elements, and the parts that are
# filled in a selected tab. Coordinates are on a 24x24 grid.
def server(h):
    a = f'<rect x="3.5" y="3.5" width="17" height="7" rx="{r(h, 2)}"/>'
    b = f'<rect x="3.5" y="13.5" width="17" height="7" rx="{r(h, 2)}"/>'
    dots = (
        '<circle cx="7.5" cy="7" r="1.1" fill="currentColor" stroke="none"/>'
        '<circle cx="7.5" cy="17" r="1.1" fill="currentColor" stroke="none"/>'
        '<path d="M11.5 7h5M11.5 17h5"/>'
    )
    return a + b + dots, a + b


def terminal(h):
    box = f'<rect x="3" y="4.5" width="18" height="15" rx="{r(h, 2.5)}"/>'
    prompt = '<path d="M7 10l3 2.5-3 2.5M12.5 15.5h4.5"/>'
    return box + prompt, box


def folder(h):
    body = (
        f'<path d="M3.5 7.5a{r(h, 2)} {r(h, 2)} 0 0 1 {r(h, 2)}-{r(h, 2)}h3.6l2 2.2h7.4'
        f'a{r(h, 2)} {r(h, 2)} 0 0 1 {r(h, 2)} {r(h, 2)}v7.8a{r(h, 2)} {r(h, 2)} 0 0 1-{r(h, 2)} {r(h, 2)}'
        f'h-13a{r(h, 2)} {r(h, 2)} 0 0 1-{r(h, 2)}-{r(h, 2)}z"/>'
    )
    return body + '<path d="M3.5 10h17"/>', body


def snippet(h):
    page = f'<rect x="4.5" y="3" width="15" height="18" rx="{r(h, 2.5)}"/>'
    code = '<path d="M10 9.5l-2.5 2.5 2.5 2.5M14 9.5l2.5 2.5-2.5 2.5"/>'
    return page + code, page


def sparkle(h):
    big = '<path d="M11 3.5l1.7 4.8 4.8 1.7-4.8 1.7L11 16.5l-1.7-4.8L4.5 10l4.8-1.7z"/>'
    small = '<path d="M18 14.5l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8z"/>'
    return big + small, big + small


def ai(h):
    """The AI settings entry: a chat bubble with a spark, not the Agent tab's
    sparkles, since the two are different places."""
    bubble = (
        f'<path d="M4 6.5a{r(h, 2.5)} {r(h, 2.5)} 0 0 1 {r(h, 2.5)}-{r(h, 2.5)}h11'
        f'a{r(h, 2.5)} {r(h, 2.5)} 0 0 1 {r(h, 2.5)} {r(h, 2.5)}v7a{r(h, 2.5)} {r(h, 2.5)} 0 0 1-{r(h, 2.5)} {r(h, 2.5)}'
        f'H10l-4 3.5V16a{r(h, 2.5)} {r(h, 2.5)} 0 0 1-2-{r(h, 2.5)}z"/>'
    )
    spark = '<path d="M12 7l1 2.5 2.5 1-2.5 1-1 2.5-1-2.5-2.5-1 2.5-1z" fill="currentColor"/>'
    return bubble + spark, bubble


def gauge(h):
    arc = '<path d="M4 16.5a8 8 0 1 1 16 0"/>'
    body = '<path d="M4 16.5a8 8 0 1 1 16 0z"/>'
    needle = '<path d="M12 16.5l3.5-5"/><circle cx="12" cy="16.5" r="1.4" fill="currentColor" stroke="none"/>'
    ticks = '<path d="M6.6 11.1l1 .8M12 6.5v1.2M17.4 11.1l-1 .8"/>'
    return arc + ticks + needle + '<path d="M3.5 19.5h17"/>', body


def monitor(h):
    screen = f'<rect x="3" y="4" width="18" height="12.5" rx="{r(h, 2)}"/>'
    stand = '<path d="M9 20.5h6M12 16.5v4"/>'
    return screen + stand, screen


def remote(h):
    screen = f'<rect x="3" y="4" width="18" height="12.5" rx="{r(h, 2)}"/>'
    stand = '<path d="M9 20.5h6M12 16.5v4"/>'
    cursor = '<path d="M10 7.5l5.5 3-2.4.7-.9 2.3z" fill="currentColor"/>'
    return screen + stand + cursor, screen


def cube(h):
    outline = '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9z"/><path d="M4 7.5l8 4.5 8-4.5M12 12v9"/>'
    body = '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9z"/>'
    return outline, body


def dots(h):
    s = "".join(
        f'<circle cx="{x}" cy="12" r="1.5" fill="currentColor" stroke="none"/>'
        for x in (6, 12, 18)
    )
    return s, ""


def gear(h):
    import math

    teeth, outer, inner = 8, 9.2, 7.2
    pts = []
    for i in range(teeth * 2):
        rad = outer if i % 2 == 0 else inner
        for off in (-0.18, 0.18):
            a = math.pi * 2 * (i + 0.5 + off) / (teeth * 2)
            pts.append((12 + rad * math.cos(a), 12 + rad * math.sin(a)))
    d = "M" + "L".join(f"{x:.2f} {y:.2f}" for x, y in pts) + "z"
    body = f'<path d="{d}"/>'
    return body + '<circle cx="12" cy="12" r="3"/>', body


def sliders(h):
    lines = '<path d="M4 7h9M17 7h3M4 12h3M11 12h9M4 17h11M19 17h1"/>'
    knobs = '<circle cx="15" cy="7" r="2"/><circle cx="9" cy="12" r="2"/><circle cx="17" cy="17" r="2"/>'
    return lines + knobs, ""


def shield(h):
    body = '<path d="M12 3l7.5 3v5.5c0 4.6-3.2 8.2-7.5 9.5-4.3-1.3-7.5-4.9-7.5-9.5V6z"/>'
    return body + '<path d="M9 12l2 2 4-4"/>', body


def tabs(h):
    back = f'<rect x="7.5" y="3.5" width="13" height="13" rx="{r(h, 2)}"/>'
    front = f'<rect x="3.5" y="7.5" width="13" height="13" rx="{r(h, 2)}"/>'
    return back + front, front


def sort(h):
    return '<path d="M8 4v16M4.5 7.5L8 4l3.5 3.5M16 20V4M12.5 16.5L16 20l3.5-3.5"/>', ""


def cloud(h):
    body = '<path d="M7 18.5a4.5 4.5 0 0 1-.6-8.96A6 6 0 0 1 17.9 9 4.75 4.75 0 0 1 17.5 18.5z"/>'
    return body, body


def inbox(h):
    body = f'<path d="M3.5 13.5l2.6-7.2A{r(h, 2)} {r(h, 2)} 0 0 1 8 5h8a{r(h, 2)} {r(h, 2)} 0 0 1 1.9 1.3l2.6 7.2v4.5a{r(h, 2)} {r(h, 2)} 0 0 1-{r(h, 2)} {r(h, 2)}h-13a{r(h, 2)} {r(h, 2)} 0 0 1-{r(h, 2)}-{r(h, 2)}z"/>'
    tray = '<path d="M3.5 13.5h4.5l1.5 2.5h5l1.5-2.5h4.5"/>'
    return body + tray, body


def key(h):
    ring = '<circle cx="8" cy="15" r="4.5"/>'
    shaft = '<path d="M11.2 11.8L20 3M16.5 6.5l2.5 2.5M14 9l2 2"/>'
    return ring + shaft, ring


def info(h):
    c = '<circle cx="12" cy="12" r="8.5"/>'
    return c + '<path d="M12 11v5.5"/><circle cx="12" cy="7.8" r="1.1" fill="currentColor" stroke="none"/>', c


def download(h):
    arrow = '<path d="M12 4v11M7.5 10.5L12 15l4.5-4.5"/>'
    tray = '<path d="M4 15.5v2a3 3 0 0 0 3 3h10a3 3 0 0 0 3-3v-2"/>'
    return arrow + tray, ""


GLYPHS = {
    "tab.server": server,
    "tab.ssh": terminal,
    "tab.file": folder,
    "tab.snippet": snippet,
    "tab.agent": sparkle,
    "tab.benchmark": gauge,
    "tab.remoteDesktop": remote,
    "tab.virt": cube,
    "nav.more": dots,
    "nav.settings": gear,
    "nav.tune": sliders,
    "nav.privacy": shield,
    "nav.agent": ai,
    "nav.tabs": tabs,
    "nav.server": server,
    "nav.sort": sort,
    "nav.terminal": terminal,
    "nav.folder": folder,
    "nav.cloud": cloud,
    "nav.snippet": snippet,
    "nav.inbox": inbox,
    "nav.key": key,
    "nav.info": info,
    "nav.download": download,
    "nav.desktop": monitor,
}


def svg(h: Hand, inner: str) -> str:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
        f'stroke="currentColor" stroke-width="{h.stroke}" stroke-linecap="{h.cap}" '
        f'stroke-linejoin="{h.join}">{inner}</svg>\n'
    )


def draw(theme: str) -> None:
    h = HANDS[theme]
    out = ROOT / theme / "icons"
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.svg"):
        old.unlink()
    for key_, glyph in GLYPHS.items():
        outline, body = glyph(h)
        (out / f"{key_.replace('.', '_')}.svg").write_text(svg(h, outline))
        if key_.startswith("tab."):
            duo = (
                f'<g fill="currentColor" fill-opacity="{h.fill}" stroke="none">{body}</g>'
                if body
                else ""
            )
            (out / f"{key_.replace('.', '_')}_selected.svg").write_text(svg(h, duo + outline))


def main() -> int:
    themes = sys.argv[1:] or list(HANDS)
    for t in themes:
        draw(t)
        print(f"drew {t}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
