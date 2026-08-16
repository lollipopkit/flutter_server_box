#!/usr/bin/env bash

set -euo pipefail

: "${PUB_HOSTED_URL:?PUB_HOSTED_URL must be set}"

replace_host() {
  local lockfile="$1"
  local mirror="${PUB_HOSTED_URL%/}"

  if [[ "${RUNNER_OS:-}" == "macOS" ]]; then
    sed -i '' "s#https://pub.dev#${mirror}#g" "$lockfile"
  else
    sed -i "s#https://pub.dev#${mirror}#g" "$lockfile"
  fi
}

if (( $# > 0 )); then
  for lockfile in "$@"; do
    replace_host "$lockfile"
  done
else
  while IFS= read -r -d '' lockfile; do
    replace_host "$lockfile"
  done < <(git ls-files -z '*pubspec.lock')
fi
