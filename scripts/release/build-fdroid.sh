#!/usr/bin/env bash
# Build the unsigned APK F-Droid compares with the upstream release.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=android-build-env.sh
source "$REPO_ROOT/scripts/release/android-build-env.sh"

offline_init_script=""
cleanup() {
  if [ -n "$offline_init_script" ]; then
    rm -f -- "$offline_init_script"
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
  export CARGO_NET_OFFLINE=true
  # Flutter does not expose Gradle's --offline switch. Install a temporary init
  # script that sets the equivalent StartParameter before dependencies are
  # resolved. Keep the dead proxy as a second guard against JVM networking.
  mkdir -p "$GRADLE_USER_HOME/init.d"
  offline_init_script="$GRADLE_USER_HOME/init.d/fdroid-offline.gradle"
  [ ! -e "$offline_init_script" ] || {
    echo "offline Gradle init script already exists: $offline_init_script" >&2
    exit 1
  }
  cp "$REPO_ROOT/scripts/release/gradle-offline.init.gradle" "$offline_init_script"
  export GRADLE_OPTS="${GRADLE_OPTS:-} -Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=9 -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=9"
  export PROOT_OFFLINE=true
  # If the preparation step missed the pinned Rust toolchain, fail instead of
  # silently filling the gap from the network in this verification workflow.
  export RUSTUP_DIST_SERVER=http://127.0.0.1:9
  export RUSTUP_UPDATE_ROOT=http://127.0.0.1:9
  flutter pub get --offline --enforce-lockfile
else
  flutter pub get --enforce-lockfile
fi
scripts/release/patch-jni-build-id.sh
scripts/build-proot-android.sh

# Refresh Flutter's Android metadata after `pub get`, then remove dev-only
# plugins before Gradle configures the release. The final assemble target
# regenerates its registrant from this pruned input even with `--no-pub`.
flutter build apk --no-pub --release --config-only
dart --packages="$REPO_ROOT/scripts/release/empty-package-config.json" \
  "$REPO_ROOT/scripts/release/prune-android-dev-plugins.dart"
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
