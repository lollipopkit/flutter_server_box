#!/usr/bin/env bash
# Download and SHA256-verify the pinned nFPM binary into the target directory.
# Single source of truth shared by build.yml and analysis.yml.
set -euo pipefail

DEST_DIR="${1:?usage: install-nfpm.sh <dest-dir>}"
if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "::error::install-nfpm.sh targets Linux x86_64 (found $(uname -s) $(uname -m))" >&2
  exit 1
fi
NFPM_VERSION="2.49.0"
NFPM_SHA256="2afaa5ffb5e3493402e31e7c67a5a1fb42133e3f66fc315ca0051934125561c7"
NFPM_URL="https://github.com/goreleaser/nfpm/releases/download/v${NFPM_VERSION}/nfpm_${NFPM_VERSION}_Linux_x86_64.tar.gz"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/nfpm.tar.gz" "$NFPM_URL"
echo "${NFPM_SHA256}  $tmp/nfpm.tar.gz" | sha256sum -c -
mkdir -p "$DEST_DIR"
tar -xzf "$tmp/nfpm.tar.gz" -C "$DEST_DIR" nfpm
chmod 755 "$DEST_DIR/nfpm"
