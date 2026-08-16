#!/usr/bin/env bash
#
# Builds the ish-arm64 engine for iOS, and an Alpine filesystem for it to run.
#
# Why this exists
# ---------------
# iOS gives an App Store app no `fork`/`exec` and no `/bin/sh`, so the Android
# answer — a real rootfs entered through proot — cannot work: there is nothing
# to enter it with. ish-arm64 is the other shape. It is an interpreter: guest
# AArch64 instructions are dispatched to pre-compiled native gadgets, so no
# machine code is written at runtime (iOS grants no JIT entitlement) and no
# guest binary is ever handed to the kernel.
#
# It emulates the *same* architecture the host runs, which is what makes it
# usable rather than a curiosity — upstream iSH interprets 32-bit x86 on ARM.
#
# What this produces
# ------------------
#   libish.a, libish_emu.a, libfakefs.a   the engine, for one SDK and arch
#   alpine-fakefs/                        an Alpine filesystem in iSH's format
#
# The app does not use `alpine-fakefs`: it downloads and unpacks its own tree at
# first launch, because `realfs` mounts an ordinary directory. That output is
# kept for the command-line build, where `ish -f` wants iSH's own format.
#
# The libraries are linked into the app by `ios/Flutter/Ish.xcconfig`, which is
# where `SBM_ISH` decides whether any of this ships at all.
#
# Usage: scripts/build-ish-ios.sh [simulator|device|macos]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${ISH_BUILD_DIR:-$REPO_ROOT/build/ish}"
SRC_DIR="$WORK_DIR/ish-arm64"

# Pinned to a commit, not a branch. This is an interpreter that runs whatever
# the guest filesystem contains; which revision of it ships should be a choice,
# not whatever upstream pushed today.
ISH_REPO="https://github.com/OpenMinis/ish-arm64.git"
ISH_COMMIT=7e100366a4b59557a4a0c4657d0d6115e99d1f5e

# The same release the Android rootfs is pinned to, and for the same reason —
# see AndroidRootfs.version, which records why the branch is 3.22.
ALPINE_VERSION=3.22.5
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/aarch64/alpine-minirootfs-${ALPINE_VERSION}-aarch64.tar.gz"
ALPINE_SHA256=3fbc6285032ed46821b511292633d7b2a6306a2e254f590e92bdafff56cf2f70

TARGET="${1:-simulator}"

