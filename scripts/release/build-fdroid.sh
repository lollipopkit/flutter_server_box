#!/usr/bin/env bash
# Build the unsigned APK F-Droid compares with the upstream release.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

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

if [ "${FDROID_OFFLINE:-false}" = true ]; then
  export CARGO_NET_OFFLINE=true
  # Flutter does not expose Gradle's --offline switch. Route any JVM download
  # attempt to a closed local port instead, so a cache miss fails in CI just
  # as it does in F-Droid's network-isolated build phase.
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

rm -rf build/app/outputs/apk/release build/app/outputs/flutter-apk
flutter build apk \
  --no-pub \
  --release \
  --split-per-abi \
  "${target_args[@]}"

mapfile -t apks < <(find build/app/outputs/apk/release -maxdepth 1 \
  -type f -name '*-release-unsigned.apk' -print | sort)
[ "${#apks[@]}" -gt 0 ] || {
  echo "no unsigned release APK was produced" >&2
  find build/app/outputs/apk/release -maxdepth 1 -type f -print >&2 || true
  exit 1
}

for apk in "${apks[@]}"; do
  sha256sum "$apk"
done
