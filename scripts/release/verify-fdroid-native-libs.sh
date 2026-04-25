#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APK_DIR="${APK_DIR:-$REPO_ROOT/build/app/outputs/flutter-apk}"
APP_NAME="${APP_NAME:-ServerBox}"

require_cmd() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "command not found: $name" >&2
    exit 1
  fi
}

require_cmd find
require_cmd readelf
require_cmd unzip

shopt -s nullglob

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

failures=()
apks=()
patterns=(
  "${APP_NAME}_*_arm64.apk"
  "${APP_NAME}_*_arm.apk"
  "${APP_NAME}_*_amd64.apk"
)

for pattern in "${patterns[@]}"; do
  matches=("$APK_DIR"/$pattern)
  if [[ ${#matches[@]} -ne 1 ]]; then
    echo "expected exactly 1 APK for pattern: $pattern" >&2
    echo "found ${#matches[@]} matches" >&2
    echo "APK_DIR: $APK_DIR" >&2
    if [[ ${#matches[@]} -gt 0 ]]; then
      printf '  %s\n' "${matches[@]}" >&2
    else
      ls -la "$APK_DIR" || true
    fi
    exit 1
  fi
  apks+=("${matches[0]}")
done

for apk in "${apks[@]}"; do
  apk_name="$(basename "$apk")"
  extract_dir="$tmp_dir/$apk_name"
  mkdir -p "$extract_dir"
  unzip -qq "$apk" "lib/*/*.so" -d "$extract_dir"

  while IFS= read -r so_file; do
    if readelf -n "$so_file" | grep -q 'Build ID'; then
      failures+=("$apk_name:${so_file#$extract_dir/}")
    fi
  done < <(find "$extract_dir" -type f -name '*.so' | sort)
done

if [[ ${#failures[@]} -ne 0 ]]; then
  echo 'native libraries still contain ELF build-id notes:' >&2
  printf '  %s\n' "${failures[@]}" >&2
  exit 1
fi

echo 'F-Droid native library verification passed.'
