#!/usr/bin/env bash
# Fetch and verify every dependency needed by build-fdroid.sh before F-Droid
# disables network access for the build phase.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=android-build-env.sh
source "$REPO_ROOT/scripts/release/android-build-env.sh"

flutter pub get --enforce-lockfile

# The native-assets hook invokes rustup in crates/sbm_ffi. Entering that crate
# installs the exact toolchain and Android std targets from rust-toolchain.toml
# while the preparation phase still has network access. Fetch dependencies
# with that same compiler selected; the offline build must not discover either
# a missing toolchain or a missing crate.
rust_toolchain="$(sed -n -E \
  's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
  crates/sbm_ffi/rust-toolchain.toml)"
[ -n "$rust_toolchain" ] || { echo "Rust toolchain is not pinned" >&2; exit 1; }
(cd crates/sbm_ffi && rustup show active-toolchain)
rustup run "$rust_toolchain" cargo fetch --locked --manifest-path Cargo.toml
scripts/release/patch-jni-build-id.sh
scripts/build-proot-android.sh

# Writes local.properties and the generated Android build inputs without
# producing an APK. Resolving the release dependency graph here fills Gradle's
# cache while the preparation phase is still allowed network access.
flutter build apk --release --config-only --no-pub
(cd android && ./gradlew --no-daemon :app:dependencies)
