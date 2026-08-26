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

# Keep generated Dart sources under a stable virtual URI. Flutter otherwise
# embeds the checkout's absolute dart_plugin_registrant.dart path in libapp.so,
# which also changes private-symbol hashes when the path length changes.
FLUTTER_ANDROID_REPRO_ARGS=(
  "--android-project-arg=filesystem-roots=$REPO_ROOT"
  "--android-project-arg=filesystem-scheme=org-dartlang-root"
)

# Do not inherit an arbitrary host Gradle cache. Preparation fills this cache
# from an empty clean checkout, and the network-isolated build reuses exactly
# that prepared input. Keep proot beside it so `flutter clean` can discard all
# warm-up build outputs without discarding proot's authenticated source cache.
FDROID_CACHE_DIR="${FDROID_CACHE_DIR:-$REPO_ROOT/.fdroid-cache}"
export GRADLE_USER_HOME="${FDROID_GRADLE_USER_HOME:-$FDROID_CACHE_DIR/gradle}"
export PROOT_BUILD_DIR="${PROOT_BUILD_DIR:-$FDROID_CACHE_DIR/proot}"
