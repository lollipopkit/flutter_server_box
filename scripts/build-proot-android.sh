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
#     nowhere for either binary to be. This script does not set it: it makes
#     every install larger, and it is only worth paying for once the rootfs
#     feature actually ships.
#
# Sources are canonical upstreams, not a fork of a fork. proot needs one
# one-line patch to build with a current NDK — see `patch_proot`.
#
# Usage: scripts/build-proot-android.sh [--clean]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${PROOT_BUILD_DIR:-$REPO_ROOT/build/proot-android}"
OUT_DIR="$REPO_ROOT/android/app/src/main/jniLibs/arm64-v8a"

TALLOC_VERSION=2.4.2
TALLOC_URL="https://download.samba.org/pub/talloc/talloc-${TALLOC_VERSION}.tar.gz"
PROOT_URL="https://github.com/termux/proot/archive/refs/heads/master.tar.gz"

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
  local url="$1" dest="$2"
  [ -f "$dest" ] && return
  log "Fetching $(basename "$dest")"
  curl -fsSL --retry 3 -o "$dest" "$url"
}

build_talloc() {
  local src="$WORK_DIR/talloc-$TALLOC_VERSION"
  [ -f "$WORK_DIR/libtalloc.a" ] && { log "talloc already built"; return; }

  fetch "$TALLOC_URL" "$WORK_DIR/talloc.tar.gz"
  [ -d "$src" ] || tar xzf "$WORK_DIR/talloc.tar.gz" -C "$WORK_DIR"

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
  if [ ! -d "$src" ]; then
    fetch "$PROOT_URL" "$WORK_DIR/proot.tar.gz"
    mkdir -p "$src"
    tar xzf "$WORK_DIR/proot.tar.gz" -C "$src" --strip-components=1
  fi
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

Not done by this script, and needed before either binary can run:

  android/app/build.gradle
      packaging { jniLibs { useLegacyPackaging = true } }

Without it nothing is extracted from the APK and nativeLibraryDir does not
exist. See the comment at the top of this file.
NOTE
