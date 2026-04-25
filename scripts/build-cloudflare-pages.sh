#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR/website"
bun install --frozen-lockfile
bun run build

cd "$ROOT_DIR/docs"
bun install
bun run build

rm -rf "$ROOT_DIR/website/dist/docs"
mkdir -p "$ROOT_DIR/website/dist/docs"
cp -R "$ROOT_DIR/docs/dist/." "$ROOT_DIR/website/dist/docs/"
