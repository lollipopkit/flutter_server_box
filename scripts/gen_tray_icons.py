#!/usr/bin/env python3
"""Draws the tray icons in `assets/tray/`.

Checked in rather than run at build time, because the assets are what ships and
a build should not need a drawing tool. Re-run it after changing anything here:

    python3 scripts/gen_tray_icons.py

Written against the standard library alone. The machines that build this repo
have neither Pillow nor ImageMagick, and adding either to CI to draw three
small files would cost more than the encoder below.

Three formats, because the three platforms want different things:

- macOS takes `mac.pdf`, a vector, through the asset catalogue with
  `preserves-vector-representation`. A menu bar is drawn at whatever height the
  system is set to and on whichever display the pointer is on, so a bitmap
  there is scaled by a factor nobody chose and goes soft. A vector is
  rasterised at the size it is asked for. Black-and-alpha, because it is used
  as a template image and the system inverts it with the bar.
- Windows loads the file with `LoadImage(..., IMAGE_ICON, LR_LOADFROMFILE)`,
  which wants a real `.ico`. The entries here are the classic DIB kind rather
  than PNG-compressed ones — `LoadImage` is documented for the former and
  inconsistent about the latter. Seven sizes, because `LoadImage` picks the
  nearest one and Windows asks for a different pixel size at every display
  scale: at 150% it wants 24, at 200% it wants 32, and upscaling 16 to either
  is what a blurry tray icon is.
- Linux hands the path to libayatana-appindicator, which reads a PNG. Drawn at
  64 so a panel at any height is scaling down rather than up.

Windows and Linux draw the icon as given, on a taskbar that may be light or
dark, so those two are a mid-tone blue rather than the black macOS wants: black
on the Windows 11 default taskbar is invisible.

One icon per platform and no second state. A menu bar is already a row of
things competing for attention, and what failed is said by the row that failed,
where there is something to be done about it.
"""

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "tray"

# Visible against both a light and a dark taskbar, which rules out the app's
# own seed colour: it is nearly black.
BLUE = (0x3B, 0x82, 0xF6)
BLACK = (0x00, 0x00, 0x00)


def draw(size: int, rgb: tuple[int, int, int]) -> bytearray:
    """A server rack: two bars, each with an indicator knocked out of it.

    Parametric rather than a pixel table so that every size is drawn at its own
    resolution. Scaling one bitmap to the others turns 1px details to mush at
    16px, which is the size that matters most.
    """
    px = bytearray(size * size * 4)

    def fill(x0: int, y0: int, x1: int, y1: int, colour: tuple[int, int, int, int]) -> None:
        for y in range(max(0, y0), min(size, y1 + 1)):
            for x in range(max(0, x0), min(size, x1 + 1)):
                i = (y * size + x) * 4
                px[i : i + 4] = bytes(colour)

    margin = max(1, round(size * 0.09))
    bar_h = max(3, round(size * 0.28))
    gap = max(1, round(size * 0.12))
    total = bar_h * 2 + gap
    top = (size - total) // 2
    left, right = margin, size - margin - 1

    opaque = (*rgb, 0xFF)
    clear = (0, 0, 0, 0)
    corner = 1 if size < 32 else 2
    led = max(1, round(size * 0.09))

    for bar in range(2):
        y0 = top + bar * (bar_h + gap)
        y1 = y0 + bar_h - 1
        fill(left, y0, right, y1, opaque)
        # Corners off, so the bars read as rounded at a glance.
        for dx in range(corner):
            for dy in range(corner):
                if dx + dy >= corner:
                    continue
                fill(left + dx, y0 + dy, left + dx, y0 + dy, clear)
                fill(right - dx, y0 + dy, right - dx, y0 + dy, clear)
                fill(left + dx, y1 - dy, left + dx, y1 - dy, clear)
                fill(right - dx, y1 - dy, right - dx, y1 - dy, clear)
        # The indicator, knocked out rather than drawn: one colour keeps the
        # macOS template valid, where anything but black-and-alpha is ignored.
        lx = left + max(1, round(size * 0.09))
        ly = y0 + (bar_h - led) // 2
        fill(lx, ly, lx + led - 1, ly + led - 1, clear)

    return px


def png(size: int, px: bytearray) -> bytes:
    raw = bytearray()
    for y in range(size):
        raw.append(0)  # filter: none
        raw += px[y * size * 4 : (y + 1) * size * 4]

    def chunk(kind: bytes, body: bytes) -> bytes:
        return (
            struct.pack(">I", len(body))
            + kind
            + body
            + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
        )

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def ico(images: list[tuple[int, bytearray]]) -> bytes:
    """A classic DIB icon. See the note at the top about PNG-compressed ones."""
    entries, bodies, offset = [], [], 6 + 16 * len(images)
    for size, px in images:
        # BGRA, bottom-up, which is what a DIB is.
        xor = bytearray()
        for y in range(size - 1, -1, -1):
            for x in range(size):
                i = (y * size + x) * 4
                r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
                xor += bytes((b, g, r, a))
        # The AND mask is unused at 32bpp but the format still requires it,
        # padded to a 4-byte row.
        stride = ((size + 31) // 32) * 4
        and_mask = bytes(stride * size)
        header = struct.pack(
            "<IiiHHIIiiII", 40, size, size * 2, 1, 32, 0, len(xor) + len(and_mask), 0, 0, 0, 0
        )
        body = header + bytes(xor) + and_mask
        entries.append(
            struct.pack(
                "<BBBBHHII",
                size if size < 256 else 0,
                size if size < 256 else 0,
                0,
                0,
                1,
                32,
                len(body),
                offset,
            )
        )
        bodies.append(body)
        offset += len(body)

    return struct.pack("<HHH", 0, 1, len(images)) + b"".join(entries) + b"".join(bodies)


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

    # 18pt, which is what a menu bar item is. A vector, so that is a size
    # rather than a resolution.
    (OUT / "mac.pdf").write_bytes(pdf(18))

    (OUT / "tray.png").write_bytes(png(64, draw(64, BLUE)))
    (OUT / "tray.ico").write_bytes(
        ico([(size, draw(size, BLUE)) for size in (16, 20, 24, 32, 40, 48, 64)])
    )

    for f in sorted(OUT.iterdir()):
        print(f"{f.relative_to(ROOT)}  {f.stat().st_size} bytes")


if __name__ == "__main__":
    main()
