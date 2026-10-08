# /// script
# dependencies = ["fonttools==4.60.1", "brotli==1.1.0"]
# ///
"""Writes src/fonts/material-symbols-rounded.woff2: Material Symbols Rounded
(the `material-symbols` devDependency) with only the axes the kit draws.

Every glyph stays (apps and the desk name icons at run time, so none can be
dropped). Of the axes, GRAD is always 0 and wght within 300-700 (`Icon`), so
those are pinned and narrowed; FILL and opsz (which follows the icon's size)
keep their whole range. About 5.4 MB down to 3.0 MB.

    uv run scripts/icons.py
"""

from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

root = Path(__file__).resolve().parent.parent
source = root / "node_modules/material-symbols/material-symbols-rounded.woff2"
target = root / "src/fonts/material-symbols-rounded.woff2"

font = TTFont(source)
font = instancer.instantiateVariableFont(font, {"GRAD": 0, "wght": (300, 700)})
font.flavor = "woff2"
font.save(target)
(root / "src/fonts/LICENSE-material-symbols").write_text((source.parent / "LICENSE").read_text())
print(f"{target.relative_to(root)}: {source.stat().st_size} -> {target.stat().st_size} bytes")
