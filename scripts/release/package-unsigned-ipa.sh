#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

APP_ASSET_NAME="${APP_ASSET_NAME:-ServerBox}"
BUILD_DATA_PATH="${BUILD_DATA_PATH:-$REPO_ROOT/lib/data/res/build_data.dart}"
APP_PATH="${1:-${APP_PATH:-$REPO_ROOT/build/ios/iphoneos/Runner.app}}"
ARTIFACTS_PATH="${ARTIFACTS_PATH:-$REPO_ROOT/build/artifacts}"
PAYLOAD_STAGING_PATH="${PAYLOAD_STAGING_PATH:-$REPO_ROOT/build/ipa-root}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "app bundle not found: $APP_PATH" >&2
  echo "Run 'flutter build ios --release --no-codesign' first." >&2
  exit 1
fi

BUILD_NUMBER="${BUILD_NUMBER:-}"
if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="$(sed -n -E 's/.*static const int build = ([0-9]+);/\1/p' "$BUILD_DATA_PATH" | head -n 1)"
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  echo "build number not found in $BUILD_DATA_PATH" >&2
  exit 1
fi

# The artifact carries no signature, so the name must say so: it is not
# installable without re-signing.
IPA_PATH="${IPA_PATH:-$ARTIFACTS_PATH/${APP_ASSET_NAME}_v1.0.${BUILD_NUMBER}_NoSign.ipa}"

# zip runs from the staging dir, so resolve the output to an absolute path
# first: a relative IPA_PATH or ARTIFACTS_PATH would otherwise land inside the
# staging dir and be deleted with it.
mkdir -p "$(dirname "$IPA_PATH")"
IPA_PATH="$(cd "$(dirname "$IPA_PATH")" && pwd)/$(basename "$IPA_PATH")"

rm -rf "$PAYLOAD_STAGING_PATH"
mkdir -p "$PAYLOAD_STAGING_PATH/Payload"
rm -f "$IPA_PATH"

STAGED_APP_PATH="$PAYLOAD_STAGING_PATH/Payload/$(basename "$APP_PATH")"
cp -R "$APP_PATH" "$STAGED_APP_PATH"

# Drop signing leftovers of the app and of every embedded bundle (extensions,
# watch app, frameworks) so the payload is uniformly unsigned.
find "$STAGED_APP_PATH" -name '_CodeSignature' -type d -prune -exec rm -rf {} +
find "$STAGED_APP_PATH" -name 'embedded.mobileprovision' -type f -delete

(cd "$PAYLOAD_STAGING_PATH" && zip -qry "$IPA_PATH" Payload)
rm -rf "$PAYLOAD_STAGING_PATH"

echo "unsigned ipa: $IPA_PATH"
shasum -a 256 "$IPA_PATH"
