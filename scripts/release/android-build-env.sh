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

# Do not inherit an arbitrary host cache or put fetched dependencies inside the
# source tree. F-Droid scans after `prebuild`, so an in-tree cache would either
# fail the scanner or be deleted before the offline build can use it.
FDROID_CACHE_DIR="${FDROID_CACHE_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/server-box-fdroid-cache}"
export PUB_CACHE="${PUB_CACHE:-$FDROID_CACHE_DIR/pub}"
export GRADLE_USER_HOME="${FDROID_GRADLE_USER_HOME:-$FDROID_CACHE_DIR/gradle}"
export PROOT_BUILD_DIR="${PROOT_BUILD_DIR:-$FDROID_CACHE_DIR/proot}"
