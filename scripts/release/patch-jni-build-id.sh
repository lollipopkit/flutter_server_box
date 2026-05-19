#!/bin/bash
set -euo pipefail

require_cmd() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "command not found: $name" >&2
    exit 1
  fi
}

pub_cache_path() {
  if [[ -n "${PUB_CACHE:-}" ]]; then
    printf '%s\n' "$PUB_CACHE"
    return
  fi

  if command -v dart >/dev/null 2>&1; then
    dart pub cache path 2>/dev/null && return
  fi

  printf '%s\n' "$HOME/.pub-cache"
}

patch_file() {
  local cmake_file="$1"
  local tmp_file

  if grep -q -- '--build-id=none' "$cmake_file"; then
    echo "jni build-id patch already present: $cmake_file"
    return
  fi

  if ! grep -q 'target_link_options(jni PRIVATE' "$cmake_file"; then
    echo "jni linker options not found: $cmake_file" >&2
    return 1
  fi

  tmp_file="$(mktemp)"
  sed 's/target_link_options(jni PRIVATE "/target_link_options(jni PRIVATE "-Wl,--build-id=none" "/' "$cmake_file" > "$tmp_file"
  mv "$tmp_file" "$cmake_file"
  echo "patched jni build-id linker flag: $cmake_file"
}

require_cmd find
require_cmd grep
require_cmd mktemp
require_cmd sed

pub_cache="$(pub_cache_path)"
if [[ ! -d "$pub_cache" ]]; then
  echo "pub cache not found: $pub_cache" >&2
  exit 1
fi

patched=0
while IFS= read -r cmake_file; do
  patch_file "$cmake_file"
  patched=$((patched + 1))
done < <(find "$pub_cache" -path '*/jni-*/src/CMakeLists.txt' -type f | sort)

if [[ $patched -eq 0 ]]; then
  echo "jni CMakeLists.txt not found under pub cache: $pub_cache" >&2
  exit 1
fi

echo "jni build-id patch checked ${patched} file(s)."
