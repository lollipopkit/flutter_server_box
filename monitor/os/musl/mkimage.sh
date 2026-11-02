#!/bin/sh
# sbOS (musl), run inside an Alpine container by ../build.sh: aports'
# mkimage.sh with the sbm profile. Mounts: /os (monitor/os), /pkg (the
# release package with install.sh), /out. Environment: SBM_ARCH
# (x86_64|aarch64), SBM_VERSION, OUT_NAME, OUT_OWNER (uid:gid).

set -eu

: "${SBM_ARCH:?}" "${SBM_VERSION:?}" "${OUT_NAME:?}"
# Alpine 3.24; aports pinned to a commit of 3.24-stable, so the scripts run
# are the ones reviewed.
ALPINE_BRANCH=v3.24
APORTS_COMMIT=8dda40f62186710707d93e571f4fa7519b1538a0
MIRROR=https://dl-cdn.alpinelinux.org/alpine

apk add --no-cache abuild alpine-conf apk-tools fakeroot squashfs-tools \
	xorriso mtools grub grub-efi dosfstools

# Signs the medium's own package index; made for this build and discarded.
abuild-keygen -a -n -q >/dev/null

work=/tmp/aports
mkdir -p "$work"
for f in mkimage.sh mkimg.base.sh mkimg.standard.sh; do
	wget -q -O "$work/$f" "https://raw.githubusercontent.com/alpinelinux/aports/$APORTS_COMMIT/scripts/$f"
done
cp /os/musl/profile/mkimg.sbm.sh /os/musl/profile/genapkovl-sbm.sh "$work/"
chmod +x "$work/genapkovl-sbm.sh"

cd "$work"
sh ./mkimage.sh \
	--tag "$SBM_VERSION" \
	--arch "$SBM_ARCH" \
	--profile sbm \
	--outdir /tmp/mkimage-out \
	--workdir /tmp/mkimage-work \
	--repository "$MIRROR/$ALPINE_BRANCH/main" \
	--repository "$MIRROR/$ALPINE_BRANCH/community"

mv "/tmp/mkimage-out/sbos-$SBM_VERSION-$SBM_ARCH.iso" "/out/$OUT_NAME.img"

# What the image carries, for its licences: every package and version, and
# where Alpine keeps their sources.
{
	echo "# $OUT_NAME: Alpine $ALPINE_BRANCH packages (aports $APORTS_COMMIT)"
	echo "# Sources: https://gitlab.alpinelinux.org/alpine/aports/-/tree/$APORTS_COMMIT"
	echo "#          https://distfiles.alpinelinux.org/distfiles/$ALPINE_BRANCH/"
	for apk in /tmp/mkimage-work/apks_*/apks/"$SBM_ARCH"/*.apk; do
		basename "$apk" .apk
	done | sort -u
} > "/out/$OUT_NAME.packages.txt"

[ -z "${OUT_OWNER:-}" ] || chown "$OUT_OWNER" "/out/$OUT_NAME.img" "/out/$OUT_NAME.packages.txt"
