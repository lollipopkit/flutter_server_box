#!/bin/sh
# Fails when a Git LFS file in the working tree is still its pointer text — a
# checkout without LFS — so a build never ships a pointer as an image, font or
# theme package.
#
#   scripts/check-lfs.sh [path…]   # default: the whole repository
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
bad=$(git ls-files -z -- "${@:-.}" | xargs -0 git check-attr filter -- 2>/dev/null \
  | awk -F': ' '$3 == "lfs" { print $1 }' \
  | while IFS= read -r f; do
      [ -f "$f" ] && head -c 40 "$f" | grep -q '^version https://git-lfs' && echo "$f"
    done || true)
if [ -n "$bad" ]; then
  echo "Git LFS files are pointers here (run: git lfs install && git lfs pull):" >&2
  printf '%s\n' "$bad" | sed 's/^/  /' >&2
  exit 1
fi
