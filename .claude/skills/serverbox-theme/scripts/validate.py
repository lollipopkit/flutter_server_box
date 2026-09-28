#!/usr/bin/env python3
"""Check a ServerBox theme folder the way the app's installer will.

    python3 validate.py <theme-folder> [--schema <fsbt-manifest.schema.json>]

Two layers:

1. The manifest against the JSON Schema the app publishes
   (docs/schemas/fsbt-manifest.schema.json), through `check-jsonschema` run by
   `uvx` or `pipx`. The schema is as strict as the installer on everything a
   single table can say: unknown fields, ranges, enums, icon paths.
2. What the schema cannot say, checked here: an `icons.colors` key without an
   image, schema 2 features under `min = 1`, schema 3 components or `[layout]`
   under `min < 3`, the files themselves (names, sizes,
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
APP_SCHEMA = (1, 3)
FEATURE_SCHEMA = 2
COMPONENT_SCHEMA = 3

# The components and fields schema 2 had (ThemeComponents.schema2 in the app).
# Anything else under [components], and [layout], needs schema.min = 3.
_SHAPE = {"radius", "borderColor", "borderWidth"}
_SURFACE = {"backgroundColor", "elevation", "shadowColor", "surfaceTintColor"}
SCHEMA2_COMPONENTS = {
    "card": _SHAPE | _SURFACE | {"margin"},
    "tile": _SHAPE | {"backgroundColor", "selectedTileColor", "textColor", "iconColor", "selectedColor", "padding"},
    "button": _SHAPE | _SURFACE | {"foregroundColor", "overlayColor", "padding"},
    "input": _SHAPE | {"filled", "fillColor", "focusedBorderColor", "errorBorderColor", "disabledBorderColor", "padding"},
    "navigation": {"backgroundColor", "indicatorColor", "indicatorRadius", "selectedIconColor",
                   "unselectedIconColor", "selectedLabelColor", "unselectedLabelColor", "elevation"},
    "dialog": _SHAPE | _SURFACE | {"barrierColor", "insetPadding"},
    "sheet": _SHAPE | _SURFACE | {"barrierColor", "dragHandleColor"},
}
BUTTON_STATES = {"disabled", "pressed", "hovered", "focused", "selected"}


def schema3_uses(manifest: dict) -> list[str]:
    """What in the manifest schema 2 did not have, as dotted paths."""
    found = []
    if manifest.get("layout"):
        found.append("[layout]")
    if manifest.get("variants"):
        found.append("[variants]")
    background = manifest.get("background")
    if isinstance(background, dict) and background.get("tile") is not None:
        found.append("background.tile")
    # Not a table is reported by check_theme; here it only has nothing to walk.
    components = manifest.get("components")
    if not isinstance(components, dict):
        return found

    def table(name: str, fields: dict, path: str) -> None:
        allowed = SCHEMA2_COMPONENTS.get(name)
        if allowed is None:
            found.append(path)
            return
        for key, value in fields.items():
            if name == "button" and key in BUTTON_STATES and isinstance(value, dict):
                found.extend(f"{path}.{key}.{k}" for k in value if k not in allowed)
            elif key not in allowed:
                found.append(f"{path}.{key}")

    for name, fields in components.items():
        if name in ("light", "dark") and isinstance(fields, dict):
            for inner, inner_fields in fields.items():
                if isinstance(inner_fields, dict):
                    table(inner, inner_fields, f"components.{name}.{inner}")
        elif isinstance(fields, dict):
            table(name, fields, f"components.{name}")
    return found

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


def merge(base: dict, overrides: dict) -> dict:
    """The installer's merge: tables merge key by key, anything else replaces."""
    out = dict(base)
    for k, v in overrides.items():
        out[k] = merge(out[k], v) if isinstance(out.get(k), dict) and isinstance(v, dict) else v
    return out


def safe_file(folder: Path, rel: str) -> Path | None:
    """The regular file `rel` names inside `folder`, or None.

    None for a path that is absolute, climbs out with `..`, or passes through a
    symlink at any level — checked before anything is read, so a theme folder
    cannot point the validator at a file outside it. The installer refuses the
    same things.
    """
    rel_path = Path(rel)
    if rel_path.is_absolute() or ".." in rel_path.parts:
        return None
    f = folder
    for part in rel_path.parts:
        f = f / part
        if f.is_symlink():
            return None
    return f if f.is_file() else None


