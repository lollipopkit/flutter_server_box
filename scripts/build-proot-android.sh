#!/usr/bin/env bash
#
# Builds proot and its loader for Android arm64, into the one directory an app
# is allowed to execute from.
#
# Why this exists
# ---------------
# An app targeting API 29 or later cannot execve a file in its own data
# directory, and a Linux rootfs is nothing but files in that directory. proot
# gets around it not by asking for permission but by never using execve on a
# guest binary: it carries a loader that maps the guest ELF and hands control
# to the guest's own interpreter. Measured in
# `integration_test/android_rootfs_test.dart` — an Alpine aarch64 busybox that
# is refused directly and by Android's own linker runs under proot.
#
# Two things are easy to get wrong, and both fail in ways that read like the
# restriction rather than a mistake:
#
#   * The loader has to be shipped too, and named in PROOT_LOADER. Left alone
#     proot extracts the copy bundled in its binary to a temp file, which lands
#     in the app's directory, cannot be executed, and proot falls back to a
#     plain execve — reported as `proot error: execve(...): Permission denied`.
#
#   * `useLegacyPackaging = true` is required in android/app/build.gradle.
#     With minSdk >= 23 native libraries are mapped straight out of the APK and
#     nothing is extracted, so `nativeLibraryDir` does not exist and there is
#     nowhere for either binary to be. It is set there now; the APK is the
#     smaller for it (extracted libraries are stored compressed) and the
#     install the larger, since they are then kept twice.
#
# Sources are canonical upstreams, not a fork of a fork, and both are pinned:
# talloc by version and digest, proot by tag *and* the commit that tag pointed
# at. proot needs one one-line patch to build with a current NDK — see
# `patch_proot`.
#
# Usage: scripts/build-proot-android.sh [--clean]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${PROOT_BUILD_DIR:-$REPO_ROOT/build/proot-android}"
OUT_DIR="$REPO_ROOT/android/app/src/main/jniLibs/arm64-v8a"

TALLOC_VERSION=2.4.2
TALLOC_URL="https://download.samba.org/pub/talloc/talloc-${TALLOC_VERSION}.tar.gz"
TALLOC_SHA256=85ecf9e465e20f98f9950a52e9a411e14320bc555fa257d87697b7e7a9b1d8a6

# Pinned to a tag, and then to the commit that tag pointed at when it was
# added. A tag can be moved; a commit id cannot, so the second check is the one
# that means anything. This is the binary that runs the guest's code, and
# `master` would have let it change under a release build without anybody
# choosing that.
PROOT_REPO="https://github.com/termux/proot.git"
PROOT_TAG=v5.1.107.90
PROOT_COMMIT=894e5789cd982e53d644bb3a13332f1d35e907ac

# 26 rather than the app's minSdk: proot is a plain executable and nothing in
# it needs a newer libc than the oldest device the app supports.
ANDROID_API=26
NDK_TRIPLE=aarch64-linux-android

log() { printf '\033[0;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[0;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

if [ "${1:-}" = "--clean" ]; then
  log "Removing $WORK_DIR and the built libraries"
  rm -rf "$WORK_DIR" "$OUT_DIR/libproot.so" "$OUT_DIR/libproot-loader.so"
  exit 0
fi

find_ndk() {
  for candidate in "${ANDROID_NDK_HOME:-}" "${ANDROID_NDK_ROOT:-}"; do
    [ -n "$candidate" ] && [ -d "$candidate" ] && { echo "$candidate"; return; }
  done
  # Whatever Android Studio installed, newest first.
  local sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  [ -d "$sdk/ndk" ] || die "no NDK found; set \$ANDROID_NDK_HOME"
  local newest
  newest="$(ls -1 "$sdk/ndk" | sort -V | tail -1)"
  [ -n "$newest" ] || die "no NDK found; set \$ANDROID_NDK_HOME"
  echo "$sdk/ndk/$newest"
}

NDK="$(find_ndk)"
case "$(uname -s)" in
  Darwin) HOST_TAG=darwin-x86_64 ;;
  Linux) HOST_TAG=linux-x86_64 ;;
  *) die "unsupported build host: $(uname -s)" ;;
esac
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin"
CC="$TOOLCHAIN/${NDK_TRIPLE}${ANDROID_API}-clang"
[ -x "$CC" ] || die "no compiler at $CC"
log "NDK: $NDK"

mkdir -p "$WORK_DIR" "$OUT_DIR"

fetch() {
  local url="$1" dest="$2" want="${3:-}" got
  if [ -f "$dest" ]; then
    if [ -z "$want" ]; then return; fi
    got="$(sha256 "$dest")"
    if [ "$got" = "$want" ]; then return; fi
    log "$(basename "$dest") digest mismatch (expected $want, got $got), re-fetching"
    rm -f "$dest"
  fi
  log "Fetching $(basename "$dest")"
  curl -fsSL --retry 3 -o "$dest" "$url"
  [ -n "$want" ] || return
  got="$(sha256 "$dest")"
  # Removed, not left behind: a cached file that failed its check would be
  # skipped by the `-f` above on the next run and never checked again.
  [ "$got" = "$want" ] || { rm -f "$dest"; die "$(basename "$dest") is not what it should be: expected $want, got $got"; }
}

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

