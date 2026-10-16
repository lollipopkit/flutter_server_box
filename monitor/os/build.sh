#!/bin/sh
# Builds an sbOS image in a container (Docker is the only requirement, macOS
# or Linux):
#
#   ./build.sh musl|gnu [--arch x64|arm64] [--version <v>] [--pkg <dir|tar.gz>] [--out <dir>]
#
# musl is Alpine 3.24, gnu Debian 13. --pkg is a release package (unpacked,
# or its tarball); without it the version's release tarball is downloaded and
# checked against SHA256SUMS. Another architecture than the host's runs
# under emulation (qemu binfmt). Writes sbOS_<musl|GNU>_<arch>.img, its
# .packages.txt and .sha256.

set -eu

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
REPO_SLUG="lollipopkit/flutter_server_box"

FLAVOR="${1:-}"
case "$FLAVOR" in
	musl | gnu) shift ;;
	-h | --help) sed -n '2,12p' "$0"; exit 0 ;;
	*) echo "usage: $0 musl|gnu [options]" >&2; exit 1 ;;
esac

ARCH=""
VERSION=""
PKG=""
OUT="$here/out"
while [ $# -gt 0 ]; do
	case "$1" in
		--arch) ARCH="$2"; shift 2 ;;
		--version) VERSION="$2"; shift 2 ;;
		--pkg) PKG="$2"; shift 2 ;;
		--out) OUT="$2"; shift 2 ;;
		*) echo "Unknown option: $1" >&2; exit 1 ;;
	esac
done

[ -n "$VERSION" ] || VERSION="$(sed -n 's/^version = "\(.*\)"/\1/p' "$repo/monitor/Cargo.toml" | head -n 1)"
if [ -z "$ARCH" ]; then
	case "$(uname -m)" in
		arm64 | aarch64) ARCH=arm64 ;;
		*) ARCH=x64 ;;
	esac
fi
case "$ARCH" in
	x64) asset_arch=amd64 platform=linux/amd64 alpine_arch=x86_64 ;;
	arm64) asset_arch=arm64 platform=linux/arm64 alpine_arch=aarch64 ;;
	*) echo "--arch is x64 or arm64" >&2; exit 1 ;;
esac

sha256() {
	if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1
}

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
pkg="$staging/server-box-monitor"

if [ -n "$PKG" ] && [ -d "$PKG" ]; then
	mkdir -p "$pkg" && cp -a "$PKG/." "$pkg/"
elif [ -n "$PKG" ]; then
	tar -xzf "$PKG" -C "$staging"
else
	asset="server-box-monitor_v${VERSION}_linux_${asset_arch}.tar.gz"
	base="https://github.com/$REPO_SLUG/releases/download/monitor-v$VERSION"
	curl -fsSL "$base/$asset" -o "$staging/$asset"
	curl -fsSL "$base/SHA256SUMS" -o "$staging/SHA256SUMS"
	expected="$(awk -v a="$asset" '$2 == a { print $1 }' "$staging/SHA256SUMS")"
	[ -n "$expected" ] && [ "$(sha256 "$staging/$asset")" = "$expected" ] || {
		echo "$asset does not match the release's SHA256SUMS" >&2
		exit 1
	}
	tar -xzf "$staging/$asset" -C "$staging"
fi
[ -f "$pkg/server_box_monitor" ] && [ -d "$pkg/frontend/dist" ] || {
	echo "Not a release package: $pkg needs server_box_monitor and frontend/dist" >&2
	exit 1
}
# The installer of this checkout, which the image runs on boot.
cp "$repo/monitor/install.sh" "$pkg/install.sh"

mkdir -p "$OUT"
owner="$(id -u):$(id -g)"
if [ "$FLAVOR" = musl ]; then
	name="sbOS_musl_$ARCH"
	# mkimage.sh creates its package root with `apk add --no-chown`, which
	# apk-tools 3 (Alpine 3.23+) refuses as root: an older Alpine runs it.
	docker run --rm --platform "$platform" \
		-v "$here:/os:ro" -v "$pkg:/pkg:ro" -v "$OUT:/out" \
		-e "SBM_ARCH=$alpine_arch" -e "SBM_VERSION=$VERSION" -e "OUT_NAME=$name" -e "OUT_OWNER=$owner" \
		alpine:3.22 sh /os/musl/mkimage.sh
else
	name="sbOS_GNU_$ARCH"
	# live-build mounts /proc and /dev in its chroot.
	docker run --rm --privileged --platform "$platform" \
		-v "$here:/os:ro" -v "$pkg:/pkg:ro" -v "$OUT:/out" \
		-e "SBM_ARCH=$asset_arch" -e "OUT_NAME=$name" -e "OUT_OWNER=$owner" \
		debian:trixie sh /os/gnu/mkimage.sh
fi

(cd "$OUT" && sha256 "$name.img" | sed "s/\$/  $name.img/" > "$name.img.sha256")
echo "$OUT/$name.img"
