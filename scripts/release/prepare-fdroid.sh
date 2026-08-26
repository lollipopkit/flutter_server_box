#!/usr/bin/env bash
# Fetch and verify every dependency needed by build-fdroid.sh before F-Droid
# disables network access for the build phase.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=android-build-env.sh
source "$REPO_ROOT/scripts/release/android-build-env.sh"

[ ! -e "$GRADLE_USER_HOME" ] || {
  echo "prepared Gradle cache already exists: $GRADLE_USER_HOME" >&2
  echo "run preparation from a clean checkout or choose a new FDROID_CACHE_DIR" >&2
  exit 1
}
mkdir -p "$GRADLE_USER_HOME"

flutter pub get --enforce-lockfile

# The native-assets hook invokes rustup in crates/sbm_ffi. Install the exact
# toolchain and every target declared there explicitly while networking is
# available; do not depend on an incidental rustup proxy command to do it.
rust_toolchain_file=crates/sbm_ffi/rust-toolchain.toml
rust_toolchain="$(sed -n -E \
  's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
  "$rust_toolchain_file")"
[ -n "$rust_toolchain" ] || { echo "Rust toolchain is not pinned" >&2; exit 1; }
mapfile -t rust_targets < <(sed -n -E \
  's/^[[:space:]]*"([^"]+)",?[[:space:]]*$/\1/p' \
  "$rust_toolchain_file")
[ "${#rust_targets[@]}" -gt 0 ] || { echo "Rust targets are not pinned" >&2; exit 1; }
rustup toolchain install "$rust_toolchain" --profile minimal
rustup target add --toolchain "$rust_toolchain" "${rust_targets[@]}"
rustup run "$rust_toolchain" cargo fetch \
  --locked \
  --manifest-path crates/sbm_ffi/Cargo.toml
scripts/release/patch-jni-build-id.sh
scripts/build-proot-android.sh

# Only a complete release task graph resolves plugin compile/runtime artifacts;
# `dependencies` and `--config-only` missed artifacts that CI then requested
# from the blocked network. Build once to seed the isolated Gradle cache, then
# remove every compiled output so the offline phase still rebuilds from source.
flutter build apk --release --split-per-abi --no-pub
flutter clean
