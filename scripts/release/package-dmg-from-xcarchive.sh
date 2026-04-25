#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

APP_NAME="${APP_NAME:-Server Box}"
APP_ASSET_NAME="${APP_ASSET_NAME:-ServerBox}"
VOLUME_NAME="${VOLUME_NAME:-ServerBox}"
XCARCHIVE_PATH="${1:-${XCARCHIVE_PATH:-}}"
APP_PATH="${APP_PATH:-}"
ARTIFACTS_PATH="${ARTIFACTS_PATH:-$REPO_ROOT/build/artifacts}"
DMG_STAGING_PATH="${DMG_STAGING_PATH:-$REPO_ROOT/build/dmg-root}"
REQUIRE_SPCTL="${REQUIRE_SPCTL:-0}"

if [[ -z "$APP_PATH" && -z "$XCARCHIVE_PATH" ]]; then
  echo "APP_PATH or XCARCHIVE_PATH is required" >&2
  echo "Usage: APP_PATH=/abs/path/to/Server Box.app $0" >&2
  echo "   or: XCARCHIVE_PATH=/abs/path/to/Runner.xcarchive $0" >&2
  exit 1
fi

if [[ -z "$APP_PATH" ]]; then
  if [[ ! -d "$XCARCHIVE_PATH" ]]; then
    echo "xcarchive not found: $XCARCHIVE_PATH" >&2
    exit 1
  fi
  APP_PATH="$XCARCHIVE_PATH/Products/Applications/${APP_NAME}.app"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "app bundle not found: $APP_PATH" >&2
  exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Info.plist not found: $INFO_PLIST" >&2
  exit 1
fi

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
DMG_BASENAME="${DMG_BASENAME:-${APP_ASSET_NAME}-${APP_VERSION}}"
DMG_PATH="${DMG_PATH:-$ARTIFACTS_PATH/${DMG_BASENAME}.dmg}"

mkdir -p "$ARTIFACTS_PATH"
rm -rf "$DMG_STAGING_PATH"
mkdir -p "$DMG_STAGING_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

if ! spctl -a -t exec -vv "$APP_PATH"; then
  if [[ "$REQUIRE_SPCTL" == "1" ]]; then
    echo "spctl assessment failed for $APP_PATH" >&2
    exit 1
  fi

  echo "warning: spctl assessment failed for $APP_PATH; continuing because REQUIRE_SPCTL=0" >&2
fi

ditto "$APP_PATH" "$DMG_STAGING_PATH/${APP_NAME}.app"
ln -s /Applications "$DMG_STAGING_PATH/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_STAGING_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created DMG at $DMG_PATH"
echo "Version: $APP_VERSION ($APP_BUILD)"
