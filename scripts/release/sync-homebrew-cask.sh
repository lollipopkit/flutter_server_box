#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_NAME="${APP_NAME:-Server Box}"
CASK_NAME="${CASK_NAME:-serverbox}"
CASK_DISPLAY_NAME="${CASK_DISPLAY_NAME:-ServerBox}"
CASK_DESC="${CASK_DESC:-App for monitoring server status with SSH terminal, SFTP, Container management}"
APP_REPO_SLUG="${APP_REPO_SLUG:-lollipopkit/flutter_server_box}"
TAP_REPO_PATH="${TAP_REPO_PATH:-$HOME/proj/homebrew-taps}"
TAP_CASK_PATH="${TAP_CASK_PATH:-}"
EXPLICIT_TAP_CASK_PATH="${TAP_CASK_PATH:-}"
XCARCHIVE_PATH="${1:-${XCARCHIVE_PATH:-}}"

if [[ -n "$XCARCHIVE_PATH" ]]; then
  APP_PATH="${APP_PATH:-$XCARCHIVE_PATH/Products/Applications/${APP_NAME}.app}"
else
  APP_PATH="${APP_PATH:-}"
fi

if [[ -n "$APP_PATH" ]]; then
  INFO_PLIST="$APP_PATH/Contents/Info.plist"
else
  INFO_PLIST="${INFO_PLIST:-$REPO_ROOT/macos/Runner/Info.plist}"
fi

if [[ -f "$INFO_PLIST" ]]; then
  APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
  APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
else
  APP_VERSION=""
  APP_BUILD=""
fi

if [[ -n "$APP_VERSION" && "$APP_VERSION" != '$('* ]]; then
  DMG_BASENAME="${DMG_BASENAME:-ServerBox-${APP_VERSION}}"
fi

if [[ -z "${DMG_PATH:-}" ]]; then
  if [[ -z "${DMG_BASENAME:-}" ]]; then
    echo "DMG_PATH requires DMG_BASENAME when version is unavailable" >&2
    echo "Provide DMG_PATH directly, or provide XCARCHIVE_PATH/APP_PATH so DMG_BASENAME can be resolved." >&2
    exit 1
  fi
  DMG_PATH="$REPO_ROOT/build/artifacts/${DMG_BASENAME}.dmg"
fi

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found: $DMG_PATH" >&2
  echo "Run package-dmg-from-xcarchive.sh first or provide DMG_PATH." >&2
  exit 1
fi

if [[ -z "$APP_VERSION" || "$APP_VERSION" == '$('* ]]; then
  dmg_filename="$(basename "$DMG_PATH")"
  if [[ "$dmg_filename" =~ ^ServerBox-([0-9]+(\.[0-9]+){1,2})\.dmg$ ]]; then
    APP_VERSION="${BASH_REMATCH[1]}"
    APP_BUILD="${APP_BUILD:-}"
  elif [[ "$dmg_filename" =~ ^ServerBox-([0-9]+(\.[0-9]+){1,2})-([0-9]+)\.dmg$ ]]; then
    APP_VERSION="${BASH_REMATCH[1]}"
    APP_BUILD="${BASH_REMATCH[3]}"
  else
    echo "unable to determine version from $DMG_PATH" >&2
    echo "Provide XCARCHIVE_PATH, APP_PATH, or a DMG named ServerBox-<version>.dmg." >&2
    exit 1
  fi
fi

RELEASE_TAG="${RELEASE_TAG:-v${APP_VERSION}}"
DMG_BASENAME="${DMG_BASENAME:-ServerBox-${APP_VERSION}}"

if [[ -z "$TAP_CASK_PATH" && -n "$TAP_REPO_PATH" ]]; then
  TAP_CASK_PATH="$TAP_REPO_PATH/Casks/${CASK_NAME}.rb"
fi

if [[ -z "$TAP_CASK_PATH" ]]; then
  echo "TAP_REPO_PATH or TAP_CASK_PATH is required" >&2
  exit 1
fi

if [[ -z "$EXPLICIT_TAP_CASK_PATH" && -n "$TAP_REPO_PATH" && ! -d "$TAP_REPO_PATH" ]]; then
  echo "TAP_REPO_PATH does not exist: $TAP_REPO_PATH" >&2
  exit 1
fi

SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"

mkdir -p "$(dirname "$TAP_CASK_PATH")"
cat > "$TAP_CASK_PATH" <<CASK
cask "$CASK_NAME" do
  version "$APP_VERSION"
  sha256 "$SHA256"

  url "https://github.com/$APP_REPO_SLUG/releases/download/$RELEASE_TAG/${DMG_BASENAME}.dmg",
      verified: "github.com/$APP_REPO_SLUG/"
  name "$CASK_DISPLAY_NAME"
  desc "$CASK_DESC"
  homepage "https://github.com/$APP_REPO_SLUG"

  app "$APP_NAME.app"
end
CASK

echo "Generated tap cask: $TAP_CASK_PATH"
echo "Version: $APP_VERSION"
if [[ -n "$APP_BUILD" && "$APP_BUILD" != '$('* ]]; then
  echo "Build number: $APP_BUILD"
fi
echo "Release tag: $RELEASE_TAG"
echo "DMG: $DMG_PATH"
echo "SHA256: $SHA256"
