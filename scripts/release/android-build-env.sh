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
