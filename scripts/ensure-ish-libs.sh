#!/usr/bin/env bash
#
# Puts the iOS Linux engine's static libraries where the linker expects them,
# by fetching the release built for this exact revision of the fork, or by
# building them here if there is no such release.
#
# Run from the Runner target's build phases, ahead of Flutter's own. Nothing
# else connects the two: ios/Flutter/Ish.xcconfig hands the three `.a` paths to
# the linker through OTHER_LDFLAGS, and if they are absent the build stops with
# three `No such file or directory` lines that name the files and not the
# reason. Two ordinary ways to get there —
#
#   * having built for the device and then running the simulator, or the other
#     way round: each target has its own build-<arch> directory and neither
#     implies the other;
#   * `flutter clean`, which removes build/ and takes the libraries with it,
#     leaving a checkout that looks untouched.
#
# ## Which release
#
# The one tagged `libs-<sha>`, where the sha is the submodule's checked-out
# HEAD. That gitlink is this repository's only statement about which revision
# of the engine it builds against — see CLAUDE.md — so binding the download to
# it means the libraries and the source cannot drift apart. "The latest
# release" would link one revision's libraries against another's headers and
# leave nothing to notice it by.
#
# ## Which not to
#
# What is checked once they are in place is the sha they were put there for,
# recorded beside them in `.ish-libs-sha`. Existence alone was not enough: the
# ordinary way the gitlink moves is `git submodule update --remote`, which
# leaves the previous revision's libraries sitting in build/ where they are
# still found, and linking those against the new revision's headers is the
# drift this script exists to prevent. A stamp that does not match HEAD is
# treated the same as no libraries at all.
#
# Editing the engine's source still does not rebuild them — that would mean
# teaching Xcode meson's dependency graph, and HEAD has not moved.
# `scripts/build-ish-ios.sh` stays the way to force one, and an edited
# submodule has no release to match its HEAD anyway, so it takes the local
# path below.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$REPO_ROOT/third_party/ish-arm64"
REPO="lollipopkit/ShellBox"

# Off is the default and is what an App Store build can be made with: the
# engine is not linked, ISH_LDFLAGS_0 is empty, and there is nothing to fetch.
[ "${SBM_ISH:-0}" = "1" ] || exit 0

case "${PLATFORM_NAME:-}" in
  iphonesimulator) target=simulator; asset=ish-iossim-arm64.tar.gz ;;
  iphoneos) target=device; asset=ish-ios-arm64.tar.gz ;;
  # macOS reaches a shell through flutter_pty, and anything else is not a
  # platform this engine is built for.
  *) exit 0 ;;
esac

# Set alongside the link flags, so the two cannot disagree about where the
# libraries are meant to be.
lib_dir="${ISH_BUILD_DIR:-}"
if [ -z "$lib_dir" ]; then
  echo "warning: ISH_BUILD_DIR is unset, leaving the engine to the linker" >&2
  exit 0
fi

if [ ! -d "$SRC_DIR/.git" ] && [ ! -f "$SRC_DIR/.git" ]; then
  echo "error: third_party/ish-arm64 is not checked out" >&2
  echo "       git submodule update --init third_party/ish-arm64" >&2
  exit 1
fi

sha="$(git -C "$SRC_DIR" rev-parse HEAD)"
tag="libs-$sha"
stamp="$lib_dir/.ish-libs-sha"

have_libs() {
  for lib in libish.a libish_emu.a libfakefs.a; do
    [ -f "$lib_dir/$lib" ] || return 1
  done
}

# Written last, so an interrupted fetch or build leaves no stamp and the next
# run does the work again rather than trusting a partial set.
stamp_libs() {
  printf '%s\n' "$sha" > "$stamp"
}

if have_libs; then
  [ "$(cat "$stamp" 2>/dev/null)" = "$sha" ] && exit 0
  echo "note: the engine in $lib_dir was built for another revision, replacing it" >&2
fi

build_locally() {
  # ISH_BUILD_DIR is cleared, not passed on. Both scripts have a variable by
  # that name and they mean different things: here, and in Ish.xcconfig, it is
  # the directory the three libraries end up in; in build-ish-ios.sh it is the
  # work directory *above* the per-target ones. Inherited, that script builds
  # into build-iossim-arm64/build-iossim-arm64 and the linker looks in vain
  # one level up.
  env -u ISH_BUILD_DIR "$SCRIPT_DIR/build-ish-ios.sh" "$target" >&2
}
base="https://github.com/$REPO/releases/download/$tag"

# Downloaded whole and checked before anything is unpacked into the directory
# the linker reads, so a truncated or wrong archive cannot leave a half-built
# set of libraries behind.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "note: fetching the iOS Linux engine for $target, $tag" >&2
if curl -fsSL --retry 2 -o "$tmp/$asset" "$base/$asset" &&
   curl -fsSL --retry 2 -o "$tmp/SHA256SUMS" "$base/SHA256SUMS"; then
  # Executable code fetched over a network, which is the standard the alpine
  # rootfs is already held to — see IosRootfs.install.
  if ! (cd "$tmp" && grep " $asset\$" SHA256SUMS | shasum -a 256 -c --status -); then
    echo "error: $asset does not match SHA256SUMS for $tag" >&2
    exit 1
  fi

  mkdir -p "$lib_dir"
  tar xzf "$tmp/$asset" -C "$lib_dir"
  have_libs || { echo "error: $asset did not hold the three libraries" >&2; exit 1; }
  stamp_libs
  echo "note: unpacked into $lib_dir" >&2
  exit 0
fi

# No release for this revision. Ordinary while the engine's own source is being
# worked on, and while a commit sits on a branch rather than on main — the fork
# publishes one release per commit there.
for tool in meson ninja; do
  command -v "$tool" >/dev/null 2>&1 && continue
  # Said this way round on purpose. The missing tool is what stops the build,
  # but it is not the problem: a checkout whose gitlink names a published
  # revision never reaches here, and on CI that is the only supported case.
  echo "error: no release $tag for the engine, and no toolchain to build one" >&2
  echo "       The gitlink names a revision the fork has not published." >&2
  echo "       Point it at a commit on the fork's main branch, or install" >&2
  echo "       the toolchain: brew install meson ninja llvm lld libarchive" >&2
  exit 1
done

echo "note: no release $tag, building from source instead" >&2
build_locally
have_libs || { echo "error: the local build left no libraries in $lib_dir" >&2; exit 1; }
stamp_libs
