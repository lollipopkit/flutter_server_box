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

warn_pre_notary_spctl_rejection() {
  local app_path="$1"

  echo "Skipping pre-notarization spctl enforcement for $app_path"
  echo 'Developer ID signed apps can be rejected by Gatekeeper before notarization with source=Unnotarized Developer ID'
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

resolve_path_for_validation() {
  local path="$1"
  local normalized
  local existing
  local remainder=''
  local name
  local parent
  local resolved

  normalized="$(normalize_abs_path "$path")"
  existing="$normalized"

  while [[ ! -e "$existing" ]]; do
    if [[ "$existing" == "/" ]]; then
      echo "unable to canonicalize path: $path" >&2
      exit 1
    fi

    name="${existing##*/}"
    parent="${existing%/*}"
    if [[ -z "$parent" ]]; then
      parent='/'
    fi

    remainder="/$name$remainder"
    existing="$parent"
  done

  if [[ -n "$remainder" && ! -d "$existing" ]]; then
    echo "path parent is not a directory: $existing" >&2
    exit 1
  fi

  if ! resolved="$(realpath "$existing" 2>/dev/null)"; then
    echo "unable to canonicalize path: $path" >&2
    exit 1
  fi

  if [[ -z "$remainder" ]]; then
    printf '%s\n' "$resolved"
  elif [[ "$resolved" == "/" ]]; then
    printf '/%s\n' "${remainder#/}"
  else
    printf '%s%s\n' "$resolved" "$remainder"
  fi
}

validate_allowed_path() {
  local label="$1"
  local path="$2"
  local resolved_path
  local resolved_repo_build
  local resolved_tmp
  local resolved_var_folders

  resolved_path="$(resolve_path_for_validation "$path")"
  resolved_repo_build="$(resolve_path_for_validation "$REPO_ROOT/build")"
  resolved_tmp="$(resolve_path_for_validation '/tmp')"
  resolved_var_folders="$(resolve_path_for_validation '/var/folders')"

  case "$resolved_path" in
    "$resolved_tmp" | "$resolved_var_folders")
      echo "$label must not be the temp root directory: $resolved_path" >&2
      exit 1
      ;;
  esac

  case "$resolved_path" in
    "$resolved_repo_build" | "$resolved_repo_build/"* | "$resolved_tmp"/* | "$resolved_var_folders"/*)
      printf '%s\n' "$resolved_path"
      ;;
    *)
      echo "$label must be under $resolved_repo_build, $resolved_tmp, or $resolved_var_folders: $resolved_path" >&2
      exit 1
      ;;
  esac
}

validate_path_within_base() {
  local label="$1"
  local path="$2"
  local base="$3"
  local resolved_path
  local resolved_base

  resolved_path="$(resolve_path_for_validation "$path")"
  resolved_base="$(validate_allowed_path "$label base" "$base")"

  case "$resolved_path" in
    "$resolved_base" | "$resolved_base/"*)
      printf '%s\n' "$resolved_path"
      ;;
    *)
      echo "$label must be within $resolved_base: $resolved_path" >&2
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

# Map Xcode architecture names to the names used by release assets. The project
# already uses `amd64` for APK and AppImage assets.
asset_arch_for() {
  case "$1" in
    arm64) printf 'arm64\n' ;;
    x86_64) printf 'amd64\n' ;;
    *) echo "unknown architecture: $1" >&2; exit 1 ;;
  esac
}

# Verify that every Mach-O contains exactly the requested architecture. This
# catches the Rust toolchain's fallback to the host target, which could place an
# arm64 library in an Intel app and cause `RustLib.init` to fail at runtime.
verify_app_arch() {
  local app_path="$1"
  local expected="$2"
  local checked=0
  local binary archs
  local -a bad=()

  while IFS= read -r -d '' binary; do
    archs="$(lipo -archs "$binary" 2>/dev/null)" || continue
    checked=$((checked + 1))
    case "${binary##*/}" in
      # Apple's Swift back-deployment runtime, copied out of the toolchain by
      # Xcode's "Copy Swift Standard Libraries" phase and universal as it
      # ships. It only has to carry this slice.
      libswift*.dylib)
        [[ " $archs " == *" $expected "* ]] || bad+=("${binary#"$app_path/"}: $archs")
        ;;
      *)
        [[ "$archs" == "$expected" ]] || bad+=("${binary#"$app_path/"}: $archs")
        ;;
    esac
  done < <(find "$app_path/Contents/MacOS" "$app_path/Contents/Frameworks" -type f -print0)

  if (( checked == 0 )); then
    echo "no Mach-O binary found in $app_path" >&2
    exit 1
  fi
  if (( ${#bad[@]} )); then
    echo "${#bad[@]} binary/binaries in $app_path are not $expected alone:" >&2
    printf '  %s\n' "${bad[@]}" >&2
    exit 1
  fi
  echo "$app_path: $checked binaries, all $expected"
}

require_var APPLE_TEAM_ID
require_var APPLE_NOTARY_KEYCHAIN_PROFILE

require_cmd xcodebuild
require_cmd codesign
require_cmd xcrun
require_cmd hdiutil
require_cmd lipo
require_cmd spctl
require_cmd realpath
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
ARTIFACTS_PATH="${ARTIFACTS_PATH:-$REPO_ROOT/build/artifacts}"
EXPORT_OPTIONS_PATH="${EXPORT_OPTIONS_PATH:-$BUILD_ROOT/ExportOptions-${APP_ASSET_NAME}.plist}"
OVERRIDE_XCCONFIG_PATH="${OVERRIDE_XCCONFIG_PATH:-$BUILD_ROOT/${APP_ASSET_NAME}-release-overrides.xcconfig}"
RUNNER_PROJECT_FILE="${RUNNER_PROJECT_FILE:-$REPO_ROOT/macos/Runner.xcodeproj/project.pbxproj}"
RUNNER_PROJECT_BACKUP="${RUNNER_PROJECT_BACKUP:-$BUILD_ROOT/Runner.project.pbxproj.backup}"
DMG_STAGING_PATH="${DMG_STAGING_PATH:-$REPO_ROOT/build/dmg-root}"
PUBLISH_GITHUB_RELEASE="${PUBLISH_GITHUB_RELEASE:-1}"
APP_REPO_SLUG="${APP_REPO_SLUG:-lollipopkit/flutter_server_box}"
RELEASE_TITLE="${RELEASE_TITLE:-}"

if [[ "$PUBLISH_GITHUB_RELEASE" == "1" ]]; then
  require_cmd gh
fi

require_file "$WORKSPACE_PATH"
require_file "$REPO_ROOT/macos/Runner/ReleaseDmg.entitlements"

read -r DEFAULT_MARKETING_VERSION DEFAULT_CURRENT_PROJECT_VERSION <<<"$(read_pubspec_versions)"
MARKETING_VERSION="${MARKETING_VERSION_OVERRIDE:-$DEFAULT_MARKETING_VERSION}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION_OVERRIDE:-$DEFAULT_CURRENT_PROJECT_VERSION}"
RELEASE_TAG="${RELEASE_TAG:-v${MARKETING_VERSION}}"
RELEASE_TITLE="${RELEASE_TITLE:-$RELEASE_TAG}"
DMG_BASENAME="${DMG_BASENAME:-${APP_ASSET_NAME}-${MARKETING_VERSION}}"

# Build one DMG per architecture instead of a universal DMG. The App Store build
# supports Apple silicon only (macos/Runner/Configs/Release.xcconfig), so Intel
# users rely on the Developer ID DMG. Separate DMGs also allow each architecture
# to be verified independently before release.
#
# `RELEASE_ARCHS` supports partial retries. If one architecture fails during
# notarization, rerun only that architecture; the Homebrew cask step reuses any
# DMG for the same version that is already on disk.
RELEASE_ARCHS="${RELEASE_ARCHS:-arm64 x86_64}"
if [[ -z "${RELEASE_ARCHS//[[:space:]]/}" ]]; then
  echo "RELEASE_ARCHS must name at least one architecture" >&2
  exit 1
fi
for arch in $RELEASE_ARCHS; do
  asset_arch_for "$arch" >/dev/null
done

validate_allowed_path 'BUILD_ROOT' "$BUILD_ROOT" >/dev/null
validate_allowed_path 'ARTIFACTS_PATH' "$ARTIFACTS_PATH" >/dev/null
validate_allowed_path 'DMG_STAGING_PATH' "$DMG_STAGING_PATH" >/dev/null
validate_path_within_base 'EXPORT_OPTIONS_PATH' "$EXPORT_OPTIONS_PATH" "$BUILD_ROOT" >/dev/null
validate_path_within_base 'OVERRIDE_XCCONFIG_PATH' "$OVERRIDE_XCCONFIG_PATH" "$BUILD_ROOT" >/dev/null
validate_path_within_base 'RUNNER_PROJECT_BACKUP' "$RUNNER_PROJECT_BACKUP" "$BUILD_ROOT" >/dev/null

mkdir -p \
  "$ARTIFACTS_PATH" \
  "$BUILD_ROOT/export" \
  "$(dirname "$EXPORT_OPTIONS_PATH")" \
  "$(dirname "$OVERRIDE_XCCONFIG_PATH")" \
  "$(dirname "$RUNNER_PROJECT_BACKUP")"

safe_remove -rf 'DMG_STAGING_PATH' "$DMG_STAGING_PATH"
safe_remove -f 'EXPORT_OPTIONS_PATH' "$EXPORT_OPTIONS_PATH" "$BUILD_ROOT"
safe_remove -f 'OVERRIDE_XCCONFIG_PATH' "$OVERRIDE_XCCONFIG_PATH" "$BUILD_ROOT"
safe_remove -f 'RUNNER_PROJECT_BACKUP' "$RUNNER_PROJECT_BACKUP" "$BUILD_ROOT"

restore_runner_project() {
  if [[ -f "$RUNNER_PROJECT_BACKUP" ]]; then
    cp "$RUNNER_PROJECT_BACKUP" "$RUNNER_PROJECT_FILE"
  fi
}

cp "$RUNNER_PROJECT_FILE" "$RUNNER_PROJECT_BACKUP"
trap restore_runner_project EXIT

cat >"$OVERRIDE_XCCONFIG_PATH" <<EOF
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY[sdk=macosx*] = $SIGNING_IDENTITY
DEVELOPMENT_TEAM[sdk=macosx*] = $APPLE_TEAM_ID
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

built_dmgs=()
last_app_path=''

for arch in $RELEASE_ARCHS; do
  asset_arch="$(asset_arch_for "$arch")"
  archive_path="$BUILD_ROOT/${APP_ASSET_NAME}-${asset_arch}.xcarchive"
  export_path="$BUILD_ROOT/export/${APP_ASSET_NAME}-${asset_arch}"
  dmg_path="$ARTIFACTS_PATH/${DMG_BASENAME}-${asset_arch}.dmg"

  validate_path_within_base 'ARCHIVE_PATH' "$archive_path" "$BUILD_ROOT" >/dev/null
  validate_path_within_base 'EXPORT_PATH' "$export_path" "$BUILD_ROOT" >/dev/null
  validate_path_within_base 'DMG_PATH' "$dmg_path" "$ARTIFACTS_PATH" >/dev/null

  safe_remove -rf 'ARCHIVE_PATH' "$archive_path" "$BUILD_ROOT"
  safe_remove -rf 'EXPORT_PATH' "$export_path" "$BUILD_ROOT"
  safe_remove -f 'DMG_PATH' "$dmg_path" "$ARTIFACTS_PATH"

  echo "==> $arch"

  # The DMG ships unsandboxed, which is what lets it host a terminal on this
  # machine: a sandboxed process cannot open a pseudo-terminal's slave device.
  # The App Store build keeps Release.entitlements and its sandbox, and the same
  # binary hides the feature there — see LocalShellBackend.isSupported.
  #
  # An override rather than a second build configuration: the two products differ
  # in one entitlement and nothing else, and a flavour would be a scheme, a
  # configuration and a bundle id to keep in step for that one bit.
  #
  # The entitlements swap is a project edit and not an xcconfig override, because
  # `-xcconfig` applies to *every* target in the workspace — including the Swift
  # Package Manager targets Flutter's plugins are built as. CODE_SIGN_ENTITLEMENTS
  # is a path relative to each target's own SRCROOT, so a value naming a file in
  # the Runner project fails to resolve in ~10 package projects and the archive
  # stops before it compiles anything. An absolute path would resolve, and would
  # then sign every plugin framework with the app's entitlements.
  #
  # Re-applied per architecture because the archive below is followed by a
  # restore: the checkout is left as it was found even when a build fails.
  APP_PROFILE_NAME="$APP_PROFILE_NAME" perl -0pi -e '
    my $profile = $ENV{"APP_PROFILE_NAME"};
    s/"PROVISIONING_PROFILE_SPECIFIER\[sdk=macosx\*\]" = "[^"]*";/"PROVISIONING_PROFILE_SPECIFIER[sdk=macosx*]" = "$profile";/
      or die "macOS Runner Release provisioning profile setting not found\n";
    s{CODE_SIGN_ENTITLEMENTS = Runner/Release\.entitlements;}{CODE_SIGN_ENTITLEMENTS = Runner/ReleaseDmg.entitlements;}
      or die "macOS Runner Release entitlements setting not found\n";
  ' "$RUNNER_PROJECT_FILE"

  # Command-line ARCHS takes precedence over both `ARCHS = arm64` in
  # macos/Runner/Configs/Release.xcconfig and the `-xcconfig` file.
  # ONLY_ACTIVE_ARCH=NO prevents Xcode from silently selecting the host
  # architecture instead of the requested one.
  xcodebuild \
    -workspace "$WORKSPACE_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$archive_path" \
    -xcconfig "$OVERRIDE_XCCONFIG_PATH" \
    ARCHS="$arch" \
    ONLY_ACTIVE_ARCH=NO \
    FLUTTER_BUILD_NAME="$MARKETING_VERSION" \
    FLUTTER_BUILD_NUMBER="$CURRENT_PROJECT_VERSION" \
    archive

  restore_runner_project

  xcodebuild -exportArchive \
    -archivePath "$archive_path" \
    -exportPath "$export_path" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PATH"

  app_path="$export_path/${APP_NAME}.app"
  if [[ ! -d "$app_path" ]]; then
    echo "exported app not found at $app_path" >&2
    exit 1
  fi

  verify_app_arch "$app_path" "$arch"
  codesign --verify --deep --strict --verbose=2 "$app_path"
  warn_pre_notary_spctl_rejection "$app_path"

  APP_PATH="$app_path" \
  APP_NAME="$APP_NAME" \
  APP_ASSET_NAME="$APP_ASSET_NAME" \
  VOLUME_NAME="$VOLUME_NAME" \
  ARTIFACTS_PATH="$ARTIFACTS_PATH" \
  DMG_STAGING_PATH="$DMG_STAGING_PATH" \
  DMG_BASENAME="${DMG_BASENAME}-${asset_arch}" \
  DMG_PATH="$dmg_path" \
  REQUIRE_SPCTL=0 \
  bash "$SCRIPT_DIR/package-dmg-from-xcarchive.sh"

  codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$dmg_path"
  codesign --verify --verbose=2 "$dmg_path"

  xcrun notarytool submit "$dmg_path" \
    --keychain-profile "$APPLE_NOTARY_KEYCHAIN_PROFILE" \
    --wait

  xcrun stapler staple "$dmg_path"
  xcrun stapler validate "$dmg_path"
  spctl -a -t open --context context:primary-signature -vv "$dmg_path"

  built_dmgs+=("$dmg_path")
  last_app_path="$app_path"
done

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

  gh release upload "$RELEASE_TAG" "${built_dmgs[@]}" \
    --repo "$APP_REPO_SLUG" \
    --clobber
fi

# The cask references one download per architecture, so update it only when both
# DMGs exist. Files already on disk count even if the current run built only one,
# which allows partial retries without creating a cask that contains a 404 URL.
DMG_ARM64_PATH="$ARTIFACTS_PATH/${DMG_BASENAME}-arm64.dmg"
DMG_AMD64_PATH="$ARTIFACTS_PATH/${DMG_BASENAME}-amd64.dmg"

if [[ "${SYNC_HOMEBREW_CASK:-1}" == "1" ]]; then
  if [[ -f "$DMG_ARM64_PATH" && -f "$DMG_AMD64_PATH" ]]; then
    APP_PATH="$last_app_path" \
    DMG_ARM64_PATH="$DMG_ARM64_PATH" \
    DMG_AMD64_PATH="$DMG_AMD64_PATH" \
    RELEASE_TAG="$RELEASE_TAG" \
    TAP_REPO_PATH="${TAP_REPO_PATH:-$HOME/proj/homebrew-cask}" \
    bash "$SCRIPT_DIR/sync-homebrew-cask.sh"
  else
    SYNC_HOMEBREW_CASK=0
    echo "Skipping the Homebrew cask: it needs a DMG for both architectures" >&2
    echo "  arm64: $DMG_ARM64_PATH" >&2
    echo "  amd64: $DMG_AMD64_PATH" >&2
  fi
fi

echo "Release complete"
echo "Marketing version: $MARKETING_VERSION"
echo "Build number: $CURRENT_PROJECT_VERSION"
echo "Architectures: $RELEASE_ARCHS"
for dmg in "${built_dmgs[@]}"; do
  echo "DMG: $dmg"
done
if [[ "$PUBLISH_GITHUB_RELEASE" == "1" ]]; then
  echo "GitHub release: $APP_REPO_SLUG $RELEASE_TAG"
fi
if [[ "${SYNC_HOMEBREW_CASK:-1}" == "1" ]]; then
  echo "Homebrew cask: ${TAP_CASK_PATH:-${TAP_REPO_PATH:-$HOME/proj/homebrew-cask}/Casks/s/server-box.rb}"
fi
