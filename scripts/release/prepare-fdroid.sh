#!/usr/bin/env bash
# Fetch every dependency build-fdroid.sh needs, so that
# `FDROID_OFFLINE=true build-fdroid.sh` can prove nothing is fetched during the
# build. Used by android-reproducible.yml only: it compiles (proot and one full
# release build to seed Gradle's cache), so it must not run in an F-Droid
# `prebuild`. F-Droid's recipe is in fdroid/README.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source-path=SCRIPTDIR
# shellcheck source=android-build-env.sh
source "$REPO_ROOT/scripts/release/android-build-env.sh"

variant="${1:-all}"
case "$variant" in
  all) target_args=() ;;
  arm64) target_args=(--target-platform=android-arm64) ;;
  arm) target_args=(--target-platform=android-arm) ;;
  amd64) target_args=(--target-platform=android-x64) ;;
  *) echo "usage: $0 [all|arm64|arm|amd64]" >&2; exit 2 ;;
esac

[ ! -e "$FDROID_CACHE_DIR" ] || {
  echo "prepared build cache already exists: $FDROID_CACHE_DIR" >&2
  echo "run preparation from a clean checkout or choose a new FDROID_CACHE_DIR" >&2
  exit 1
}
mkdir -p "$GRADLE_USER_HOME"

flutter pub get --enforce-lockfile

# Install the exact toolchain and every target declared for the hook while
# networking is available; do not depend on an incidental rustup proxy command
# to do it.
rustup toolchain install "$rust_toolchain" --profile minimal
rustup target add --toolchain "$rust_toolchain" "${rust_targets[@]}"
rustup run "$rust_toolchain" cargo fetch \
  --locked \
  --manifest-path crates/sbm_ffi/Cargo.toml
scripts/release/patch-jni-build-id.sh
if [ "$variant" = all ] || [ "$variant" = arm64 ]; then
  scripts/build-proot-android.sh
fi

# Refresh Flutter's Android metadata after `pub get`, then remove dev-only
# plugins before Gradle configures the release. The complete build below
# regenerates its registrant from this pruned input even with `--no-pub`.
flutter build apk --release --config-only
dart --packages="$REPO_ROOT/scripts/release/empty-package-config.json" \
  "$REPO_ROOT/scripts/release/prune_android_dev_plugins.dart"
dart --packages="$REPO_ROOT/scripts/release/empty-package-config.json" \
  "$REPO_ROOT/scripts/release/map_plugin_registrant_package.dart"

# Only a complete release task graph resolves plugin compile/runtime artifacts;
# `dependencies` and `--config-only` alone missed artifacts that CI then
# requested from the blocked network. Build once to seed the isolated Gradle
# cache, then remove every compiled output so the offline phase still rebuilds
# from source.
flutter build apk \
  --release \
  --split-per-abi \
  --no-pub \
  "${target_args[@]}"
flutter clean
