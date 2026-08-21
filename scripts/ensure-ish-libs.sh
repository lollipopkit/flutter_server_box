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
# The one whose tag is on the submodule's checked-out HEAD, asked of the
# submodule itself: the fork tags every published commit `vX.Y.Z`, so
# `git tag --points-at HEAD` answers offline and exactly. That gitlink is this
# repository's only statement about which revision of the engine it builds
# against — see CLAUDE.md — so resolving through it means the libraries and the
# source cannot drift apart. "The latest release" would link one revision's
# libraries against another's headers and leave nothing to notice it by.
#
# `libs-<sha>` is what the fork tagged with until versions arrived, and is
# still tried when no `v` tag points here — a gitlink pinned before the change
# resolves the way it always did.
#
# A shallow submodule, or one cloned before the tag existed, has no tag to find
# and gets one `git fetch --tags` before the fallback. Not on every run: the
# usual reason to be here is a build directory that is empty or stale, not a
# checkout that is behind.
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
stamp="$lib_dir/.ish-libs-sha"

# Highest first, so a commit that ended up with two of them — a re-run of the
# publishing workflow — takes the later version rather than whichever `git tag`
# happened to list first.
#
# Read whole rather than piped into `head`: this script runs under `pipefail`,
# and `head` closing the pipe after one line can leave `git` killed by SIGPIPE,
# which fails the pipeline and takes the script with it.
version_tag() {
  local tags
  tags="$(git -C "$SRC_DIR" tag --points-at HEAD --list 'v[0-9]*' --sort=-v:refname)"
  printf '%s\n' "${tags%%$'\n'*}"
}

tag="$(version_tag)"
if [ -z "$tag" ]; then
  git -C "$SRC_DIR" fetch --tags --quiet origin 2>/dev/null || true
  tag="$(version_tag)"
fi
# The name the fork published under before it had versions. Kept as a fallback
# rather than as the answer: a gitlink from then still resolves, and one from
# now never reaches it.
[ -n "$tag" ] || tag="libs-$sha"

ish_libs=(libish.a libish_emu.a libfakefs.a)

have_libs() {
  for lib in "${ish_libs[@]}"; do
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
  # Both sides of this come from the same release, so it catches a truncated
  # or corrupted download and nothing else. It is NOT the guarantee
  # `IosRootfs.install` gives the rootfs: that compares against
  # `LinuxDistro.sha256`, a constant in the source, so a replaced release fails
  # it. Here a replaced release brings its own SHA256SUMS and passes.
  #
  # What stands between this and running someone else's code is the release
  # being reached over HTTPS from a repository the developer controls. That is
  # weaker, and worth saying rather than implying otherwise.
  #
  # TODO: pin the archive's digest next to the gitlink, so moving the submodule
  # and trusting a build become one reviewable change.
  if ! (cd "$tmp" && grep " $asset\$" SHA256SUMS | shasum -a 256 -c --status -); then
    echo "error: $asset does not match SHA256SUMS for $tag" >&2
    exit 1
  fi

  mkdir -p "$lib_dir"
  # The previous revision's libraries go first. `have_libs` below asks only
  # whether the three are present, so one this archive does not carry would
  # survive the unpack, pass that check, and link into a build it was not built
  # for.
  for lib in "${ish_libs[@]}"; do rm -f "$lib_dir/$lib"; done
  # Owner comes from this machine rather than the archive. Members that are
  # absolute or climb with `..` are refused by tar itself unless `-P` is given,
  # which is why there is no guard for them here — this unpacks during the
  # Xcode build of a shipped app, so it is worth knowing which of the two is
  # doing the work.
  tar xzf "$tmp/$asset" -C "$lib_dir" --no-same-owner
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
