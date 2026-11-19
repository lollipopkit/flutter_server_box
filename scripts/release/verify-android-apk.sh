#!/usr/bin/env bash
# Verify an APK this fork built can be installed on the Fujitsu Arrows U 801FJ
# (Android 9, API 28) and, on arm64, that it carries the Linux userland.
#
# Every check here is one that an install refusal or a silently missing feature
# would otherwise hide: an APK whose minSdkVersion is above the device's API
# level is refused by the package manager before anything else, an unsigned one
# cannot be installed at all, and an APK without libproot.so installs and runs
# with the terminal's Linux tab simply absent.
#
# Not the F-Droid reproducibility check (see android-reproducible.yml): this says
# "this file is the right shape for this device", not "this file can be rebuilt
# byte for byte".
#
# Usage: scripts/release/verify-android-apk.sh <apk> <abi|all>
#   abi  arm64-v8a | armeabi-v7a -- the split APK for that ABI
#   all  a fat APK: every ABI, signature and minSdkVersion checked, proot only
#        required where the hook builds it (arm64-v8a)
#
# Environment: ANDROID_HOME (the runner's SDK), APKSIGNER (set by
# .github/actions/setup-android-sdk), AAPT2 to override the build-tools lookup.

set -euo pipefail

APK="${1:?usage: $0 <apk> <abi|all>}"
ABI="${2:?usage: $0 <apk> <abi|all>}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Android 9 is API 28, Android 10 is API 29. Nothing here claims support below
# that; the floor the APK declares is what has to be at or under it.
MAX_API=28

# `::error::` rather than plain stderr: it becomes the annotation the run's
# summary shows, which is the only place a failure is visible without opening
# the log.
fail() { printf '::error::%s\n' "$*" >&2; exit 1; }

[ -s "$APK" ] || fail "the APK is missing or empty: $APK"

build_tools="$(tr -d '[:space:]' < "$REPO_ROOT/android/build-tools-version.txt")"
sdk="${ANDROID_HOME:?ANDROID_HOME is not set}"
aapt2="${AAPT2:-$sdk/build-tools/$build_tools/aapt2}"
apksigner="${APKSIGNER:-$sdk/build-tools/$build_tools/apksigner}"

badging="$(mktemp)"
listing="$(mktemp)"
trap 'rm -f -- "$badging" "$listing"' EXIT

# `unzip -l` into a file rather than through a pipe: a `grep -q` downstream
# closes the pipe, unzip dies of SIGPIPE, and `set -o pipefail` turns that into
# a failed check on an APK that is fine.
"$aapt2" dump badging "$APK" > "$badging" ||
  fail "aapt2 could not read $APK"
unzip -l "$APK" > "$listing"

package_line="$(grep -m1 '^package:' "$badging" || true)"
# aapt2 writes `minSdkVersion:'24'`, not `sdkVersion:'24'`; matching the short
# form finds nothing and a `set -e` step dies with no message at all.
min_sdk="$(sed -n -E "s/^minSdkVersion:'([0-9]+)'.*/\1/p" "$badging" | head -n 1)"
target_sdk="$(sed -n -E "s/^targetSdkVersion:'([0-9]+)'.*/\1/p" "$badging" | head -n 1)"
native_line="$(grep -m1 '^native-code:' "$badging" || true)"

printf '%s\n' "${package_line:-<no package line>}"
printf 'minSdkVersion:    %s\n' "${min_sdk:-<none>}"
printf 'targetSdkVersion: %s\n' "${target_sdk:-<none>}"
printf '%s\n' "${native_line:-<no native code>}"

[ -n "$package_line" ] || fail "no package line in aapt2's output"
[ -n "$min_sdk" ] || fail "the APK declares no minSdkVersion"
[ -n "$target_sdk" ] || fail "the APK declares no targetSdkVersion"
[ -n "$native_line" ] || fail "the APK declares no native code"

[ "$min_sdk" -le "$MAX_API" ] ||
  fail "minSdkVersion is $min_sdk, above $MAX_API: the 801FJ runs Android 9 (API 28)"

case "$ABI" in
  arm64-v8a | armeabi-v7a)
    grep -q "'$ABI'" <<< "$native_line" ||
      fail "the APK carries no $ABI code: $native_line"
    grep -q "lib/$ABI/libflutter.so" "$listing" ||
      fail "no libflutter.so for $ABI"
    ;;
  all)
    for abi in arm64-v8a armeabi-v7a; do
      grep -q "lib/$abi/libflutter.so" "$listing" ||
        fail "the fat APK carries no $abi code"
    done
    ;;
  *) fail "unknown ABI '$ABI' (expected arm64-v8a, armeabi-v7a or all)" ;;
esac

# An unsigned APK is refused by the package manager with no explanation.
"$apksigner" verify --verbose --print-certs "$APK" | sed -n '1,4p'

# proot and its loader are built for aarch64 only
# (packages/fl_tty/scripts/build-proot-android.sh pins aarch64-linux-android).
# Saying so is what keeps the release notes from promising a Linux userland on
# armeabi-v7a.
if grep -q 'lib/arm64-v8a/libproot.so' "$listing"; then
  grep -q 'lib/arm64-v8a/libproot-loader.so' "$listing" ||
    fail "proot is in the APK but its loader is not; entering the rootfs would be refused"
  echo "proot: present"
elif [ "$ABI" = 'arm64-v8a' ]; then
  fail "no libproot.so: the Linux userland would be missing from the arm64 APK"
elif [ "$ABI" = 'all' ]; then
  fail "the fat APK carries no libproot.so for arm64-v8a"
else
  echo '::notice::armeabi-v7a has no proot by design; Linux distros need the arm64 APK'
fi

sha256sum "$APK" | tee "$APK.sha256"
du -h "$APK" | cut -f1 | sed 's/^/size: /'
echo "verified: $APK"
