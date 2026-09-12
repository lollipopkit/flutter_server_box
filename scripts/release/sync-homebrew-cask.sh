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
# What the leftovers under ~/Library are keyed by. `PRODUCT_BUNDLE_IDENTIFIER`
# in macos/Runner.xcodeproj.
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.lollipopkit.toolbox}"
TAP_REPO_PATH="${TAP_REPO_PATH:-$HOME/proj/homebrew-cask}"
TAP_CASK_PATH="${TAP_CASK_PATH:-}"
EXPLICIT_TAP_CASK_PATH="${TAP_CASK_PATH:-}"
XCARCHIVE_PATH="${1:-${XCARCHIVE_PATH:-}}"

# One cask serves both architectures through `arch arm:`/`intel:` and an
# interpolated URL. Generate it only when both DMGs are available; otherwise,
# one architecture would receive a URL for an unpublished asset.
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

# The checked-in Info.plist contains the unresolved `$(FLUTTER_BUILD_NAME)`
# setting rather than a version. Ignore that placeholder and infer the version
# from a DMG filename instead.
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

# Neither path was given, so the loop above had nothing to read — and the
# defaults below cannot supply one, because the filename they build contains
# the version being looked for. So look in the directory those defaults point
# at.
#
# This is the whole standalone case. `release-macos-dmg.sh` passes both paths,
# and running this script by hand is what its own comments describe for a
# partial retry, which until now could only fail.
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$REPO_ROOT/build/artifacts}"
if [[ -z "$APP_VERSION" && -z "$DMG_ARM64_PATH" && -z "$DMG_AMD64_PATH" ]]; then
  found_versions=()
  # arm64 alone: the amd64 half is checked for existence further down, and
  # reporting a missing one there gives the better message.
  for candidate in "$ARTIFACTS_DIR/${APP_ASSET_NAME}-"*"-arm64.dmg"; do
    [[ -f "$candidate" ]] || continue
    dmg_filename="$(basename "$candidate")"
    if [[ "$dmg_filename" =~ ^${APP_ASSET_NAME}-([0-9]+(\.[0-9]+){1,2})-arm64\.dmg$ ]]; then
      found_versions+=("${BASH_REMATCH[1]}")
    fi
  done

  # Refused rather than resolved, because both ways of resolving it are wrong
  # in a way nothing downstream would notice: the cask that comes out is
  # internally consistent whichever version is picked, so publishing last
  # month's build looks exactly like publishing this one.
  if (( ${#found_versions[@]} == 1 )); then
    APP_VERSION="${found_versions[0]}"
  elif (( ${#found_versions[@]} > 1 )); then
    echo "more than one version is built in $ARTIFACTS_DIR:" >&2
    printf '  %s\n' "${found_versions[@]}" >&2
    echo "Name one with DMG_ARM64_PATH and DMG_AMD64_PATH." >&2
    exit 1
  fi
fi

if [[ -z "$APP_VERSION" ]]; then
  echo "unable to determine the app version" >&2
  echo "Provide XCARCHIVE_PATH or APP_PATH, or DMGs named ${APP_ASSET_NAME}-<version>-<arm64|amd64>.dmg." >&2
  exit 1
fi

RELEASE_TAG="${RELEASE_TAG:-v${APP_VERSION}}"
DMG_BASENAME="${DMG_BASENAME:-${APP_ASSET_NAME}-${APP_VERSION}}"
DMG_ARM64_PATH="${DMG_ARM64_PATH:-$ARTIFACTS_DIR/${DMG_BASENAME}-arm64.dmg}"
DMG_AMD64_PATH="${DMG_AMD64_PATH:-$ARTIFACTS_DIR/${DMG_BASENAME}-amd64.dmg}"

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

# `brew bump-cask-pr` rewrites `version` and `sha256` and expects everything
# else to follow from them, which is also how a reviewer reads the URL. A tag
# written out in full would have to be hand-edited every release, so it is
# interpolated whenever it is exactly `v<version>` — which it is unless a
# caller overrode `RELEASE_TAG`.
if [[ "$RELEASE_TAG" == "v$APP_VERSION" ]]; then
  URL_TAG='v#{version}'
else
  URL_TAG="$RELEASE_TAG"
fi

# `#{version}` and `#{arch}` are Ruby interpolations. They remain literal here
# because the shell expands `$`, not `#`.
#
# What comes out of this heredoc is submitted to Homebrew/homebrew-cask
# verbatim, so it carries no commentary: a cask is read by people maintaining
# thousands of them, and reasoning about this repository's Xcode settings is
# not theirs to carry. The reasoning lives here instead.
#
# - `depends_on macos: :ventura` matches `MACOSX_DEPLOYMENT_TARGET` in the
#   Xcode project. Without it Homebrew installs happily on an older macOS and
#   the app fails to launch with a dyld error, which reads as a broken build
#   rather than as a machine that is too old. The bare symbol already means
#   "or newer" — `Cask::DSL::DependsOn` calls `MacOSRequirement.parse` with
#   `comparator: ">="` — and spelling it `">= :ventura"` is the same
#   requirement written the way the `Homebrew/OSDependsOn` cop rejects.
# - The `zap` paths were checked against what a real run leaves behind. The
#   DMG build is **not** sandboxed (`macos/Runner/ReleaseDmg.entitlements`
#   sets `app-sandbox` false), so its data is under Application Support keyed
#   by the app's name, not in a container keyed by its bundle id — which is
#   what this cask used to name, and what a Homebrew install never creates.
#   The container stays for a user who had the App Store build first.
#   `HTTPStorages`, `Saved Application State` and `WebKit` were checked too
#   and are not created. The database encryption key cannot be listed at all:
#   it is a login keychain item and `zap` has no stanza for one.
mkdir -p "$(dirname "$TAP_CASK_PATH")"
cat > "$TAP_CASK_PATH" <<CASK
cask "$CASK_NAME" do
  arch arm: "arm64", intel: "amd64"

  version "$APP_VERSION"
  sha256 arm:   "$SHA256_ARM64",
         intel: "$SHA256_AMD64"

  url "https://github.com/$APP_REPO_SLUG/releases/download/$URL_TAG/${APP_ASSET_NAME}-#{version}-#{arch}.dmg",
      verified: "github.com/$APP_REPO_SLUG/"
  name "$CASK_DISPLAY_NAME"
  desc "$CASK_DESC"
  homepage "https://github.com/$APP_REPO_SLUG"

  depends_on macos: :ventura

  app "$APP_NAME.app"

  zap trash: [
    "~/Library/Application Support/$APP_ASSET_NAME",
    "~/Library/Caches/$APP_BUNDLE_ID",
    "~/Library/Containers/$APP_BUNDLE_ID",
    "~/Library/Preferences/$APP_BUNDLE_ID.plist",
  ]
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
