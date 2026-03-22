#!/bin/sh

set -eu

if [ "${ACTION:-}" != "install" ] && [ -z "${ARCHIVE_PATH:-}" ]; then
  exit 0
fi

APP_BUNDLE_PATH="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"

if [ ! -d "${APP_BUNDLE_PATH}" ]; then
  exit 0
fi

DSYM_ROOT="${DWARF_DSYM_FOLDER_PATH:-}"
if [ -n "${ARCHIVE_PATH:-}" ]; then
  DSYM_ROOT="${ARCHIVE_PATH}/dSYMs"
fi

if [ -z "${DSYM_ROOT}" ]; then
  exit 0
fi

mkdir -p "${DSYM_ROOT}"

uuid_list() {
  xcrun dwarfdump --uuid "$1" 2>/dev/null | awk '{ print $2 }' | sort
}

find "${APP_BUNDLE_PATH}" -type d -path '*/Frameworks/*.framework' -print0 | while IFS= read -r -d '' framework_path; do
  info_plist="${framework_path}/Info.plist"
  binary_name=''
  if [ -f "${info_plist}" ]; then
    binary_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${info_plist}" 2>/dev/null || true)
  fi
  if [ -z "${binary_name}" ]; then
    binary_name="$(basename "${framework_path}" .framework)"
  fi

  binary_path="${framework_path}/${binary_name}"
  if [ ! -f "${binary_path}" ]; then
    continue
  fi

  dsym_path="${DSYM_ROOT}/$(basename "${framework_path}").dSYM"
  dsym_binary_path="${dsym_path}/Contents/Resources/DWARF/${binary_name}"
  binary_uuids="$(uuid_list "${binary_path}")"

  if [ -n "${binary_uuids}" ] && [ -f "${dsym_binary_path}" ]; then
    dsym_uuids="$(uuid_list "${dsym_binary_path}")"
    if [ "${binary_uuids}" = "${dsym_uuids}" ]; then
      continue
    fi
  fi

  rm -rf "${dsym_path}"
  xcrun dsymutil "${binary_path}" -o "${dsym_path}"
done
