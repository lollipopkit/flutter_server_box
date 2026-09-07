#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_NAME="${APP_NAME:-Server Box}"
APP_ASSET_NAME="${APP_ASSET_NAME:-ServerBox}"
CASK_NAME="${CASK_NAME:-server-box}"
CASK_SUBDIR="${CASK_SUBDIR:-${CASK_NAME:0:1}}"
CASK_DISPLAY_NAME="${CASK_DISPLAY_NAME:-ServerBox}"
CASK_DESC="${CASK_DESC:-App for monitoring server status with SSH terminal, SFTP, Container management}"
APP_REPO_SLUG="${APP_REPO_SLUG:-lollipopkit/flutter_server_box}"
TAP_REPO_PATH="${TAP_REPO_PATH:-$HOME/proj/homebrew-cask}"
TAP_CASK_PATH="${TAP_CASK_PATH:-}"
EXPLICIT_TAP_CASK_PATH="${TAP_CASK_PATH:-}"
XCARCHIVE_PATH="${1:-${XCARCHIVE_PATH:-}}"

# The cask serves both architectures from one file — `arch arm:`/`intel:` and
# an interpolated url — so it needs both DMGs, not the one that happens to have
# been built last. A cask naming a download that was never published installs
# nothing on half the machines that use it.
DMG_ARM64_PATH="${DMG_ARM64_PATH:-}"
DMG_AMD64_PATH="${DMG_AMD64_PATH:-}"

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

# The checked-in Info.plist carries `$(FLUTTER_BUILD_NAME)` rather than a
# version, so a value that still looks like a build setting is not one.
if [[ -z "$APP_VERSION" || "$APP_VERSION" == '$('* ]]; then
  APP_VERSION=""
  for candidate in "$DMG_ARM64_PATH" "$DMG_AMD64_PATH"; do
    [[ -n "$candidate" ]] || continue
    dmg_filename="$(basename "$candidate")"
    if [[ "$dmg_filename" =~ ^${APP_ASSET_NAME}-([0-9]+(\.[0-9]+){1,2})-(arm64|amd64)\.dmg$ ]]; then
      APP_VERSION="${BASH_REMATCH[1]}"
      break
    fi
  done
fi

if [[ -z "$APP_VERSION" ]]; then
  echo "unable to determine the app version" >&2
  echo "Provide XCARCHIVE_PATH or APP_PATH, or DMGs named ${APP_ASSET_NAME}-<version>-<arm64|amd64>.dmg." >&2
  exit 1
fi

RELEASE_TAG="${RELEASE_TAG:-v${APP_VERSION}}"
DMG_BASENAME="${DMG_BASENAME:-${APP_ASSET_NAME}-${APP_VERSION}}"
DMG_ARM64_PATH="${DMG_ARM64_PATH:-$REPO_ROOT/build/artifacts/${DMG_BASENAME}-arm64.dmg}"
DMG_AMD64_PATH="${DMG_AMD64_PATH:-$REPO_ROOT/build/artifacts/${DMG_BASENAME}-amd64.dmg}"

for dmg in "$DMG_ARM64_PATH" "$DMG_AMD64_PATH"; do
  if [[ ! -f "$dmg" ]]; then
    echo "DMG not found: $dmg" >&2
    echo "Run release-macos-dmg.sh for both architectures, or provide DMG_ARM64_PATH and DMG_AMD64_PATH." >&2
    exit 1
  fi
done

if [[ -z "$TAP_CASK_PATH" && -n "$TAP_REPO_PATH" ]]; then
  TAP_CASK_PATH="$TAP_REPO_PATH/Casks/${CASK_SUBDIR}/${CASK_NAME}.rb"
fi

if [[ -z "$TAP_CASK_PATH" ]]; then
  echo "TAP_REPO_PATH or TAP_CASK_PATH is required" >&2
  exit 1
fi

if [[ -z "$EXPLICIT_TAP_CASK_PATH" && -n "$TAP_REPO_PATH" && ! -d "$TAP_REPO_PATH" ]]; then
  echo "TAP_REPO_PATH does not exist: $TAP_REPO_PATH" >&2
  exit 1
fi

SHA256_ARM64="$(shasum -a 256 "$DMG_ARM64_PATH" | awk '{print $1}')"
SHA256_AMD64="$(shasum -a 256 "$DMG_AMD64_PATH" | awk '{print $1}')"

# `#{version}` and `#{arch}` are Ruby, and reach the file as written: the
# heredoc expands the shell's `$`, and neither of those is one.
mkdir -p "$(dirname "$TAP_CASK_PATH")"
cat > "$TAP_CASK_PATH" <<CASK
cask "$CASK_NAME" do
  arch arm: "arm64", intel: "amd64"

  version "$APP_VERSION"
  sha256 arm:   "$SHA256_ARM64",
         intel: "$SHA256_AMD64"

  url "https://github.com/$APP_REPO_SLUG/releases/download/$RELEASE_TAG/${APP_ASSET_NAME}-#{version}-#{arch}.dmg",
      verified: "github.com/$APP_REPO_SLUG/"
  name "$CASK_DISPLAY_NAME"
  desc "$CASK_DESC"
  homepage "https://github.com/$APP_REPO_SLUG"

  # Matches MACOSX_DEPLOYMENT_TARGET in the Xcode project. Without it Homebrew
  # installs happily on an older macOS and the app then fails to launch with
  # a dyld error, which reads as a broken build rather than as a machine that
  # is too old.
  depends_on macos: ">= :ventura"

  app "$APP_NAME.app"
end
CASK

echo "Generated tap cask: $TAP_CASK_PATH"
echo "Version: $APP_VERSION"
if [[ -n "$APP_BUILD" && "$APP_BUILD" != '$('* ]]; then
  echo "Build number: $APP_BUILD"
fi
echo "Release tag: $RELEASE_TAG"
echo "DMG (arm64): $DMG_ARM64_PATH"
echo "SHA256 (arm64): $SHA256_ARM64"
echo "DMG (amd64): $DMG_AMD64_PATH"
echo "SHA256 (amd64): $SHA256_AMD64"
