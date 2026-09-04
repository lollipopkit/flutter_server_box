#!/usr/bin/env python3
"""Builds `assets/geo/land_110m.bin` from Natural Earth 110m land.

The asset is a few tens of kilobytes of binary with no header anyone could
read by eye, so without this script it is a blob nobody can regenerate or
check. Run it whenever the upstream data moves; the output is deterministic,
so a run that changes nothing produces a byte-identical file and no diff.

    python3 scripts/build_land_asset.py

Source: https://github.com/nvkelso/natural-earth-vector, `ne_110m_land`.
Natural Earth is public domain — no attribution is required, and the project
asks that none be implied. See https://www.naturalearthdata.com/about/terms-of-use/

Why 110m and not 50m: this is drawn as an outline on a disc a few hundred
pixels across, where 110m already puts several vertices in a pixel. 50m is
about six times the data for detail nothing can show.

Format, big-endian throughout, matching `GlobeLand` in
`lib/view/widget/globe/land.dart`:

    magic "SBGL"     4 B
    format           1 B   == 1
    ringCount        2 B   u16
    per ring:
      pointCount     2 B   u16
      points         pointCount x 4 B: lat i16 + lon i16

Coordinates are quantised the same way the geo database quantises a country's
capital: a signed 16-bit fraction of the axis, so latitude resolves to about
300 m. That is finer than the source data, which is drawn at 1:110,000,000.
"""

from __future__ import annotations

import json
import struct
import sys
import urllib.request
from pathlib import Path

SOURCE = (
    "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/"
    "master/geojson/ne_110m_land.geojson"
)
OUT = Path(__file__).resolve().parent.parent / "assets" / "geo" / "land_110m.bin"

MAGIC = b"SBGL"
FORMAT = 1
QUANTUM = 32767

# A ring with fewer points than this is a rock. At the scale this is drawn it
# is at most one pixel, and it costs the same per-ring overhead as a continent.
MIN_POINTS = 4


def quantise(lon: float, lat: float) -> tuple[int, int]:
    return (
        max(-QUANTUM, min(QUANTUM, round(lat / 90 * QUANTUM))),
        max(-QUANTUM, min(QUANTUM, round(lon / 180 * QUANTUM))),
    )


def rings_of(geometry: dict) -> list[list[list[float]]]:
    kind = geometry["type"]
    if kind == "Polygon":
        polygons = [geometry["coordinates"]]
    elif kind == "MultiPolygon":
        polygons = geometry["coordinates"]
    else:
        raise SystemExit(f"unexpected geometry {kind}")
    # Only the outer ring of each polygon. The inner ones are lakes, and this
    # is drawn as a coastline rather than filled, so a lake outline would read
    # as another island.
    return [polygon[0] for polygon in polygons]


def main() -> None:
    print(f"fetching {SOURCE}")
    with urllib.request.urlopen(SOURCE) as response:
        data = json.load(response)

    rings: list[list[tuple[int, int]]] = []
    dropped = 0
    for feature in data["features"]:
        for ring in rings_of(feature["geometry"]):
            # GeoJSON closes a ring by repeating the first point. The reader
            # closes it itself, so the repeat is a wasted vertex per ring.
            points = ring[:-1] if len(ring) > 1 and ring[0] == ring[-1] else ring
            if len(points) < MIN_POINTS:
                dropped += 1
                continue
            quantised = [quantise(lon, lat) for lon, lat, *_ in points]
            # Consecutive points that quantise to the same value draw nothing.
            deduped = [quantised[0]]
            for point in quantised[1:]:
                if point != deduped[-1]:
                    deduped.append(point)
            if len(deduped) < MIN_POINTS:
                dropped += 1
                continue
            rings.append(deduped)

    if len(rings) > 0xFFFF:
        raise SystemExit(f"{len(rings)} rings does not fit in a u16")

    out = bytearray()
    out += MAGIC
    out += struct.pack(">B", FORMAT)
    out += struct.pack(">H", len(rings))
    for ring in rings:
        if len(ring) > 0xFFFF:
            raise SystemExit(f"a ring of {len(ring)} points does not fit in a u16")
        out += struct.pack(">H", len(ring))
        for lat, lon in ring:
            out += struct.pack(">hh", lat, lon)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(bytes(out))
    points = sum(len(ring) for ring in rings)
    print(
        f"wrote {OUT.relative_to(Path.cwd()) if OUT.is_relative_to(Path.cwd()) else OUT}"
        f": {len(rings)} rings, {points} points, {len(out)} bytes"
        f" ({dropped} rings dropped as too small)"
    )


if __name__ == "__main__":
    sys.exit(main())