log() { printf '\033[0;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[0;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

for tool in meson ninja git curl; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool is not installed (brew install $tool)"
done
# The guest VDSO is compiled for Linux, which Apple's clang cannot target.
[ -x /opt/homebrew/opt/llvm/bin/clang ] || die "llvm is not installed (brew install llvm)"
# fakefsify needs it, and meson only builds that tool when it is present.
[ -d /opt/homebrew/opt/libarchive ] || die "libarchive is not installed (brew install libarchive)"
export PKG_CONFIG_PATH="/opt/homebrew/opt/libarchive/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

mkdir -p "$WORK_DIR"

fetch_source() {
  if [ ! -d "$SRC_DIR" ]; then
    log "Cloning ish-arm64"
    git clone --quiet "$ISH_REPO" "$SRC_DIR"
  fi
  local head
  head="$(git -C "$SRC_DIR" rev-parse HEAD)"
  if [ "$head" != "$ISH_COMMIT" ]; then
    log "Checking out the pinned commit"
    git -C "$SRC_DIR" fetch --quiet origin "$ISH_COMMIT" 2>/dev/null || git -C "$SRC_DIR" fetch --quiet origin
    # Forced, because the tree carries the patches below and they are put back
    # immediately afterwards. Without it a pin bump fails on a dirty tree.
    git -C "$SRC_DIR" checkout --quiet -f "$ISH_COMMIT"
  fi
  apply_patches
}

# Fixes to the engine that this app needs and upstream has not made.
#
# Kept as patches against the pinned commit rather than as a fork, so what was
# changed and why is readable in one place. Applying is idempotent: a patch that
# is already in the tree is recognised and skipped. One that no longer applies
# stops the build rather than being skipped quietly — the pin moved and somebody
# has to look.
apply_patches() {
  local dir="$REPO_ROOT/scripts/ish-patches"
  [ -d "$dir" ] || return 0
  local patch
  for patch in "$dir"/*.patch; do
    [ -e "$patch" ] || continue
    local name
    name="$(basename "$patch")"
    if git -C "$SRC_DIR" apply --reverse --check "$patch" >/dev/null 2>&1; then
      log "$name is already applied"
    elif git -C "$SRC_DIR" apply --check "$patch" >/dev/null 2>&1; then
      log "Applying $name"
      git -C "$SRC_DIR" apply "$patch"
    else
      die "$name does not apply to $ISH_COMMIT — the pin moved, or the tree is not clean"
    fi
  done
}

# The engine, for one platform. Only the three libraries: the `ish` CLI is a
# host convenience and meson does not build it in a cross build anyway.
build_libs() {
  local name="$1" sdk="$2" min_flag="$3"
  local build_dir="$SRC_DIR/build-$name"
  local sysroot
  sysroot="$(xcrun --sdk "$sdk" --show-sdk-path)"

  local cross="$WORK_DIR/$name.ini"
  cat >"$cross" <<EOF
# Generated by scripts/build-ish-ios.sh — edits will be overwritten.
#
# The simulator and the device are the same architecture as this machine,
# which is the point of this fork: the gadgets a device runs are the ones
# built here. What differs is the SDK and the platform minimum.
[binaries]
c = 'clang'
cpp = 'clang++'
ar = 'ar'
strip = 'strip'
pkg-config = 'pkg-config'

[built-in options]
c_args = ['-arch', 'arm64', '-isysroot', '$sysroot', '$min_flag']
c_link_args = ['-arch', 'arm64', '-isysroot', '$sysroot', '$min_flag']
cpp_args = ['-arch', 'arm64', '-isysroot', '$sysroot', '$min_flag']
cpp_link_args = ['-arch', 'arm64', '-isysroot', '$sysroot', '$min_flag']

[host_machine]
system = 'darwin'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF

  log "Configuring $name"
  if [ -d "$build_dir" ]; then
    ( cd "$SRC_DIR" && meson setup --reconfigure "build-$name" -Dguest_arch=arm64 \
        --buildtype=release --cross-file "$cross" >/dev/null )
  else
    ( cd "$SRC_DIR" && meson setup "build-$name" -Dguest_arch=arm64 \
        --buildtype=release --cross-file "$cross" >/dev/null )
  fi

  log "Building $name"
  # Named targets rather than everything: `tools/fakefsify` links the host's
  # libarchive and cannot be built for a phone, and it is not wanted there.
  ninja -C "$build_dir" libish.a libish_emu.a libfakefs.a >/dev/null

  for lib in libish.a libish_emu.a libfakefs.a; do
    [ -f "$build_dir/$lib" ] || die "$lib did not build"
  done
  log "Built into $build_dir"
  ls -la "$build_dir"/lib{ish,ish_emu,fakefs}.a
}

# The host build, which is also what makes the filesystem.
build_host() {
  local build_dir="$SRC_DIR/build-macos-arm64"
  log "Configuring macOS host build"
  if [ -d "$build_dir" ]; then
    ( cd "$SRC_DIR" && meson setup --reconfigure build-macos-arm64 -Dguest_arch=arm64 --buildtype=release >/dev/null )
  else
    ( cd "$SRC_DIR" && meson setup build-macos-arm64 -Dguest_arch=arm64 --buildtype=release >/dev/null )
  fi
  log "Building macOS host build"
  ninja -C "$build_dir" >/dev/null
  echo "$build_dir"
}

# The filesystem the app actually uses: an ordinary directory tree.
#
# `realfs` is what mounts it — every guest path resolved against a root fd —
# so there is nothing to build but the tree itself. That is the whole reason
# this is `tar` and not a tool: unpacking is something the app can do on a
# phone, and a metadata database is not.
build_tree() {
  local tarball="$WORK_DIR/alpine-$ALPINE_VERSION.tar.gz"
  local out="$WORK_DIR/alpine-tree"
  fetch_alpine "$tarball"
  [ -d "$out" ] && { log "Tree already unpacked at $out"; return; }
  log "Unpacking the Alpine tree"
  mkdir -p "$out"
  # Device nodes in the tarball are skipped without root, which is correct
  # here: `/dev` is a tmpfs the guest builds at boot.
  tar xzf "$tarball" -C "$out" 2>/dev/null || true
  [ -f "$out/etc/alpine-release" ] || die "the tree did not unpack"
  log "Unpacked $out"
}

fetch_alpine() {
  local tarball="$1"
  if [ ! -f "$tarball" ]; then
    log "Fetching Alpine $ALPINE_VERSION"
    curl -fsSL --retry 3 -o "$tarball" "$ALPINE_URL"
  fi
  local got
  got="$(sha256 "$tarball")"
  [ "$got" = "$ALPINE_SHA256" ] || { rm -f "$tarball"; die "Alpine tarball digest mismatch: expected $ALPINE_SHA256, got $got"; }
}

# iSH's own format, kept for the command-line build: `ish -f` wants one, and it
# is the only way to run the engine outside an app for comparison.
build_fakefs() {
  local host_build="$1"
  local tarball="$WORK_DIR/alpine-$ALPINE_VERSION.tar.gz"
  local out="$WORK_DIR/alpine-fakefs"

  fetch_alpine "$tarball"
  [ -d "$out" ] && { log "Filesystem already built at $out"; return; }
  log "Building the Alpine filesystem"
  "$host_build/tools/fakefsify" "$tarball" "$out" >/dev/null
  log "Built $out"
}

fetch_source
case "$TARGET" in
  simulator)
    build_libs iossim-arm64 iphonesimulator "-mios-simulator-version-min=13.0"
    build_tree
    ;;
  device)
    build_libs ios-arm64 iphoneos "-miphoneos-version-min=13.0"
    build_tree
    ;;
  macos)
    host="$(build_host)"
    build_fakefs "$host"
    log "Try it: $host/ish -f $WORK_DIR/alpine-fakefs /bin/sh"
    ;;
  *) die "unknown target: $TARGET (simulator|device|macos)" ;;
esac

cat <<'NOTE'

Built. To use them, set `SBM_ISH = 1` — in an untracked ios/Flutter/
IshLocal.xcconfig rather than in the tracked file — and rebuild.

Not done by this script: the device work that only hands can do. See
local-ssh-plan.md, M1 to M5.
NOTE
