#!/usr/bin/env python3
"""Check a ServerBox theme folder the way the app's installer will.

    python3 validate.py <theme-folder> [--schema <fsbt-manifest.schema.json>]

Two layers:

1. The manifest against the JSON Schema the app publishes
   (docs/schemas/fsbt-manifest.schema.json), through `check-jsonschema` run by
   `uvx` or `pipx`. The schema is as strict as the installer on everything a
   single table can say: unknown fields, ranges, enums, icon paths.
2. What the schema cannot say, checked here: an `icons.colors` key without an
   image, schema 2 features under `min = 1`, the files themselves (names, sizes,
   PNG/JPEG dimensions, SVG content), stray files the installer refuses, and
   the contrast of the text pairs a palette sets.

Exit status 0 means no errors; warnings do not fail. Standard library only
(Python 3.11+ for tomllib).
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    sys.exit("Python 3.11 or newer is needed (tomllib)")

SCHEMA_URL = (
    "https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/"
    "docs/schemas/fsbt-manifest.schema.json"
)
# The app's supported theme schema range. Raise with the app.
APP_SCHEMA = (1, 2)
FEATURE_SCHEMA = 2

KIB = 1024
MIB = 1024 * KIB
LIMITS = {
    "package": 16 * MIB,
    "manifest": 64 * KIB,
    "icon": 256 * KIB,
    "splash": 512 * KIB,
    "background": 8 * MIB,
}
ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")
BACKGROUNDS = {"background.png", "background.jpg", "background.jpeg"}
SPLASH_LOGOS = {
    "splash_logo.png",
    "splash_logo.jpg",
    "splash_logo.jpeg",
    "splash_logo.svg",
}

# Foreground/background pairs a palette is read in. Text pairs need 4.5:1
# (WCAG AA, normal text); outline against its surface needs 3:1 (non-text).
TEXT_PAIRS = [
    ("onSurface", "surface"),
    ("onSurface", "surfaceContainer"),
    ("onSurface", "surfaceContainerHigh"),
    ("onSurface", "surfaceContainerHighest"),
    ("onSurfaceVariant", "surface"),
    ("onSurfaceVariant", "surfaceContainer"),
    ("onPrimary", "primary"),
    ("onPrimaryContainer", "primaryContainer"),
    ("onSecondary", "secondary"),
    ("onSecondaryContainer", "secondaryContainer"),
    ("onTertiary", "tertiary"),
    ("onTertiaryContainer", "tertiaryContainer"),
    ("onError", "error"),
    ("onErrorContainer", "errorContainer"),
    ("onInverseSurface", "inverseSurface"),
]
NON_TEXT_PAIRS = [("outline", "surface"), ("primary", "surface")]


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)


def find_schema(explicit: str | None) -> Path | None:
    if explicit:
        return Path(explicit)
    # Inside a checkout of flutter_server_box, the schema is beside the docs.
    for parent in [Path.cwd(), *Path.cwd().parents, *Path(__file__).resolve().parents]:
        candidate = parent / "docs/schemas/fsbt-manifest.schema.json"
        if candidate.is_file():
            return candidate
    return None


def load_schema(path: Path | None) -> tuple[dict, str]:
    if path is not None:
        return json.loads(path.read_text()), str(path)
    # check-jsonschema fetches the URL itself, and says so when it cannot.
    return {}, SCHEMA_URL


def run_check_jsonschema(manifest: Path, schema_ref: str, rep: Report) -> None:
    runner = None
    if shutil.which("check-jsonschema"):
        runner = ["check-jsonschema"]
    elif shutil.which("uvx"):
        runner = ["uvx", "--from", "check-jsonschema==0.38.2", "check-jsonschema"]
    elif shutil.which("pipx"):
        runner = ["pipx", "run", "--spec", "check-jsonschema==0.38.2", "check-jsonschema"]
    if runner is None:
        rep.warn(
            "schema not checked: install uv (https://docs.astral.sh/uv/) or pipx "
            "so check-jsonschema can run"
        )
        return
    proc = subprocess.run(
        [*runner, "--schemafile", schema_ref, str(manifest)],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        out = (proc.stdout + proc.stderr).strip()
        rep.error("manifest does not match the schema:\n" + out)


def png_size(data: bytes) -> tuple[int, int] | None:
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", data[16:24])


def jpeg_size(data: bytes) -> tuple[int, int] | None:
    if data[:2] != b"\xff\xd8":
        return None
    i = 2
    while i + 9 < len(data):
        if data[i] != 0xFF:
            i += 1
            continue
        marker = data[i + 1]
        if marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
            i += 2
            continue
        length = struct.unpack(">H", data[i + 2 : i + 4])[0]
        if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
            h, w = struct.unpack(">HH", data[i + 5 : i + 9])
            return w, h
        i += 2 + length
    return None


FOREIGN_URL = re.compile(r"url\(\s*['\"]?\s*(?!#)", re.IGNORECASE)


def check_svg(path: Path, data: bytes, rep: Report, *, tinted: bool = True) -> None:
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        rep.error(f"{path.name}: an SVG must be UTF-8")
        return
    if "<!DOCTYPE" in text or "<!ENTITY" in text:
        rep.error(f"{path.name}: a DTD or entity declaration is refused")
    if re.search(r"<\?(?!xml\s)", text):
        rep.error(f"{path.name}: processing instructions (e.g. xml-stylesheet) are refused")
    try:
        root = ET.fromstring(data)
    except ET.ParseError as e:
        rep.error(f"{path.name}: not a readable SVG document ({e})")
        return
    if root.tag.split("}")[-1] != "svg":
        rep.error(f"{path.name}: the root element must be svg")
    for el in root.iter():
        local = el.tag.split("}")[-1].lower()
        if local in ("script", "style", "foreignobject"):
            rep.error(f"{path.name}: <{local}> is refused")
        for name, value in el.attrib.items():
            if name.split("}")[-1] == "href" and not value.startswith("#"):
                rep.error(f"{path.name}: href to '{value}' reaches outside the file")
            if FOREIGN_URL.search(value):
                rep.error(f"{path.name}: url(...) in {name} reaches outside the file")
    if tinted and "currentColor" not in text:
        rep.warn(
            f"{path.name}: no currentColor; the app tints the whole icon one "
            "color, so parts meant to follow the theme should use currentColor"
        )


def check_raster(path: Path, data: bytes, max_side: int, max_pixels: int, rep: Report) -> None:
    size = png_size(data) or jpeg_size(data)
    if size is None:
        rep.error(f"{path.name}: not a PNG or JPEG the installer can decode")
        return
    w, h = size
    if w > max_side or h > max_side or w * h > max_pixels:
        rep.error(f"{path.name}: {w}x{h} exceeds {max_side}px per side / {max_pixels} pixels")


def luminance(argb: int) -> float:
    def ch(c: int) -> float:
        c = c / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = (argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def contrast(a: int, b: int) -> float:
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def check_contrast(manifest: dict, rep: Report) -> list[str]:
    lines = []
    palettes = manifest.get("colors", {}).get("palette", {})
    for brightness in ("light", "dark"):
        pal = palettes.get(brightness) or {}
        if not isinstance(pal, dict):
            continue
        for pairs, need in ((TEXT_PAIRS, 4.5), (NON_TEXT_PAIRS, 3.0)):
            for fg, bg in pairs:
                if not (isinstance(pal.get(fg), int) and isinstance(pal.get(bg), int)):
                    continue
                if (pal[fg] >> 24) != 0xFF or (pal[bg] >> 24) != 0xFF:
                    continue  # translucent: depends on what is under it
                ratio = contrast(pal[fg], pal[bg])
                mark = "ok " if ratio >= need else "LOW"
                lines.append(f"  {mark} {brightness:5} {fg} on {bg}: {ratio:.2f}:1 (needs {need})")
                if ratio < need:
                    rep.warn(f"{brightness} {fg} on {bg} is {ratio:.2f}:1, below {need}:1")
    return lines


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder")
    ap.add_argument("--schema", help="path to fsbt-manifest.schema.json")
    args = ap.parse_args()

    folder = Path(args.folder)
    manifest_path = folder / "manifest.toml"
    rep = Report()
    if not manifest_path.is_file():
        print(f"error: {manifest_path} does not exist")
        return 1

    raw = manifest_path.read_bytes()
    if len(raw) > LIMITS["manifest"]:
        rep.error(f"manifest.toml is {len(raw)} bytes, over 64 KiB")
    try:
        manifest = tomllib.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, tomllib.TOMLDecodeError) as e:
        print(f"error: manifest.toml is not readable TOML: {e}")
        return 1

    schema, schema_ref = load_schema(find_schema(args.schema))
    run_check_jsonschema(manifest_path, schema_ref, rep)

    # Identity and the schema range.
    tid = manifest.get("id")
    if not isinstance(tid, str) or not ID_PATTERN.match(tid):
        rep.error("id must be lowercase letters, digits, '.', '_' or '-', starting with a letter or digit")
    sch = manifest.get("schema") or {}
    lo, hi = sch.get("min"), sch.get("max")
    if isinstance(lo, int) and isinstance(hi, int):
        if lo > hi:
            rep.error("schema.min is greater than schema.max")
        if hi < APP_SCHEMA[0] or lo > APP_SCHEMA[1]:
            rep.error(f"schema {lo}..{hi} does not overlap the app's {APP_SCHEMA[0]}..{APP_SCHEMA[1]}")

    # Files: only the names the installer accepts.
    icons = manifest.get("icons") or {}
    images = icons.get("images") or {}
    colors = icons.get("colors") or {}
    splash = manifest.get("splash")
    background = manifest.get("background") or {}

    allowed = {"manifest.toml", *BACKGROUNDS, *SPLASH_LOGOS}
    allowed |= {v for v in images.values() if isinstance(v, str)}
    total = 0
    for f in sorted(folder.rglob("*")):
        rel = f.relative_to(folder).as_posix()
        if any(part.startswith(".") for part in f.relative_to(folder).parts):
            continue  # left out when packed
        if f.is_symlink():
            rep.error(f"{rel}: symlinks are refused")
            continue
        if f.is_dir():
            continue
        total += f.stat().st_size
        if rel not in allowed:
            rep.error(f"{rel}: the installer refuses files it has no name for; remove it")
    if total > LIMITS["package"]:
        rep.error(f"the folder holds {total} bytes, over 16 MiB")

    # Icons.
    for key, rel in images.items():
        f = folder / str(rel)
        if not f.is_file():
            rep.error(f"icons.images.{key}: {rel} does not exist (the app would show the built-in glyph)")
            continue
        data = f.read_bytes()
        if len(data) > LIMITS["icon"]:
            rep.error(f"{rel}: {len(data)} bytes, over 256 KiB")
        if str(rel).endswith(".svg"):
            check_svg(f, data, rep)
        else:
            check_raster(f, data, 512, 512 * 512, rep)
    for key in colors:
        if key not in images:
            rep.error(f'icons.colors."{key}" names an icon the package carries no image for')

    # Background and splash.
    if background.get("type") == "image":
        name = background.get("image")
        f = folder / str(name)
        if not f.is_file():
            rep.error(f"background.image: {name} does not exist")
        else:
            data = f.read_bytes()
            if len(data) > LIMITS["background"]:
                rep.error(f"{name}: over 8 MiB")
            check_raster(f, data, 8192, 64 * MIB, rep)
    if isinstance(splash, dict) and splash.get("logo"):
        name = splash["logo"]
        f = folder / str(name)
        if not f.is_file():
            rep.error(f"splash.logo: {name} does not exist")
        else:
            data = f.read_bytes()
            if len(data) > LIMITS["splash"]:
                rep.error(f"{name}: over 512 KiB")
            if name.endswith(".svg"):
                # A splash logo is drawn in its own colors; only an unset
                # currentColor follows the theme (onSurface).
                check_svg(f, data, rep, tinted=False)
            else:
                check_raster(f, data, 2048, 2048 * 2048, rep)

    # Schema 2 features need min = 2, or an older app installs the package and
    # silently drops them.
    uses_v2 = (
        any(str(v).endswith(".svg") for v in images.values())
        or bool(colors)
        or splash is not None
    )
    if uses_v2 and isinstance(lo, int) and lo < FEATURE_SCHEMA:
        rep.error("SVG icons, icons.colors and [splash] are schema 2 features: set schema.min = 2")

    # Modes vs palettes: a palette for a mode the theme does not declare is
    # never shown.
    modes = manifest.get("modes") or []
    palettes = (manifest.get("colors") or {}).get("palette") or {}
    for b in ("light", "dark"):
        if palettes.get(b) and b not in modes:
            rep.warn(f"colors.palette.{b} is set but modes has no '{b}'; it is never shown")
        if b in modes and not palettes.get(b):
            rep.warn(f"'{b}' mode has no palette: every role is generated from the seed")

    lines = check_contrast(manifest, rep)

    print(f"theme  {tid}  ({manifest_path})")
    print(f"schema {schema_ref}")
    if lines:
        print("contrast:")
        print("\n".join(lines))
    for w in rep.warnings:
        print(f"warning: {w}")
    for e in rep.errors:
        print(f"error: {e}")
    print("OK" if not rep.errors else f"{len(rep.errors)} error(s)")
    return 0 if not rep.errors else 1


if __name__ == "__main__":
    sys.exit(main())