build_talloc() {
  local src="$WORK_DIR/talloc-$TALLOC_VERSION"
  fetch "$TALLOC_URL" "$WORK_DIR/talloc.tar.gz" "$TALLOC_SHA256"
  # The archive is the authenticated cache. Recreate sources and outputs from
  # it on every invocation so a modified persistent work tree or libtalloc.a
  # can never be packaged merely because the expected files still exist.
  rm -rf "$src"
  rm -f "$WORK_DIR/talloc.o" "$WORK_DIR/libtalloc.a"
  tar xzf "$WORK_DIR/talloc.tar.gz" -C "$WORK_DIR"

  # talloc.c includes Samba's `replace.h`, a compat shim for platforms without
  # a modern libc. Building the one file we need against bionic is far less
  # work than bringing in Samba's waf build to generate it.
  cat >"$src/replace.h" <<'SHIM'
#ifndef REPLACE_H
#define REPLACE_H

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>
#include <errno.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/auxv.h>

/* Must match the tarball, which talloc.c asserts against at runtime. */
#define TALLOC_BUILD_VERSION_MAJOR   2
#define TALLOC_BUILD_VERSION_MINOR   4
#define TALLOC_BUILD_VERSION_RELEASE 2

#define HAVE_SYS_AUXV_H 1
#define HAVE_INTPTR_T 1
#define HAVE_VA_COPY 1
#define HAVE_CONSTRUCTOR_ATTRIBUTE 1

/* Valgrind hooks are no-ops outside Samba's own build. */
#define VALGRIND_MAKE_MEM_UNDEFINED(p, n) do { (void)(p); (void)(n); } while (0)
#define VALGRIND_MAKE_MEM_DEFINED(p, n)   do { (void)(p); (void)(n); } while (0)
#define VALGRIND_MAKE_MEM_NOACCESS(p, n)  do { (void)(p); (void)(n); } while (0)

#ifndef ZERO_STRUCT
#define ZERO_STRUCT(x) memset((char *)&(x), 0, sizeof(x))
#endif
#ifndef discard_const
#define discard_const(ptr) ((void *)((uintptr_t)(ptr)))
#endif
#ifndef MIN
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif
#ifndef MAX
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#endif

#endif /* REPLACE_H */
SHIM

  log "Building talloc"
  "$CC" -c -O2 -o "$WORK_DIR/talloc.o" -I "$src" "$src/talloc.c"
  "$TOOLCHAIN/llvm-ar" rcs "$WORK_DIR/libtalloc.a" "$WORK_DIR/talloc.o"
}

patch_proot() {
  local file="$1/src/extension/ashmem_memfd/ashmem_memfd.c"
  grep -q '#include <string.h>' "$file" && return
  # `strcmp` and `memset` with no declaration. A current clang rejects implicit
  # declarations outright, where the one this fork was written against warned.
  # Applied here rather than by depending on somebody's fork of the fork.
  log "Patching ashmem_memfd.c for a current NDK"
  awk 'NR==1{print "#include <string.h>"}1' "$file" >"$file.new"
  mv "$file.new" "$file"
}

build_proot() {
  local src="$WORK_DIR/proot"
  if [ -e "$src" ] && [ ! -d "$src/.git" ]; then
    log "Discarding an unauthenticated proot source cache"
    rm -rf "$src"
  fi
  if [ ! -d "$src" ]; then
    log "Cloning proot $PROOT_TAG"
    # Cloned rather than fetched as a tarball: GitHub's generated archives are
    # not promised to be byte-stable, so a digest of one is a check that can
    # break without anything having changed. A commit id cannot.
    git clone --quiet --depth 1 --branch "$PROOT_TAG" "$PROOT_REPO" "$src"
  fi
  local head
  head="$(git -C "$src" rev-parse HEAD)"
  [ "$head" = "$PROOT_COMMIT" ] || die "proot $PROOT_TAG is $head, not the pinned $PROOT_COMMIT"
  # HEAD alone does not authenticate a reused working tree or old build
  # products. Restore the committed tree and remove every untracked/ignored
  # artifact before applying our deterministic patch and rebuilding.
  git -C "$src" reset --hard "$PROOT_COMMIT" >/dev/null
  git -C "$src" clean -ffdqx
  patch_proot "$src"

  log "Building proot"
  # In-tree: proot's makefile double-prefixes source paths for out-of-tree
  # builds, and objects next to sources are what `make clean` expects.
  #
  # ARG_MAX is not defined on bionic. -I. matters because proot's own headers
  # are included as `execve/elf.h` and the like.
  ( cd "$src/src" && make \
      CC="$CC" \
      STRIP="$TOOLCHAIN/llvm-strip" \
      OBJCOPY="$TOOLCHAIN/llvm-objcopy" \
      OBJDUMP="$TOOLCHAIN/llvm-objdump" \
      CPPFLAGS="-D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE -I. -DARG_MAX=131072 -I$WORK_DIR/talloc-$TALLOC_VERSION" \
      CFLAGS="-O2 -Wall -Wextra -fPIE" \
      LDFLAGS="-Wl,-z,noexecstack -pie -L$WORK_DIR -ltalloc" \
      -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)" >/dev/null )

  [ -f "$src/src/proot" ] || die "proot did not build"
  [ -f "$src/src/loader/loader" ] || die "proot's loader did not build"

  # Named `lib*.so` because that is what Android extracts. Neither is a shared
  # object; the packaging cares about the name and nothing else.
  install -m 0755 "$src/src/proot" "$OUT_DIR/libproot.so"
  install -m 0755 "$src/src/loader/loader" "$OUT_DIR/libproot-loader.so"
}

build_talloc
build_proot

log "Built into $OUT_DIR"
ls -la "$OUT_DIR"/libproot*.so
cat <<'NOTE'

These are not in the repository. A build that has not run this script has no
Linux userland — `AndroidRootfs.isAvailable` is false and the entry does not
appear. CI runs it in .github/workflows/build.yml, and checks afterwards that
both binaries actually reached the APK.
NOTE
