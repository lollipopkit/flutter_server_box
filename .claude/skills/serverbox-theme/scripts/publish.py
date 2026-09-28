#!/usr/bin/env python3
"""Publish the themes of a theme repository that changed since their last version.

    python3 publish.py                       # every theme, in the repository around the working directory
    python3 publish.py --root path/to/repo   # a theme repository elsewhere
    python3 publish.py yourname.nord         # only these themes
    python3 publish.py yourname.nord=2.0.0   # an exact version
    python3 publish.py --bump minor
    python3 publish.py --dry-run             # say what would happen
    python3 publish.py --init --name "Somebody's themes"   # start a repository here

A theme repository is what the ServerBox theme store reads:

    repo.toml              schema = 1, name = "..."
    themes/<id>.toml       the listing: id, name, description, license, [[version]]s
    themes/<id>/           the theme itself: manifest.toml, icons/, ...

For each theme it packs `themes/<id>/` and compares the package with the newest
version the listing records. The same bytes mean nothing changed and the theme
is skipped; different bytes are a new version — the patch number bumped (or
`--bump`, or `<id>=<version>`), 1.0.0 for a theme with no version yet.

Every new package goes up in one upload to a single release of the GitHub
repository `origin` points at (tag `themes` unless `--release` says otherwise),
then each listing gets its `[[version]]`, sha256 and size appended. Commit and
push the listings afterwards: the store reads the repository's default branch.

**The package is deterministic**, which is what makes "changed" answerable:
entries sorted, one fixed timestamp, fixed permissions, and stored rather than
deflated, so the bytes depend on the files alone — not on a checkout's mtimes
or a machine's zlib. Dotfiles are left out.

Rules it keeps:

- **The themes release is never the repository's Latest.** It is created as a
  pre-release, which GitHub never marks Latest, and with `--latest=false`; the
  Latest release stays the one the repository's own software ships. The script
  checks that before it uploads anything.
- Packages go up before the listings name them: a listing pointing at an
  address that answers 404 is broken for everybody, a package nothing lists is
  harmless.
- An asset is never replaced. If one by that name is already up — an earlier
  run that stopped before writing the listing — its bytes must equal these, and
  then only the listing is written.
- A version number never names two sets of bytes.

Needs Python 3.11+ and an authenticated `gh` (https://cli.github.com).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
import tomllib
import urllib.request
import zipfile
from pathlib import Path

FIXED_TIME = (1980, 1, 1, 0, 0, 0)


def gh(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    proc = subprocess.run(["gh", *args], capture_output=True, text=True)
    if check and proc.returncode != 0:
        sys.exit(f"gh {' '.join(args[:3])}: {proc.stderr.strip()}")
    return proc


def find_root(start: Path) -> Path | None:
    for d in [start, *start.parents]:
        if (d / "repo.toml").is_file():
            return d
    return None


def github_slug(root: Path) -> str:
    url = subprocess.run(
        ["git", "-C", str(root), "remote", "get-url", "origin"],
        capture_output=True, text=True,
    ).stdout.strip().removesuffix(".git")
    for prefix in ("git@github.com:", "https://github.com/", "ssh://git@github.com/"):
        if url.startswith(prefix):
            return url[len(prefix):]
    sys.exit(f"the git remote origin is not a GitHub repository: {url or '(none)'}")


def pack(folder: Path) -> bytes:
    files = sorted(
        p for p in folder.rglob("*")
        if p.is_file() and not any(part.startswith(".") for part in p.relative_to(folder).parts)
    )
    with tempfile.SpooledTemporaryFile() as buf:
        with zipfile.ZipFile(buf, "w", zipfile.ZIP_STORED) as z:
            for f in files:
                info = zipfile.ZipInfo(f.relative_to(folder).as_posix(), FIXED_TIME)
                info.external_attr = 0o644 << 16
                info.create_system = 3
                z.writestr(info, f.read_bytes())
        buf.seek(0)
        return buf.read()


def version_key(v: str) -> tuple:
    core, _, pre = v.partition("-")
    nums = [int(n) if n.isdigit() else 0 for n in core.split(".")]
    nums += [0] * (3 - len(nums))
    # A pre-release sorts below the same numbers without one.
    return (*nums[:3], 0 if pre else 1, pre)


def bump(v: str, part: str) -> str:
    major, minor, patch = version_key(v)[:3]
    if part == "major":
        return f"{major + 1}.0.0"
    if part == "minor":
        return f"{major}.{minor + 1}.0"
    return f"{major}.{minor}.{patch + 1}"


def init(root: Path, name: str) -> int:
    repo = root / "repo.toml"
    if repo.exists():
        sys.exit(f"{repo} already exists")
    (root / "themes").mkdir(exist_ok=True)
    repo.write_text(f'schema = 1\nname = "{name}"\n', "utf-8")
    print(f"wrote {repo} and themes/. Add themes/<id>/ (the theme) and themes/<id>.toml:")
    print('  id = "<id>"\n  name = "..."\n  description = "..."\n  license = "MIT"')
    return 0


def check_latest(repo: str, release: str) -> None:
    latest = gh("api", f"repos/{repo}/releases/latest", check=False)
    if latest.returncode == 0 and json.loads(latest.stdout).get("tag_name") == release:
        sys.exit(
            f"the {release} release is {repo}'s Latest; mark it a pre-release: "
            f"gh release edit {release} --repo {repo} --prerelease --latest=false"
        )


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("themes", nargs="*", help="<id> or <id>=<version>; default: every theme")
    ap.add_argument("--root", type=Path, help="the theme repository (default: the one around the working directory)")
    ap.add_argument("--release", default="themes", help="the release tag every package goes to (default: themes)")
    ap.add_argument("--bump", choices=["patch", "minor", "major"], default="patch")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--init", action="store_true", help="write repo.toml and themes/ here")
    ap.add_argument("--name", default="My themes", help="with --init: what the store calls the repository")
    args = ap.parse_args()

    if args.init:
        return init((args.root or Path.cwd()).resolve(), args.name)

    root = (args.root.resolve() if args.root else find_root(Path.cwd().resolve()))
    if root is None or not (root / "repo.toml").is_file():
        sys.exit("no repo.toml here or above: pass --root, or start one with --init")
    themes_dir = root / "themes"

    wanted: dict[str, str | None] = {}
    for a in args.themes:
        tid, _, ver = a.partition("=")
        wanted[tid] = ver or None
    ids = list(wanted) or sorted(p.stem for p in themes_dir.glob("*.toml"))

    repo = github_slug(root)
    plan = []  # (id, version, bytes, digest, listing path, schema)
    for tid in ids:
        folder, listing_path = themes_dir / tid, themes_dir / f"{tid}.toml"
        if not folder.is_dir() or not listing_path.is_file():
            sys.exit(f"{tid}: needs themes/{tid}/ and themes/{tid}.toml")
        manifest = tomllib.loads((folder / "manifest.toml").read_text("utf-8"))
        listing = tomllib.loads(listing_path.read_text("utf-8"))
        # The app installs what the manifest says, and the store checks a
        # listing's file name against its id: all three are one spelling.
        if manifest.get("id") != tid or listing.get("id") != tid:
            sys.exit(f"{tid}: manifest id {manifest.get('id')!r} / listing id {listing.get('id')!r} differ from the folder")
        schema = manifest.get("schema") or {}
        if not isinstance(schema.get("min"), int) or not isinstance(schema.get("max"), int):
            sys.exit(f"{tid}: manifest declares no [schema] min and max")

        data = pack(folder)
        if len(data) > 16 * 1024 * 1024:
            sys.exit(f"{tid}: the package is over 16 MiB")
        digest = hashlib.sha256(data).hexdigest()
        versions = sorted(listing.get("version") or [], key=lambda v: version_key(v["version"]))
        newest = versions[-1] if versions else None
        if newest and newest.get("sha256") == digest:
            print(f"  {tid}: unchanged since {newest['version']}")
            continue

        version = wanted.get(tid) or (bump(newest["version"], args.bump) if newest else "1.0.0")
        if any(v["version"] == version for v in versions):
            sys.exit(f"{tid}: {version} is already recorded with other bytes; pick a new version")
        if newest and version_key(version) <= version_key(newest["version"]):
            sys.exit(f"{tid}: {version} is not newer than {newest['version']}")
        plan.append((tid, version, data, digest, listing_path, schema))
        print(f"+ {tid}: {newest['version'] if newest else '(new)'} -> {version}  {digest[:12]}  {len(data)} B")

    if not plan:
        print("nothing changed")
        return 0
    if args.dry_run:
        return 0

    release = args.release
    if gh("release", "view", release, "--repo", repo, check=False).returncode != 0:
        gh("release", "create", release, "--repo", repo, "--title", "Themes",
           "--prerelease", "--latest=false",
           "--notes", "Theme packages for the ServerBox theme store, one asset per version. "
                      "Listed in the repository's themes/ folder.")
        print(f"created release {release} (pre-release, never Latest)")
    # Before anything goes up: a themes release that is Latest is a mistake to
    # fix first, not one to publish more packages into.
    check_latest(repo, release)
    up = json.loads(gh("release", "view", release, "--repo", repo, "--json", "assets").stdout)["assets"]
    uploaded = {a["name"] for a in up}

    with tempfile.TemporaryDirectory() as tmp:
        to_upload = []
        for tid, version, data, digest, *_ in plan:
            name = f"{tid}-{version}.fsbt"
            if name in uploaded:
                url = f"https://github.com/{repo}/releases/download/{release}/{name}"
                with urllib.request.urlopen(url, timeout=60) as r:  # noqa: S310
                    served = hashlib.sha256(r.read()).hexdigest()
                if served != digest:
                    sys.exit(f"{name} is already up with other bytes ({served[:12]}); bump the version")
                print(f"  {name}: already up with these bytes")
                continue
            path = Path(tmp) / name
            path.write_bytes(data)
            to_upload.append(str(path))
        if to_upload:
            gh("release", "upload", release, *to_upload, "--repo", repo)
            print(f"uploaded {len(to_upload)} package(s) to {release}")

    for tid, version, data, digest, listing_path, schema in plan:
        name = f"{tid}-{version}.fsbt"
        with listing_path.open("a", encoding="utf-8") as f:
            f.write(
                f"\n[[version]]\n"
                f'version = "{version}"\n'
                f"schema_min = {schema['min']}\n"
                f"schema_max = {schema['max']}\n"
                f'url = "https://github.com/{repo}/releases/download/{release}/{name}"\n'
                f'sha256 = "{digest}"\n'
                f"size = {len(data)}\n"
            )
        print(f"  {tid} {version} added to themes/{tid}.toml")

    print("commit and push the listings")
    return 0


if __name__ == "__main__":
    sys.exit(main())
