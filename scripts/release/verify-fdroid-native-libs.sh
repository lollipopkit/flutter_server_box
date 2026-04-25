#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APK_DIR="${APK_DIR:-$REPO_ROOT/build/app/outputs/flutter-apk}"
APP_NAME="${APP_NAME:-ServerBox}"
KEY_PROPERTIES="${KEY_PROPERTIES:-$REPO_ROOT/android/key.properties}"

require_cmd() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "command not found: $name" >&2
    exit 1
  fi
}

android_sdk_roots() {
  local candidates=(
    "${ANDROID_HOME:-}"
    "${ANDROID_SDK_ROOT:-}"
    "$HOME/Library/Android/sdk"
    "$HOME/Android/Sdk"
    "/opt/android-sdk"
    "/usr/local/lib/android/sdk"
  )
  local roots=''
  local candidate

  for candidate in "${candidates[@]}"; do
    if [[ -z "$candidate" || ! -d "$candidate" ]]; then
      continue
    fi

    if printf '%s' "$roots" | grep -Fxq "$candidate"; then
      continue
    fi
    roots+="$candidate"$'\n'
  done

  printf '%s' "$roots"
}

android_tool_version() {
  local path="$1"
  local version='0'
  case "$path" in
    */build-tools/*)
      version="${path#*/build-tools/}"
      version="${version%%/*}"
      ;;
    */ndk/*)
      version="${path#*/ndk/}"
      version="${version%%/*}"
      ;;
  esac

  printf '%s\n' "$version"
}

version_sort_key() {
  local version="$1"
  local part
  local padded
  local key=''

  IFS='.' read -ra parts <<< "$version"
  for part in "${parts[@]}"; do
    if [[ "$part" =~ ^[0-9]+$ ]]; then
      printf -v padded '%010d' "$part"
    else
      padded="$part"
    fi
    key+="$padded."
  done

  printf '%s\n' "$key"
}

select_latest_android_path() {
  local path
  local version
  local key

  while IFS= read -r path; do
    if [[ -z "$path" ]]; then
      continue
    fi
    version="$(android_tool_version "$path")"
    key="$(version_sort_key "$version")"
    printf '%s\t%s\n' "$key" "$path"
  done |
    sort |
    tail -n 1 |
    while IFS=$'\t' read -r _ path; do
      printf '%s\n' "$path"
    done
}

