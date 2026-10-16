#!/bin/sh -e
# Writes the image's overlay (`<hostname>.apkovl.tar.gz`): the files Alpine's
# initramfs unpacks over the live system at boot. Called by mkimage.sh with
# the hostname, in the build's output directory.
#
# /pkg is the release package (build.sh mounts it, with install.sh beside
# the binary); /os/musl/overlay the files copied as they are, /os/common
# what both images share.

HOSTNAME="$1"
[ -n "$HOSTNAME" ] || { echo "usage: $0 hostname" >&2; exit 1; }
set -u

PKG=/pkg
OVERLAY=/os/musl/overlay
[ -n "${SBM_WORLD:-}" ] || { echo "SBM_WORLD is empty: run by mkimage.sh with profile sbm" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

rc_add() {
	mkdir -p "$tmp/etc/runlevels/$2"
	ln -sf "/etc/init.d/$1" "$tmp/etc/runlevels/$2/$1"
}

mkdir -p "$tmp/etc/apk" "$tmp/etc/network"
echo "$HOSTNAME" > "$tmp/etc/hostname"

# What the initramfs installs from the medium at boot, and what setup-disk
# installs on a disk (`SBM_WORLD` in the profile).
# shellcheck disable=SC2086  # a list of package names
printf '%s\n' $SBM_WORLD | sort -u > "$tmp/etc/apk/world"

cat > "$tmp/etc/network/interfaces" <<IFACES
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
IFACES

# Alpine's base set (aports' genapkovl-dhcp.sh), then this image's services.
# The agent's own service is added by install.sh when it is installed.
for svc in devfs:sysinit dmesg:sysinit mdev:sysinit hwdrivers:sysinit modloop:sysinit \
	hwclock:boot modules:boot sysctl:boot hostname:boot bootmisc:boot syslog:boot \
	networking:boot \
	sshd:default chronyd:default docker:default sbm-setup:default \
	mount-ro:shutdown killprocs:shutdown savecache:shutdown; do
	rc_add "${svc%%:*}" "${svc##*:}"
done

cp -a "$OVERLAY/." "$tmp/"

# The release package and the install.sh of the same commit.
share="$tmp/usr/share/server-box-monitor"
mkdir -p "$share/pkg"
cp -a "$PKG/server_box_monitor" "$PKG/frontend" "$PKG/migrations" \
	"$PKG/config.example.toml" "$PKG/.env.example" "$share/pkg/"
cp "$PKG/install.sh" "$share/install.sh"
cp /os/common/sbm-setup "$share/sbm-setup"
cp /os/common/NOTICE "$share/NOTICE"
chmod 755 "$share/sbm-setup"

chown -R 0:0 "$tmp"
tar -c -C "$tmp" etc usr | gzip -9n > "$HOSTNAME.apkovl.tar.gz"
