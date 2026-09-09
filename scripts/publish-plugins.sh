#!/usr/bin/env bash
#
# Publishes every plugin in `packages/plugins` to the official repository.
#
#   scripts/publish-plugins.sh [--repo-dir DIR] [--allow-republish]
#
# DIR is a clone of lollipopkit/serverbox-plugins, `../serverbox-plugins` by
# default. Needs `bun`, `git` and `gh`.
#
# The repository is text — one TOML file per plugin — and the packages are its
# own releases, **one release per plugin version**, tagged `<id>-<version>`. So
# a tag identifies exactly one set of bytes and keeps its URL for as long as a
# file lists that version.
#
# **The package goes up before the file that names it.** A file pointing at an
# address that 404s is broken for everybody who reads it, while an uploaded
# package nothing lists yet is invisible and harmless. Stopping between the two
# costs nothing; running this again finishes it.
#
# It ends by fetching the repository the way a client does and checking every
# version against what the files say. Every other check here works from the bytes
# on this machine, and the ways publishing goes wrong live in the gap between
# those and the ones a user downloads.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAP_SLUG="lollipopkit/serverbox-plugins"
ADDRESS="https://github.com/$TAP_SLUG"

repo_dir="$(cd "$ROOT_DIR/.." && pwd)/serverbox-plugins"
allow_republish=""

while [ $# -gt 0 ]; do
  case "$1" in
    --repo-dir) repo_dir="$2"; shift 2 ;;
    --allow-republish) allow_republish="--allow-republish"; shift ;;
    -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

for tool in bun gh; do
  command -v "$tool" >/dev/null || { echo "$tool is not installed" >&2; exit 1; }
done

[ -d "$repo_dir/.git" ] || {
  echo "$repo_dir is not a clone — clone $TAP_SLUG there first" >&2
  exit 1
}

# A dirty or stale checkout is how a publish ends up on top of something else's
# half-finished one.
if [ -n "$(git -C "$repo_dir" status --porcelain)" ]; then
  echo "$repo_dir has uncommitted changes; deal with them first" >&2
  exit 1
fi
git -C "$repo_dir" fetch --quiet origin
git -C "$repo_dir" merge --ff-only --quiet FETCH_HEAD

echo "==> packing"
# `pack` writes `dist/<id>-<version>.sbp`, so a previous version's package stays
# behind — and it would be published again from bytes rebuilt since, which the
# generator then refuses as a republish. What goes out is what this run packed.
rm -f "$ROOT_DIR"/packages/plugins/*/dist/*.sbp
for plugin in "$ROOT_DIR"/packages/plugins/*/; do
  [ -f "$plugin/manifest.json" ] || continue
  (cd "$plugin" && bun run pack)
done

echo "==> releasing the packages"
for sbp in "$ROOT_DIR"/packages/plugins/*/dist/*.sbp; do
  name="$(basename "$sbp")"
  # The tag is the file name without its extension, which is `tagOf` in
  # `plugin-tools`: a release and its one asset read the same.
  tag="${name%.sbp}"
  id="${tag%-*}"
  version="${tag##*-}"
  if gh release view "$tag" --repo "$TAP_SLUG" >/dev/null 2>&1; then
    # Never replaced. A tag names a version, a version names bytes; publishing
    # different bytes means a new version, which the generator also enforces.
    echo "  = $tag"
    continue
  fi
  gh release create "$tag" "$sbp" \
    --repo "$TAP_SLUG" \
    --title "$id $version" \
    --notes "The package this repository's file for \`$id\` names for version \`$version\`, and its checksum is there.

One release per plugin version, so this tag identifies exactly these bytes and keeps one URL for as long as that file lists the version." >/dev/null
  echo "  + $tag"
done

echo "==> writing the repository"
# shellcheck disable=SC2086
bun run "$ROOT_DIR/packages/plugin-tools/bin/repo.ts" \
  --repo "$repo_dir" --name "ServerBox plugins" $allow_republish

echo "==> checking it before it goes out"
bun run "$ROOT_DIR/packages/plugin-tools/bin/verify.ts" "$repo_dir"

if [ -z "$(git -C "$repo_dir" status --porcelain)" ]; then
  echo "==> nothing changed; already published"
  exit 0
fi

echo "==> committing"
git -C "$repo_dir" add -A
git -C "$repo_dir" commit --quiet -m "feat: publish $(date -u +%Y-%m-%d)"
git -C "$repo_dir" push --quiet

echo "==> reading it back the way a client does"
# GitHub resolves `HEAD` through a cache that can lag a push by a few seconds,
# so this is the one step worth re-running rather than believing on the first
# miss.
sleep 5
bun run "$ROOT_DIR/packages/plugin-tools/bin/verify.ts" "$ADDRESS"
