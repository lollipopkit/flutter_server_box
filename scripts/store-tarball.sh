#!/bin/sh
# Write the theme store's tarball: `store/` as committed at HEAD, as the app
# reads a repository (`ThemeRepos.readArchive`).
#
#   scripts/store-tarball.sh <out.tar.gz>
#
# The website build runs this (`website/package.json`, `prebuild`), so the store
# is served at https://serverbox.lollipopkit.com/store.tar.gz, the address
# `assets/catalog/repos.toml` lists.
#
# Packed from the working tree, not with `git archive`: theme packages and
# images are Git LFS objects, and `git archive` writes their pointers. So the
# tree must be HEAD's (no change, no untracked file under `store/`) and every
# LFS file fetched (`check-lfs.sh`). Python's `tarfile`, not `tar`: pax with
# no xattr records (macOS `tar` adds binary ones the app refuses), sorted,
# owned by root, every time HEAD's commit time, so one commit gives one file.
# The `store/` prefix is the one wrapper directory a source tarball has, and
# the reader drops it.
set -eu

[ $# -eq 1 ] || { echo "usage: $0 <out.tar.gz>" >&2; exit 2; }
root=$(cd "$(dirname "$0")/.." && pwd)
# Where the caller meant it, not relative to the repository root.
out=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
cd "$root"
if ! git diff --quiet HEAD -- store || [ -n "$(git ls-files --others --exclude-standard -- store)" ]; then
  echo "store/ differs from HEAD; commit or stash it first" >&2
  exit 1
fi
sh scripts/check-lfs.sh store
git ls-files -z -- store | python3 -I -c '
import gzip, io, os, sys, tarfile
out, mtime = sys.argv[1], int(sys.argv[2])
paths = sorted(p for p in sys.stdin.buffer.read().decode().split("\0") if p)
def entry(name, kind, mode, size=0):
    info = tarfile.TarInfo(name)
    info.type, info.mode, info.size, info.mtime = kind, mode, size, mtime
    info.uid = info.gid = 0
    info.uname = info.gname = ""
    return info
dirs = sorted({"/".join(p.split("/")[:i]) for p in paths for i in range(1, p.count("/") + 1)})
with open(out, "wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", mtime=mtime, filename="") as gz, \
        tarfile.open(fileobj=gz, mode="w", format=tarfile.PAX_FORMAT) as tar:
    for name in sorted(dirs + paths):
        if name in dirs:
            tar.addfile(entry(name + "/", tarfile.DIRTYPE, 0o755))
        else:
            with open(name, "rb") as f:
                data = f.read()
            mode = 0o755 if os.access(name, os.X_OK) else 0o644
            tar.addfile(entry(name, tarfile.REGTYPE, mode, len(data)), io.BytesIO(data))
' "$out" "$(git log -1 --format=%ct HEAD)"
