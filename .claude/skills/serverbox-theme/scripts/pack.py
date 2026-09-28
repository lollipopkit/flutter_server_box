#!/usr/bin/env python3
"""Pack a theme folder into a .fsbt and print what a listing needs.

    python3 pack.py <theme-folder> [-o out.fsbt] [--version 1.0.0] [--url URL]

The package is a ZIP with manifest.toml at the archive root. Dotfiles
(.DS_Store, .git) are left out, entries are sorted, carry a fixed timestamp and
are stored rather than deflated, so the same files give the same bytes and the
same sha256 on any machine (deflate output depends on the local zlib). With
--version (and --url where the package will be downloaded from), it also prints
the `[[version]]` block for a theme repository's listing.

Run validate.py first: this does not check the contents.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
import tomllib
import zipfile
from pathlib import Path

MAX_PACKAGE = 16 * 1024 * 1024
FIXED_TIME = (1980, 1, 1, 0, 0, 0)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder")
    ap.add_argument("-o", "--out")
    ap.add_argument("--version", help="the theme's own version, for the listing block")
    ap.add_argument("--url", help="where the .fsbt will be served, for the listing block")
    args = ap.parse_args()

    folder = Path(args.folder)
    manifest = tomllib.loads((folder / "manifest.toml").read_text("utf-8"))
    tid = manifest["id"]
    out = Path(args.out or f"{tid}{'-' + args.version if args.version else ''}.fsbt")

    files = sorted(
        f
        for f in folder.rglob("*")
        if f.is_file()
        and not any(p.startswith(".") for p in f.relative_to(folder).parts)
    )
    with zipfile.ZipFile(out, "w", zipfile.ZIP_STORED) as z:
        for f in files:
            info = zipfile.ZipInfo(f.relative_to(folder).as_posix(), FIXED_TIME)
            info.external_attr = 0o644 << 16
            info.create_system = 3
            z.writestr(info, f.read_bytes())

    data = out.read_bytes()
    if len(data) > MAX_PACKAGE:
        print(f"error: {out} is {len(data)} bytes, over 16 MiB", file=sys.stderr)
        return 1
    digest = hashlib.sha256(data).hexdigest()
    print(f"package {out}")
    print(f"sha256  {digest}")
    print(f"size    {len(data)}")

    if args.version:
        schema = manifest["schema"]
        print("\n# listing block for themes/%s.toml" % tid)
        print("[[version]]")
        print(f'version = "{args.version}"')
        print(f"schema_min = {schema['min']}")
        print(f"schema_max = {schema['max']}")
        print(f'url = "{args.url or "https://…/" + out.name}"')
        print(f'sha256 = "{digest}"')
        print(f"size = {len(data)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