def check_theme(manifest: dict, folder: Path, key: str | None, lo, rep: Report, where: str):
    """One theme's own rules; answers the package files it used and its contrast lines."""
    used: set[str] = set()

    def locate(name: str) -> tuple[Path | None, str]:
        if key:
            rel = f"variants/{key}/{name}"
            if (f := safe_file(folder, rel)) is not None:
                return f, rel
        return safe_file(folder, name), name

    # Tables the checks below walk, which the schema check may not have run on:
    # one that is not a table is reported and read as empty, so the rest of the
    # checks still run.
    for table in ("components", "background", "icons"):
        if table in manifest and not isinstance(manifest[table], dict):
            rep.error(f"{where}{table} must be a table")

    def table_of(value) -> dict:
        return value if isinstance(value, dict) else {}

    icons = table_of(manifest.get("icons"))
    for sub in ("images", "colors"):
        if sub in icons and not isinstance(icons[sub], dict):
            rep.error(f"{where}icons.{sub} must be a table")
    images = table_of(icons.get("images"))
    colors = table_of(icons.get("colors"))
    splash = manifest.get("splash")
    background = table_of(manifest.get("background"))

    # Icons.
    for ikey, rel in images.items():
        f = safe_file(folder, str(rel))
        used.add(str(rel))
        if f is None:
            rep.error(f"{where}icons.images.{ikey}: {rel} does not exist or is a symlink (the app would show the built-in glyph)")
            continue
        data = f.read_bytes()
        if len(data) > LIMITS["icon"]:
            rep.error(f"{rel}: {len(data)} bytes, over 256 KiB")
        if str(rel).endswith(".svg"):
            check_svg(f, data, rep)
        else:
            check_raster(f, data, 512, 512 * 512, rep)
    for ikey in colors:
        if ikey not in images:
            rep.error(f'{where}icons.colors."{ikey}" names an icon the package carries no image for')

    # Background and splash.
    if background.get("type") == "image":
        f, rel = locate(str(background.get("image")))
        used.add(rel)
        if f is None:
            rep.error(f"{where}background.image: {background.get('image')} does not exist or is a symlink")
        else:
            data = f.read_bytes()
            if len(data) > LIMITS["background"]:
                rep.error(f"{rel}: over 8 MiB")
            check_raster(f, data, 8192, 64 * MIB, rep)
    if isinstance(splash, dict) and splash.get("logo"):
        name = str(splash["logo"])
        f, rel = locate(name)
        used.add(rel)
        if f is None:
            rep.error(f"{where}splash.logo: {name} does not exist or is a symlink")
        else:
            data = f.read_bytes()
            if len(data) > LIMITS["splash"]:
                rep.error(f"{rel}: over 512 KiB")
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
        rep.error(f"{where}SVG icons, icons.colors and [splash] are schema 2 features: set schema.min = 2")

    # Schema 3: the components beyond schema 2's seven, new fields, [layout].
    # A build that reads only 2 refuses these outright, so the store has to
    # know before the download.
    uses_v3 = schema3_uses(manifest)
    if uses_v3 and isinstance(lo, int) and lo < COMPONENT_SCHEMA:
        shown = ", ".join(uses_v3[:4]) + (" ..." if len(uses_v3) > 4 else "")
        rep.error(f"{where}{shown}: schema 3 features, set schema.min = 3")

    # Modes vs palettes: a palette for a mode the theme does not declare is
    # never shown.
    modes = manifest.get("modes") or []
    palettes = (manifest.get("colors") or {}).get("palette") or {}
    for b in ("light", "dark"):
        if palettes.get(b) and b not in modes:
            rep.warn(f"{where}colors.palette.{b} is set but modes has no '{b}'; it is never shown")
        if b in modes and not palettes.get(b):
            rep.warn(f"{where}'{b}' mode has no palette: every role is generated from the seed")

    return used, check_contrast(manifest, rep)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder")
    ap.add_argument("--schema", help="path to fsbt-manifest.schema.json")
    args = ap.parse_args()

    folder = Path(args.folder)
    manifest_path = folder / "manifest.toml"
    rep = Report()
    if safe_file(folder, "manifest.toml") is None:
        print(f"error: {manifest_path} does not exist or is a symlink")
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
    sch = manifest.get("schema")
    schema_table = isinstance(sch, dict)
    if not schema_table:
        rep.error("schema must be a table with min and max")
        sch = {}
    lo, hi = sch.get("min"), sch.get("max")
    # As the installer reads it: exactly min and max, integers from 1. Without
    # them no feature gate below can be checked, so that alone is an error.
    # (`bool` is an `int` to Python, and not to TOML or the app.)
    def schema_int(v) -> bool:
        return isinstance(v, int) and not isinstance(v, bool) and v >= 1
    # An empty `[schema]` too: a table without its bounds is not a range.
    if schema_table and (set(sch) != {"min", "max"} or not (schema_int(lo) and schema_int(hi))):
        rep.error("schema must hold exactly min and max, each an integer from 1")
        lo = hi = None
    if isinstance(lo, int) and isinstance(hi, int):
        if lo > hi:
            rep.error("schema.min is greater than schema.max")
        if hi < APP_SCHEMA[0] or lo > APP_SCHEMA[1]:
            rep.error(f"schema {lo}..{hi} does not overlap the app's {APP_SCHEMA[0]}..{APP_SCHEMA[1]}")

    # The themes the package installs as: itself, or each of its variants —
    # the base tables with the variant's drawn over them, reading
    # variants/<key>/<file> in place of the package's file of that name.
    variants = manifest.get("variants")
    themes = []  # (label, manifest, key or None)
    # The installer refuses each of these outright rather than reading the
    # package as one without variants.
    if "variants" in manifest and not isinstance(variants, dict):
        rep.error("variants must be a table of [variants.<key>] tables")
    elif isinstance(variants, dict) and not variants:
        rep.error("[variants] is empty: give it at least one [variants.<key>] table, or remove it")
    if isinstance(variants, dict) and variants:
        base = {k: v for k, v in manifest.items() if k != "variants"}
        for key, table in variants.items():
            if not isinstance(table, dict):
                rep.error(f"variants.{key} must be a table")
                continue
            if isinstance(table.get("icons"), dict) and "images" in table["icons"]:
                rep.error(f"variants.{key}.icons.images: a variant shares the package's icon files")
            overrides = {k: v for k, v in table.items() if k != "name"}
            themes.append((f"variant {key}", merge(base, overrides), key))
    else:
        themes.append(("", manifest, None))
    if variants and isinstance(lo, int) and lo < COMPONENT_SCHEMA:
        rep.error("[variants] is a schema 3 feature: set schema.min = 3")

    # Files: only the names the installer accepts, and each used by a theme.
    keys = [k for _, _, k in themes if k]
    allowed = {"manifest.toml", *BACKGROUNDS, *SPLASH_LOGOS}
    allowed |= {f"variants/{k}/{n}" for k in keys for n in (*BACKGROUNDS, *SPLASH_LOGOS)}
    icons = manifest.get("icons")
    images = icons.get("images") if isinstance(icons, dict) else None
    if isinstance(images, dict):
        allowed |= {v for v in images.values() if isinstance(v, str)}
    present = []
    total = 0
    for f in sorted(folder.rglob("*")):
        rel = f.relative_to(folder).as_posix()
        if any(part.startswith(".") for part in f.relative_to(folder).parts):
            continue  # left out when packed
        if f.is_symlink():
            rep.error(f"{rel}: symlinks are refused")
            continue
        # Under a symlinked directory, which older Pythons' rglob descends
        # into: already reported at the directory, and not this theme's.
        parts = f.relative_to(folder).parts
        if any((folder.joinpath(*parts[:i])).is_symlink() for i in range(1, len(parts))):
            continue
        if f.is_dir():
            continue
        total += f.stat().st_size
        if rel not in allowed:
            rep.error(f"{rel}: the installer refuses files it has no name for; remove it")
        else:
            present.append(rel)
    if total > LIMITS["package"]:
        rep.error(f"the folder holds {total} bytes, over 16 MiB")

    used = {"manifest.toml"}
    lines = []
    for label, theme, key in themes:
        where = f"{label}: " if label else ""
        found, contrast_lines = check_theme(theme, folder, key, lo, rep, where)
        used |= found
        if label:
            lines.append(f"  [{label}]")
        lines += contrast_lines
    for rel in present:
        if rel not in used:
            rep.error(f"{rel}: no theme in the package uses it, and the installer refuses it")

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
