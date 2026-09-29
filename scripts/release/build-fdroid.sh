#!/usr/bin/env bash
# Build the unsigned APK F-Droid compares with the upstream release.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source-path=SCRIPTDIR
# shellcheck source=android-build-env.sh
source "$REPO_ROOT/scripts/release/android-build-env.sh"

offline_init_script=""
offline_cargo_config=""
cleanup() {
  if [ -n "$offline_init_script" ]; then
    rm -f -- "$offline_init_script"
  fi
  if [ -n "$offline_cargo_config" ]; then
    rm -f -- "$offline_cargo_config"
    rmdir -- "$(dirname "$offline_cargo_config")" 2>/dev/null || true
  fi
}
trap cleanup EXIT

variant="${1:-all}"
case "$variant" in
  all)
    target_args=()
    expected_apk_names=(
      app-arm64-v8a-release-unsigned.apk
      app-armeabi-v7a-release-unsigned.apk
      app-x86_64-release-unsigned.apk
    )
    ;;
  arm64)
    target_args=(--target-platform=android-arm64)
    expected_apk_names=(app-arm64-v8a-release-unsigned.apk)
    ;;
  arm)
    target_args=(--target-platform=android-arm)
    expected_apk_names=(app-armeabi-v7a-release-unsigned.apk)
    ;;
  amd64)
    target_args=(--target-platform=android-x64)
    expected_apk_names=(app-x86_64-release-unsigned.apk)
    ;;
  *) echo "usage: $0 [all|arm64|arm|amd64]" >&2; exit 2 ;;
esac

if [ "${FDROID_OFFLINE:-false}" = true ]; then
  # The hook runs cargo with hooks_runner's environment allowlist, so
  # CARGO_NET_OFFLINE would never reach it. Cargo does read config from its
  # working directory, which for the hook is the package root.
  offline_cargo_config="$REPO_ROOT/.cargo/config.toml"
  [ ! -e "$offline_cargo_config" ] || {
    echo "Cargo config already exists: $offline_cargo_config" >&2
    offline_cargo_config=""
    exit 1
  }
  mkdir -p "$(dirname "$offline_cargo_config")"
  printf '[net]\noffline = true\n' > "$offline_cargo_config"
  # Flutter does not expose Gradle's --offline switch. Install a temporary init
  # script that sets the equivalent StartParameter before dependencies are
  # resolved. Keep the dead proxy as a second guard against JVM networking.
  mkdir -p "$GRADLE_USER_HOME/init.d"
  offline_init_script="$GRADLE_USER_HOME/init.d/fdroid-offline.gradle"
  [ ! -e "$offline_init_script" ] || {
    echo "offline Gradle init script already exists: $offline_init_script" >&2
    offline_init_script=""
    exit 1
  }
  cp "$REPO_ROOT/scripts/release/gradle-offline.init.gradle" "$offline_init_script"
  export GRADLE_OPTS="${GRADLE_OPTS:-} -Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=9 -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=9"
  export PROOT_OFFLINE=true
  # rustup in the hook cannot be pointed at a dead server either (same
  # allowlist), and it installs a missing toolchain or target on its own. Fail
  # here instead if the preparation step missed one.
  rustup toolchain list | grep -q "^$rust_toolchain-" || {
    echo "Rust $rust_toolchain is not installed; run prepare-fdroid.sh" >&2
    exit 1
  }
  installed_targets="$(rustup target list --installed --toolchain "$rust_toolchain")"
  for target in "${rust_targets[@]}"; do
    grep -qxF -- "$target" <<< "$installed_targets" || {
      echo "Rust target $target is not installed; run prepare-fdroid.sh" >&2
      exit 1
    }
  done
  flutter pub get --offline --enforce-lockfile
else
  flutter pub get --enforce-lockfile
fi
scripts/release/patch-jni-build-id.sh
if [ "$variant" = all ] || [ "$variant" = arm64 ]; then
  scripts/build-proot-android.sh
fi

# Refresh Flutter's Android metadata after `pub get`, then remove dev-only
# plugins before Gradle configures the release. The final assemble target
# regenerates its registrant from this pruned input even with `--no-pub`.
flutter build apk --no-pub --release --config-only
dart --packages="$REPO_ROOT/scripts/release/empty-package-config.json" \
  "$REPO_ROOT/scripts/release/prune_android_dev_plugins.dart"
dart --packages="$REPO_ROOT/scripts/release/empty-package-config.json" \
  "$REPO_ROOT/scripts/release/map_plugin_registrant_package.dart"

rm -rf build/app/outputs/apk/release build/app/outputs/flutter-apk
flutter build apk \
  --no-pub \
  --release \
  --split-per-abi \
  "${target_args[@]}"

mapfile -t apks < <(find build/app/outputs/apk/release -maxdepth 1 \
  -type f -name '*-release-unsigned.apk' -print | sort)
actual_apk_names=()
for apk in "${apks[@]}"; do
  actual_apk_names+=("$(basename "$apk")")
done
if [ "${actual_apk_names[*]}" != "${expected_apk_names[*]}" ]; then
  echo "unexpected unsigned APK set" >&2
  printf 'expected: %s\n' "${expected_apk_names[*]}" >&2
  printf 'actual:   %s\n' "${actual_apk_names[*]}" >&2
  find build/app/outputs/apk/release -maxdepth 1 -type f -print >&2 || true
  exit 1
fi

for apk in "${apks[@]}"; do
  sha256sum "$apk"
done
