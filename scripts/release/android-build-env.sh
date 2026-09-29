#!/usr/bin/env bash
# Shared deterministic environment for the upstream and F-Droid Android builds.
# This file is sourced by the preparation and offline build entry points.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

expected_flutter_version="$(sed -n -E \
  's/^[[:space:]]*flutter-version:[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p' \
  "$REPO_ROOT/.github/actions/setup-flutter/action.yml" | tr -d "\"'")"
actual_flutter_version="$(flutter --version --machine | sed -n -E \
  's/^[[:space:]]*"frameworkVersion":[[:space:]]*"([^"]+)".*/\1/p')"

[ -n "$expected_flutter_version" ] || {
  echo "could not read the pinned Flutter version" >&2
  exit 1
}
[ "$actual_flutter_version" = "$expected_flutter_version" ] || {
  echo "Flutter $actual_flutter_version is active; expected $expected_flutter_version" >&2
  exit 1
}

export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "$REPO_ROOT" log -1 --format=%ct)}"
export TZ=UTC
export LC_ALL=C
export ORG_GRADLE_PROJECT_allowUnsignedRelease=true

# Do not inherit an arbitrary host cache. An explicit PUB_CACHE wins: F-Droid's
# recipe fetches into an in-tree `.pub-cache` during `prebuild` so its scanner
# sees the packages.
FDROID_CACHE_DIR="${FDROID_CACHE_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/server-box-fdroid-cache}"
export PUB_CACHE="${PUB_CACHE:-$FDROID_CACHE_DIR/pub}"
export GRADLE_USER_HOME="${FDROID_GRADLE_USER_HOME:-$FDROID_CACHE_DIR/gradle}"
export PROOT_BUILD_DIR="${PROOT_BUILD_DIR:-$FDROID_CACHE_DIR/proot}"
# No CARGO_HOME / RUSTUP_HOME here: the native-assets hook that runs cargo gets
# only hooks_runner's environment allowlist (HOME and PATH, not these), so it
# always uses ~/.cargo and ~/.rustup. Setting them for the scripts alone would
# prepare a toolchain and registry the hook never reads.

# The hook runs rustup in crates/sbm_ffi, which picks this toolchain file.
rust_toolchain_file="$REPO_ROOT/crates/sbm_ffi/rust-toolchain.toml"
rust_toolchain="$(sed -n -E \
  's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
  "$rust_toolchain_file")"
[ -n "$rust_toolchain" ] || { echo "Rust toolchain is not pinned" >&2; exit 1; }
mapfile -t rust_targets < <(sed -n -E \
  's/^[[:space:]]*"([^"]+)",?[[:space:]]*$/\1/p' \
  "$rust_toolchain_file")
[ "${#rust_targets[@]}" -gt 0 ] || { echo "Rust targets are not pinned" >&2; exit 1; }
