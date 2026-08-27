#!/usr/bin/env bash

set -euo pipefail

left="${1:?first APK directory is required}"
right="${2:?second APK directory is required}"
report="${3:-apk-diffoscope.txt}"

mapfile -t left_names < <(find "$left" -maxdepth 1 -type f -name '*.apk' \
  -printf '%f\n' | sort)
mapfile -t right_names < <(find "$right" -maxdepth 1 -type f -name '*.apk' \
  -printf '%f\n' | sort)

[ "${#left_names[@]}" -gt 0 ] || { echo "no APKs in $left" >&2; exit 1; }
if [ "${left_names[*]}" != "${right_names[*]}" ]; then
  echo "APK sets differ" >&2
  printf 'first:  %s\n' "${left_names[*]}" >&2
  printf 'second: %s\n' "${right_names[*]}" >&2
  exit 1
fi

failed=0
for name in "${left_names[@]}"; do
  first="$left/$name"
  second="$right/$name"
  if cmp --silent "$first" "$second"; then
    sha256sum "$first"
    continue
  fi

  echo "$name is not reproducible" >&2
  sha256sum "$first" "$second" >&2
  if command -v diffoscope >/dev/null 2>&1; then
    diffoscope --text "$report" "$first" "$second" || true
    echo "diffoscope report: $report" >&2
  fi
  failed=1
done

exit "$failed"
