#!/bin/sh
# Write the theme store's tarball: `store/` at HEAD, as the app reads a
# repository (`ThemeRepos.readArchive`).
#
#   scripts/store-tarball.sh <out.tar.gz>
#
# The website build runs this (`website/package.json`, `prebuild`), so the store
# is served at https://serverbox.lollipopkit.com/store.tar.gz, the address
# `assets/catalog/repos.toml` lists.
#
# `git archive`, not `tar`: it writes the ustar/pax a hosting service does, and
# macOS `tar` adds binary xattr records the app refuses. HEAD, not the working
# tree: what is served is what was committed. The `store/` prefix is the one
# wrapper directory a source tarball has, and the reader drops it.
set -eu

[ $# -eq 1 ] || { echo "usage: $0 <out.tar.gz>" >&2; exit 2; }
root=$(cd "$(dirname "$0")/.." && pwd)
# Where the caller meant it, not relative to the repository root `git -C` runs in.
out=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
git -C "$root" archive --format=tar.gz --prefix=store/ -o "$out" HEAD:store
