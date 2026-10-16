#!/bin/sh
# Runs inside an Alpine container (build.sh, CI): aports' mkimage.sh with the
# sbm profile. Mounts: /iso (this directory), /pkg (the release package with
# install.sh), /out. Environment: SBM_ARCH, SBM_VERSION, OUT_OWNER (uid:gid).

set -eu

: "${SBM_ARCH:?}" "${SBM_VERSION:?}"
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
cp /iso/profile/mkimg.sbm.sh /iso/profile/genapkovl-sbm.sh "$work/"
chmod +x "$work/genapkovl-sbm.sh"

cd "$work"
sh ./mkimage.sh \
	--tag "$SBM_VERSION" \
	--arch "$SBM_ARCH" \
	--profile sbm \
	--outdir /out \
	--repository "$MIRROR/$ALPINE_BRANCH/main" \
	--repository "$MIRROR/$ALPINE_BRANCH/community"

iso="server-box-monitor-$SBM_VERSION-$SBM_ARCH.iso"
cd /out
[ -f "$iso" ] || { echo "mkimage wrote no $iso" >&2; ls -l >&2; exit 1; }
sha256sum "$iso" > "$iso.sha256"
# The caller's, not the container's root.
[ -z "${OUT_OWNER:-}" ] || chown "$OUT_OWNER" "$iso" "$iso.sha256"
