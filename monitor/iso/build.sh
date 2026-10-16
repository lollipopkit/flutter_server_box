#!/bin/sh
# Builds the ServerBox Monitor ISO in an Alpine container (Docker is the only
# requirement, macOS or Linux):
#
#   ./build.sh [--arch x86_64|aarch64] [--version <v>] [--pkg <dir|tar.gz>] [--out <dir>]
#
# --pkg is a release package (unpacked, or its tarball); without it the
# version's release tarball is downloaded and checked against SHA256SUMS.
# Another architecture than the host's runs under emulation (qemu binfmt).

set -eu

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
REPO_SLUG="lollipopkit/flutter_server_box"
# The container mkimage.sh runs in. An older Alpine than the image: mkimage.sh
# creates its package root with `apk add --no-chown`, which apk-tools 3
# (Alpine 3.23+) refuses as root. The image is built from v3.24 either way.
BUILDER_IMAGE="alpine:3.22"

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
		-h | --help) sed -n '2,10p' "$0"; exit 0 ;;
		*) echo "Unknown option: $1" >&2; exit 1 ;;
	esac
done

[ -n "$VERSION" ] || VERSION="$(sed -n 's/^version = "\(.*\)"/\1/p' "$repo/monitor/Cargo.toml" | head -n 1)"
if [ -z "$ARCH" ]; then
	case "$(uname -m)" in
		arm64 | aarch64) ARCH=aarch64 ;;
		*) ARCH=x86_64 ;;
	esac
fi
case "$ARCH" in
	x86_64) asset_arch=amd64 platform=linux/amd64 ;;
	aarch64) asset_arch=arm64 platform=linux/arm64 ;;
	*) echo "--arch is x86_64 or aarch64" >&2; exit 1 ;;
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
docker run --rm --platform "$platform" \
	-v "$here:/iso:ro" -v "$pkg:/pkg:ro" -v "$OUT:/out" \
	-e "SBM_ARCH=$ARCH" -e "SBM_VERSION=$VERSION" -e "OUT_OWNER=$(id -u):$(id -g)" \
	"$BUILDER_IMAGE" sh /iso/mkiso.sh
echo "$OUT/server-box-monitor-$VERSION-$ARCH.iso"
