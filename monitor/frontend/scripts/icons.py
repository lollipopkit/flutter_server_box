# /// script
# dependencies = ["fonttools==4.60.1", "brotli==1.1.0"]
# ///
"""Writes the icon fonts: Material Symbols Rounded (the `material-symbols`
devDependency) with only the axes the kit draws, twice.

- `material-symbols-rounded.woff2`: every glyph. Apps and the desk name icons
  at run time (a catalog app's glyph, an installed app's), so the panel loads
  it once it is up, and installed apps get it with `desk.css`.
- `material-symbols-rounded-core.woff2`: the glyphs this source names (every
  string literal in `src/` and `../../store/apps` that is a glyph's name), so
  the first screen draws its icons without waiting for the whole font. Their
  names go to `core-icons.txt`, every glyph's to `all-icons.txt`;
  `tests/iconFonts.test.ts` holds the source to the core list: run this again
  after naming a new icon.

Of the axes, GRAD is always 0 and wght within 300-700 (`Icon`), so those are
pinned and narrowed; FILL and opsz (which follows the icon's size) keep
their whole range. About 5.4 MB down to 3.0 MB, and the core a fraction.

    uv run scripts/icons.py
"""

import re
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

root = Path(__file__).resolve().parent.parent
source = root / "node_modules/material-symbols/material-symbols-rounded.woff2"
fonts = root / "src/desk/lk/fonts"
target = fonts / "material-symbols-rounded.woff2"
core_target = fonts / "material-symbols-rounded-core.woff2"
# What a glyph's name may be, as a string literal in the source.
LITERAL = re.compile(r"""['"`]([a-z][a-z0-9_]{1,63})['"`]""")

font = TTFont(source)
font = instancer.instantiateVariableFont(font, {"GRAD": 0, "wght": (300, 700)})
font.flavor = "woff2"
font.save(target)
(fonts / "LICENSE-material-symbols").write_text((source.parent / "LICENSE").read_text())
print(f"{target.relative_to(root)}: {source.stat().st_size} -> {target.stat().st_size} bytes")

# A glyph's name is the word its ligature spells.
glyphs = set(font.getGlyphOrder())
names = sorted(n for n in glyphs if re.fullmatch(r"[a-z][a-z0-9_]*", n) and len(n) > 1)
(fonts / "all-icons.txt").write_text("\n".join(names) + "\n")
used = set()
for folder in (root / "src", root / "../../store/apps"):
    for path in folder.rglob("*"):
        if path.suffix in {".svelte", ".ts", ".toml"} and "i18n" not in path.parts and "tests" not in path.parts:
            for m in LITERAL.finditer(path.read_text(errors="ignore")):
                used.add(m.group(1))
core = sorted(used & set(names))
(fonts / "core-icons.txt").write_text("\n".join(core) + "\n")

options = subset.Options()
options.layout_features = ["*"]
options.flavor = "woff2"
options.notdef_outline = True
# Not every ligature the letters could spell: only the glyphs kept above.
options.layout_closure = False
sub = subset.Subsetter(options)
# The letters the ligatures are spelled with, and the glyphs they make.
letters = [g for g in glyphs if len(g) == 1 or g in {"underscore", "space"} or re.fullmatch(r"[a-z0-9]", g)]
sub.populate(glyphs=core + letters, text="abcdefghijklmnopqrstuvwxyz0123456789_ ")
core_font = TTFont(target)
sub.subset(core_font)
core_font.flavor = "woff2"
core_font.save(core_target)
print(f"{core_target.relative_to(root)}: {len(core)} glyphs, {core_target.stat().st_size} bytes")