find_latest_android_tool() {
  local name="$1"
  local sdk_root
  local matches=()
  local path

  while IFS= read -r sdk_root; do
    if [[ -z "$sdk_root" || ! -d "$sdk_root/build-tools" ]]; then
      continue
    fi
    while IFS= read -r path; do
      matches+=("$path")
    done < <(find "$sdk_root/build-tools" -type f -name "$name")
  done < <(android_sdk_roots)

  if [[ ${#matches[@]} -eq 0 ]]; then
    return 1
  fi

  printf '%s\n' "${matches[@]}" | select_latest_android_path
}

find_llvm_objcopy() {
  local sdk_root
  local matches=()
  local path

  while IFS= read -r sdk_root; do
    if [[ -z "$sdk_root" || ! -d "$sdk_root/ndk" ]]; then
      continue
    fi
    while IFS= read -r path; do
      matches+=("$path")
    done < <(find "$sdk_root/ndk" -type f -path '*/toolchains/llvm/prebuilt/*/bin/llvm-objcopy')
  done < <(android_sdk_roots)

  if [[ ${#matches[@]} -ne 0 ]]; then
    printf '%s\n' "${matches[@]}" | select_latest_android_path
    return
  fi

  command -v llvm-objcopy || command -v objcopy
}

find_readelf() {
  local sdk_root
  local matches=()
  local path

  while IFS= read -r sdk_root; do
    if [[ -z "$sdk_root" || ! -d "$sdk_root/ndk" ]]; then
      continue
    fi
    while IFS= read -r path; do
      matches+=("$path")
    done < <(find "$sdk_root/ndk" -type f -path '*/toolchains/llvm/prebuilt/*/bin/llvm-readelf')
  done < <(android_sdk_roots)

  if [[ ${#matches[@]} -ne 0 ]]; then
    printf '%s\n' "${matches[@]}" | select_latest_android_path
    return
  fi

  command -v readelf || command -v llvm-readelf
}

property_value() {
  local name="$1"
  grep -E "^[[:space:]]*${name}[[:space:]]*=" "$KEY_PROPERTIES" |
    tail -n 1 |
    sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//' || true
}

has_build_id() {
  local so_file="$1"
  "$READELF" -n "$so_file" 2>/dev/null | grep -q 'Build ID'
}

require_cmd find
require_cmd grep
require_cmd sed
require_cmd sort
require_cmd unzip
require_cmd zip

OBJCOPY="${OBJCOPY:-}"
READELF="${READELF:-}"
APKSIGNER="${APKSIGNER:-}"
ZIPALIGN="${ZIPALIGN:-}"

if [[ -z "$OBJCOPY" ]]; then
  OBJCOPY="$(find_llvm_objcopy || true)"
fi
if [[ -z "$READELF" ]]; then
  READELF="$(find_readelf || true)"
fi
if [[ -z "$APKSIGNER" ]]; then
  APKSIGNER="$(find_latest_android_tool apksigner || true)"
fi
if [[ -z "$ZIPALIGN" ]]; then
  ZIPALIGN="$(find_latest_android_tool zipalign || true)"
fi

if [[ -z "$OBJCOPY" || ! -x "$OBJCOPY" ]]; then
  echo 'llvm-objcopy or objcopy is required to remove ELF build-id notes' >&2
  exit 1
fi

if [[ -z "$READELF" || ! -x "$READELF" ]]; then
  echo 'readelf or llvm-readelf is required to inspect ELF build-id notes' >&2
  exit 1
fi

if [[ -z "$APKSIGNER" || ! -x "$APKSIGNER" ]]; then
  echo 'Android build-tools apksigner is required to re-sign patched APKs' >&2
  exit 1
fi

if [[ -z "$ZIPALIGN" || ! -x "$ZIPALIGN" ]]; then
  echo 'Android build-tools zipalign is required before re-signing patched APKs' >&2
  exit 1
fi

if [[ ! -f "$KEY_PROPERTIES" ]]; then
  echo "key.properties not found: $KEY_PROPERTIES" >&2
  exit 1
fi

store_file="$(property_value storeFile)"
store_password="$(property_value storePassword)"
key_alias="$(property_value keyAlias)"
key_password="$(property_value keyPassword)"

if [[ -z "$store_file" || -z "$store_password" || -z "$key_alias" || -z "$key_password" ]]; then
  echo "storeFile, storePassword, keyAlias, and keyPassword are required in $KEY_PROPERTIES" >&2
  exit 1
fi

if [[ "$store_file" != /* ]]; then
  store_file="$REPO_ROOT/android/app/$store_file"
fi

if [[ ! -f "$store_file" ]]; then
  echo "signing store file not found: $store_file" >&2
  exit 1
fi

shopt -s nullglob

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

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
  patched_files=()

  while IFS= read -r so_file; do
    if has_build_id "$so_file"; then
      rel_path="${so_file#"$extract_dir"/}"
      tmp_so="$so_file.tmp"
      "$OBJCOPY" --remove-section=.note.gnu.build-id "$so_file" "$tmp_so"
      mv "$tmp_so" "$so_file"
      if has_build_id "$so_file"; then
        echo "failed to remove ELF build-id note: $apk_name:$rel_path" >&2
        exit 1
      fi
      patched_files+=("$rel_path")
    fi
  done < <(find "$extract_dir" -type f -name '*.so' | sort)

  if [[ ${#patched_files[@]} -eq 0 ]]; then
    continue
  fi

  echo "Removing ELF build-id notes from $apk_name"
  (
    cd "$extract_dir"
    zip -q -0 "$apk" "${patched_files[@]}"
  )

  aligned_apk="$tmp_dir/$apk_name.aligned.apk"
  "$ZIPALIGN" -f -p 4 "$apk" "$aligned_apk"
  mv "$aligned_apk" "$apk"

  "$APKSIGNER" sign \
    --ks "$store_file" \
    --ks-key-alias "$key_alias" \
    --ks-pass "pass:$store_password" \
    --key-pass "pass:$key_password" \
    "$apk"
done

for apk in "${apks[@]}"; do
  apk_name="$(basename "$apk")"
  verify_dir="$tmp_dir/verify-$apk_name"
  mkdir -p "$verify_dir"
  unzip -qq "$apk" "lib/*/*.so" -d "$verify_dir"

  while IFS= read -r so_file; do
    if has_build_id "$so_file"; then
      rel_path="${so_file#"$verify_dir"/}"
      echo "native library still contains ELF build-id note: $apk_name:$rel_path" >&2
      exit 1
    fi
  done < <(find "$verify_dir" -type f -name '*.so' | sort)

  "$APKSIGNER" verify "$apk"
done

echo 'F-Droid native library verification passed.'
