#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [[ -n "${SERVERBOX_RELEASE_ENV_FILE:-}" ]]; then
  ENV_FILE="$SERVERBOX_RELEASE_ENV_FILE"
elif [[ -f "$REPO_ROOT/.env.release" ]]; then
  ENV_FILE="$REPO_ROOT/.env.release"
elif [[ -f "$REPO_ROOT/.env" ]]; then
  ENV_FILE="$REPO_ROOT/.env"
else
  ENV_FILE=""
fi

if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
elif [[ "${SERVERBOX_RELEASE_ENV_FILE:-}" != "" ]]; then
  echo "release environment file not found: $ENV_FILE" >&2
  exit 1
fi

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "$name is required" >&2
    exit 1
  fi
}

require_file() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    echo "file not found: $path" >&2
    exit 1
  fi
}

require_cmd() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "command not found: $name" >&2
    exit 1
  fi
}

normalize_abs_path() {
  local path="$1"
  if [[ -z "$path" ]]; then
    echo 'path must not be empty' >&2
    exit 1
  fi
  if [[ "$path" != /* ]]; then
    echo "path must be absolute: $path" >&2
    exit 1
  fi

  local normalized="${path%/}"
  if [[ -z "$normalized" ]]; then
    normalized='/'
  fi

  case "$normalized" in
    *$'\n'* | *'//'*) echo "path contains invalid characters: $path" >&2; exit 1 ;;
    ../* | */../* | */.. | .. | . | */./* | */.) echo "path must not contain traversal segments: $path" >&2; exit 1 ;;
  esac

  printf '%s\n' "$normalized"
}

validate_allowed_path() {
  local label="$1"
  local path="$2"
  local normalized
  normalized="$(normalize_abs_path "$path")"

  case "$normalized" in
    /tmp | /var/folders)
      echo "$label must not be the temp root directory: $normalized" >&2
      exit 1
      ;;
  esac

  case "$normalized" in
    "$REPO_ROOT/build" | "$REPO_ROOT/build/"* | /tmp/* | /var/folders/*)
      printf '%s\n' "$normalized"
      ;;
    *)
      echo "$label must be under $REPO_ROOT/build, /tmp, or /var/folders: $normalized" >&2
      exit 1
      ;;
  esac
}

validate_path_within_base() {
  local label="$1"
  local path="$2"
  local base="$3"
  local normalized_path
  local normalized_base

  normalized_path="$(normalize_abs_path "$path")"
  normalized_base="$(validate_allowed_path "$label base" "$base")"

  case "$normalized_path" in
    "$normalized_base" | "$normalized_base/"*)
      printf '%s\n' "$normalized_path"
      ;;
    *)
      echo "$label must be within $normalized_base: $normalized_path" >&2
      exit 1
      ;;
  esac
}

safe_remove() {
  local mode="$1"
  local label="$2"
  local path="$3"
  local base="${4:-}"
  local normalized_path

  if [[ -n "$base" ]]; then
    normalized_path="$(validate_path_within_base "$label" "$path" "$base")"
  else
    normalized_path="$(validate_allowed_path "$label" "$path")"
  fi

  rm "$mode" "$normalized_path"
}

read_pubspec_versions() {
  local version_line
  version_line="$(sed -nE 's/^version:[[:space:]]*([^+]+)\+([0-9]+)$/\1 \2/p' "$REPO_ROOT/pubspec.yaml" | head -n 1)"
  if [[ -z "$version_line" ]]; then
    echo "unable to parse version from pubspec.yaml" >&2
    exit 1
  fi
  printf '%s\n' "$version_line"
}

require_var APPLE_TEAM_ID
require_var APPLE_NOTARY_KEYCHAIN_PROFILE

require_cmd xcodebuild
require_cmd codesign
require_cmd xcrun
require_cmd hdiutil
require_cmd spctl
require_file /usr/libexec/PlistBuddy

WORKSPACE_PATH="${WORKSPACE_PATH:-$REPO_ROOT/macos/Runner.xcworkspace}"
SCHEME="${SCHEME:-Runner}"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_NAME="${APP_NAME:-Server Box}"
APP_ASSET_NAME="${APP_ASSET_NAME:-ServerBox}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.lollipopkit.toolbox}"
VOLUME_NAME="${VOLUME_NAME:-ServerBox}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
APP_PROFILE_NAME="${APP_PROFILE_NAME:-ServerBox DMG Profile}"
BUILD_ROOT="${BUILD_ROOT:-$REPO_ROOT/build/release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$BUILD_ROOT/${APP_ASSET_NAME}.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$BUILD_ROOT/export/${APP_ASSET_NAME}}"
ARTIFACTS_PATH="${ARTIFACTS_PATH:-$REPO_ROOT/build/artifacts}"
EXPORT_OPTIONS_PATH="${EXPORT_OPTIONS_PATH:-$BUILD_ROOT/ExportOptions-${APP_ASSET_NAME}.plist}"
OVERRIDE_XCCONFIG_PATH="${OVERRIDE_XCCONFIG_PATH:-$BUILD_ROOT/${APP_ASSET_NAME}-release-overrides.xcconfig}"
DMG_STAGING_PATH="${DMG_STAGING_PATH:-$REPO_ROOT/build/dmg-root}"
PUBLISH_GITHUB_RELEASE="${PUBLISH_GITHUB_RELEASE:-1}"
APP_REPO_SLUG="${APP_REPO_SLUG:-lollipopkit/flutter_server_box}"
RELEASE_TITLE="${RELEASE_TITLE:-}"

if [[ "$PUBLISH_GITHUB_RELEASE" == "1" ]]; then
  require_cmd gh
fi

require_file "$WORKSPACE_PATH"

read -r DEFAULT_MARKETING_VERSION DEFAULT_CURRENT_PROJECT_VERSION <<<"$(read_pubspec_versions)"
MARKETING_VERSION="${MARKETING_VERSION_OVERRIDE:-$DEFAULT_MARKETING_VERSION}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION_OVERRIDE:-$DEFAULT_CURRENT_PROJECT_VERSION}"
RELEASE_TAG="${RELEASE_TAG:-v${MARKETING_VERSION}}"
RELEASE_TITLE="${RELEASE_TITLE:-$RELEASE_TAG}"
DMG_BASENAME="${DMG_BASENAME:-${APP_ASSET_NAME}-${MARKETING_VERSION}-${CURRENT_PROJECT_VERSION}}"
DMG_PATH="${DMG_PATH:-$ARTIFACTS_PATH/${DMG_BASENAME}.dmg}"

validate_allowed_path 'BUILD_ROOT' "$BUILD_ROOT" >/dev/null
validate_allowed_path 'ARTIFACTS_PATH' "$ARTIFACTS_PATH" >/dev/null
validate_allowed_path 'DMG_STAGING_PATH' "$DMG_STAGING_PATH" >/dev/null
validate_path_within_base 'ARCHIVE_PATH' "$ARCHIVE_PATH" "$BUILD_ROOT" >/dev/null
validate_path_within_base 'EXPORT_PATH' "$EXPORT_PATH" "$BUILD_ROOT" >/dev/null
validate_path_within_base 'EXPORT_OPTIONS_PATH' "$EXPORT_OPTIONS_PATH" "$BUILD_ROOT" >/dev/null
validate_path_within_base 'OVERRIDE_XCCONFIG_PATH' "$OVERRIDE_XCCONFIG_PATH" "$BUILD_ROOT" >/dev/null
validate_path_within_base 'DMG_PATH' "$DMG_PATH" "$ARTIFACTS_PATH" >/dev/null

mkdir -p "$ARTIFACTS_PATH" "$(dirname "$ARCHIVE_PATH")" "$(dirname "$EXPORT_PATH")"

safe_remove -rf 'ARCHIVE_PATH' "$ARCHIVE_PATH" "$BUILD_ROOT"
safe_remove -rf 'EXPORT_PATH' "$EXPORT_PATH" "$BUILD_ROOT"
safe_remove -rf 'DMG_STAGING_PATH' "$DMG_STAGING_PATH"
safe_remove -f 'EXPORT_OPTIONS_PATH' "$EXPORT_OPTIONS_PATH" "$BUILD_ROOT"
safe_remove -f 'OVERRIDE_XCCONFIG_PATH' "$OVERRIDE_XCCONFIG_PATH" "$BUILD_ROOT"
safe_remove -f 'DMG_PATH' "$DMG_PATH" "$ARTIFACTS_PATH"

cat >"$OVERRIDE_XCCONFIG_PATH" <<EOF
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY[sdk=macosx*] = $SIGNING_IDENTITY
DEVELOPMENT_TEAM[sdk=macosx*] = $APPLE_TEAM_ID
PROVISIONING_PROFILE_SPECIFIER[sdk=macosx*] = $APP_PROFILE_NAME
OTHER_CODE_SIGN_FLAGS = --timestamp --options runtime
EOF

/usr/libexec/PlistBuddy -c 'Clear dict' "$EXPORT_OPTIONS_PATH"
/usr/libexec/PlistBuddy -c 'Add :method string developer-id' "$EXPORT_OPTIONS_PATH"
/usr/libexec/PlistBuddy -c 'Add :signingStyle string manual' "$EXPORT_OPTIONS_PATH"
/usr/libexec/PlistBuddy -c 'Add :stripSwiftSymbols bool true' "$EXPORT_OPTIONS_PATH"
/usr/libexec/PlistBuddy -c "Add :teamID string $APPLE_TEAM_ID" "$EXPORT_OPTIONS_PATH"
/usr/libexec/PlistBuddy -c "Add :signingCertificate string $SIGNING_IDENTITY" "$EXPORT_OPTIONS_PATH"
/usr/libexec/PlistBuddy -c 'Add :provisioningProfiles dict' "$EXPORT_OPTIONS_PATH"
/usr/libexec/PlistBuddy -c "Add :provisioningProfiles:$APP_BUNDLE_ID string $APP_PROFILE_NAME" "$EXPORT_OPTIONS_PATH"

xcodebuild \
  -workspace "$WORKSPACE_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -xcconfig "$OVERRIDE_XCCONFIG_PATH" \
  FLUTTER_BUILD_NAME="$MARKETING_VERSION" \
  FLUTTER_BUILD_NUMBER="$CURRENT_PROJECT_VERSION" \
  archive

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PATH"

APP_PATH="$EXPORT_PATH/${APP_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "exported app not found at $APP_PATH" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl -a -t exec -vv "$APP_PATH"

APP_PATH="$APP_PATH" \
APP_NAME="$APP_NAME" \
APP_ASSET_NAME="$APP_ASSET_NAME" \
VOLUME_NAME="$VOLUME_NAME" \
ARTIFACTS_PATH="$ARTIFACTS_PATH" \
DMG_STAGING_PATH="$DMG_STAGING_PATH" \
DMG_BASENAME="$DMG_BASENAME" \
DMG_PATH="$DMG_PATH" \
REQUIRE_SPCTL=1 \
bash "$SCRIPT_DIR/package-dmg-from-xcarchive.sh"

codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"

xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$APPLE_NOTARY_KEYCHAIN_PROFILE" \
  --wait

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

if [[ "$PUBLISH_GITHUB_RELEASE" == "1" ]]; then
  if gh release view "$RELEASE_TAG" --repo "$APP_REPO_SLUG" >/dev/null 2>&1; then
    gh release edit "$RELEASE_TAG" \
      --repo "$APP_REPO_SLUG" \
      --title "$RELEASE_TITLE"
  else
    gh release create "$RELEASE_TAG" \
      --repo "$APP_REPO_SLUG" \
      --title "$RELEASE_TITLE" \
      --notes ""
  fi

  gh release upload "$RELEASE_TAG" "$DMG_PATH" \
    --repo "$APP_REPO_SLUG" \
    --clobber
fi

echo "Release complete"
echo "Marketing version: $MARKETING_VERSION"
echo "Build number: $CURRENT_PROJECT_VERSION"
echo "Archive: $ARCHIVE_PATH"
echo "Exported app: $APP_PATH"
echo "DMG: $DMG_PATH"
if [[ "$PUBLISH_GITHUB_RELEASE" == "1" ]]; then
  echo "GitHub release: $APP_REPO_SLUG $RELEASE_TAG"
fi
