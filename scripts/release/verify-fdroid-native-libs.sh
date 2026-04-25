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
apks=(
  "$APK_DIR"/"${APP_NAME}"_*_arm64.apk
  "$APK_DIR"/"${APP_NAME}"_*_arm.apk
  "$APK_DIR"/"${APP_NAME}"_*_amd64.apk
)

if [[ ${#apks[@]} -ne 3 ]]; then
  echo "expected 3 generated APKs, found ${#apks[@]}" >&2
  echo "APK_DIR: $APK_DIR" >&2
  ls -la "$APK_DIR" || true
  exit 1
fi

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
