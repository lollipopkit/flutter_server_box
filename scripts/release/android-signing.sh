#!/usr/bin/env bash
# Runs a command with the Android release key from 1Password: the keystore as
# the file $SBX_KEYSTORE, removed afterwards, and its passwords and alias as
# SBX_KEYSTORE_PASSWORD, SBX_KEY_PASSWORD and SBX_KEY_ALIAS.
#
#   scripts/release/android-signing.sh dart run fl_build -p android
#
# CI signs in with OP_SERVICE_ACCOUNT_TOKEN; elsewhere `op` asks. A build
# signed with the debug key, or not at all, runs without it.

set -euo pipefail

[ "$#" -gt 0 ] || { echo "usage: $0 <command> [args...]" >&2; exit 2; }

if [ "${ORG_GRADLE_PROJECT_allowDebugReleaseSigning:-}" = true ] ||
  [ "${ORG_GRADLE_PROJECT_allowUnsignedRelease:-}" = true ]; then
  exec "$@"
fi

item="op://ServerBox CI/serverbox-android-keystore"
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
chmod 700 "$dir"

op read --no-newline --out-file "$dir/app.key" "$item/keystore" >/dev/null
export SBX_KEYSTORE="$dir/app.key"
export SBX_KEYSTORE_PASSWORD="$item/password"
export SBX_KEY_PASSWORD="$item/keyPassword"
export SBX_KEY_ALIAS="$item/alias"
# No daemon: one would keep the passwords in its environment after the build.
export GRADLE_OPTS="${GRADLE_OPTS:+$GRADLE_OPTS }-Dorg.gradle.daemon=false"
op run -- "$@"
