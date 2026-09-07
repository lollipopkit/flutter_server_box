#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# npm rather than bun, matching CI: Dependabot maintains a `package-lock.json`
# and does not maintain a `bun.lock`, so with bun every dependency PR against
# these two directories arrived with a manifest the lockfile did not match.
#
# `npm ci` on both, where docs used to run a plain `bun install`: that resolved
# whatever was newest at deploy time, so what the site was built from was not
# what any pull request had checked.
cd "$ROOT_DIR/website"
npm ci
npm run build

cd "$ROOT_DIR/docs"
npm ci
npm run build

rm -rf "$ROOT_DIR/website/dist/docs"
mkdir -p "$ROOT_DIR/website/dist/docs"
cp -R "$ROOT_DIR/docs/dist/." "$ROOT_DIR/website/dist/docs/"
