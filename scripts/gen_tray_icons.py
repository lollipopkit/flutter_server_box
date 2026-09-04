#!/usr/bin/env python3
"""Draws the macOS menu-bar icon in `assets/tray/mac.pdf`.

Checked in rather than run at build time, because the assets are what ships and
a build should not need a drawing tool. Re-run it after changing anything here:

    python3 scripts/gen_tray_icons.py

Windows and Linux use their existing application icons directly. macOS keeps a
separate black-and-alpha vector because the system treats menu-bar artwork as a
template and rasterises it at the size of the current display.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "tray"

def pdf(size: int) -> bytes:
    """The same glyph as a one-page vector, for the menu bar.

    Written by hand for the reason the PNG encoder is: this repo's machines have
    no drawing tool, and a vector of two rounded bars is a dozen curves.

    Even-odd filling is what knocks the indicator out of each bar — one path
    holding both shapes, so the hole is a hole rather than a second colour.
    """
    # Proportions of `draw`, in a unit square, so the two shapes agree.
    margin = size * 0.09
    bar_h = size * 0.28
    gap = size * 0.12
    radius = bar_h * 0.35
    led = size * 0.09
    top = (size - (bar_h * 2 + gap)) / 2
    left, right = margin, size - margin

    def rounded(x0: float, y0: float, x1: float, y1: float, r: float) -> str:
        k = r * 0.5523  # circle-to-bezier, the usual constant
        return (
            f"{x0 + r:.3f} {y0:.3f} m "
            f"{x1 - r:.3f} {y0:.3f} l "
            f"{x1 - r + k:.3f} {y0:.3f} {x1:.3f} {y0 + r - k:.3f} {x1:.3f} {y0 + r:.3f} c "
            f"{x1:.3f} {y1 - r:.3f} l "
            f"{x1:.3f} {y1 - r + k:.3f} {x1 - r + k:.3f} {y1:.3f} {x1 - r:.3f} {y1:.3f} c "
            f"{x0 + r:.3f} {y1:.3f} l "
            f"{x0 + r - k:.3f} {y1:.3f} {x0:.3f} {y1 - r + k:.3f} {x0:.3f} {y1 - r:.3f} c "
            f"{x0:.3f} {y0 + r:.3f} l "
            f"{x0:.3f} {y0 + r - k:.3f} {x0 + r - k:.3f} {y0:.3f} {x0 + r:.3f} {y0:.3f} c h "
        )

    def circle(cx: float, cy: float, r: float) -> str:
        k = r * 0.5523
        return (
            f"{cx - r:.3f} {cy:.3f} m "
            f"{cx - r:.3f} {cy + k:.3f} {cx - k:.3f} {cy + r:.3f} {cx:.3f} {cy + r:.3f} c "
            f"{cx + k:.3f} {cy + r:.3f} {cx + r:.3f} {cy + k:.3f} {cx + r:.3f} {cy:.3f} c "
            f"{cx + r:.3f} {cy - k:.3f} {cx + k:.3f} {cy - r:.3f} {cx:.3f} {cy - r:.3f} c "
            f"{cx - k:.3f} {cy - r:.3f} {cx - r:.3f} {cy - k:.3f} {cx - r:.3f} {cy:.3f} c h "
        )

    body = "0 g "
    for bar in range(2):
        # PDF's origin is bottom-left, so the first bar is the upper one.
        y1 = size - top - bar * (bar_h + gap)
        y0 = y1 - bar_h
        body += rounded(left, y0, right, y1, radius)
        body += circle(left + led * 1.6, (y0 + y1) / 2, led / 2)
        body += "f* "

    stream = body.encode("ascii")
    objects = [
        b"<</Type/Catalog/Pages 2 0 R>>",
        b"<</Type/Pages/Kids[3 0 R]/Count 1>>",
        f"<</Type/Page/Parent 2 0 R/MediaBox[0 0 {size} {size}]/Contents 4 0 R/Resources<<>>>>".encode(),
        b"<</Length " + str(len(stream)).encode() + b">>stream\n" + stream + b"\nendstream",
    ]

    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for i, obj in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{i} 0 obj\n".encode() + obj + b"\nendobj\n"
    xref = len(out)
    out += f"xref\n0 {len(objects) + 1}\n".encode()
    out += b"0000000000 65535 f \n"
    for offset in offsets:
        out += f"{offset:010d} 00000 n \n".encode()
    out += f"trailer\n<</Size {len(objects) + 1}/Root 1 0 R>>\nstartxref\n{xref}\n%%EOF\n".encode()
    return bytes(out)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    output = OUT / "mac.pdf"
    output.write_bytes(pdf(18))
    print(f"{output.relative_to(ROOT)}  {output.stat().st_size} bytes")


if __name__ == "__main__":
    main()
