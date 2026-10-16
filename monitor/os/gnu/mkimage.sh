#!/bin/sh
# sbOS (GNU), run inside a privileged Debian container by ../build.sh:
# Debian's live-build makes a hybrid image (UEFI, and BIOS on amd64) of
# Debian 13 with Docker and the image's files. Mounts: /os (monitor/os),
# /pkg (the release package with install.sh), /out. Environment: SBM_ARCH
# (amd64|arm64), OUT_NAME, OUT_OWNER (uid:gid).

set -eu

: "${SBM_ARCH:?}" "${OUT_NAME:?}"
SUITE=trixie
MIRROR=http://deb.debian.org/debian
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq --no-install-recommends live-build debootstrap \
	squashfs-tools xorriso mtools dosfstools cpio ca-certificates >/dev/null

case "$SBM_ARCH" in
	amd64) bootloaders="grub-efi syslinux" boot_pkgs="grub-efi-amd64-bin grub-pc-bin" ;;
	arm64) bootloaders="grub-efi" boot_pkgs="grub-efi-arm64-bin" ;;
	*) echo "SBM_ARCH is amd64 or arm64" >&2; exit 1 ;;
esac

# The archive as it was when the image was built: the date the package list
# names, for snapshot.debian.org.
built=$(date -u +%Y%m%dT%H%M%SZ)

work=/tmp/lb
mkdir -p "$work"
cd "$work"
lb config \
	--mode debian --distribution "$SUITE" --architectures "$SBM_ARCH" \
	--archive-areas "main non-free-firmware" \
	--mirror-bootstrap "$MIRROR" --mirror-chroot "$MIRROR" --mirror-binary "$MIRROR" \
	--security true --updates true \
	--binary-images iso-hybrid --bootloaders "$bootloaders" \
	--debian-installer none --memtest none \
	--apt-recommends false --firmware-binary false --firmware-chroot false \
	--iso-application sbOS --iso-volume sbOS --iso-publisher ServerBox \
	--bootappend-live "boot=live quiet" \
	--cache false >/dev/null

# live-boot without live-config (lb config lists both in live.list.chroot):
# no default account with an automatic login, the image's own settings
# instead (hostname, network, services, below).
rm -f config/package-lists/live.list.chroot
cat > config/package-lists/sbos.list.chroot <<EOF
live-boot
systemd-sysv systemd-resolved dbus libpam-systemd
openssh-server chrony ca-certificates curl openssl iproute2 less nano
docker.io docker-cli docker-compose
firmware-linux-free firmware-misc-nonfree firmware-realtek firmware-bnx2 firmware-bnx2x
zstd fdisk dosfstools e2fsprogs grub2-common $boot_pkgs
EOF

# The boot menu: sbOS's, plain text, booting on its own after 3 s.
mkdir -p config/bootloaders
cp -a /os/gnu/bootloaders/. config/bootloaders/

inc=config/includes.chroot
cp -a /os/gnu/includes/. "$inc/"
share="$inc/usr/share/server-box-monitor"
mkdir -p "$share/pkg"
cp -a /pkg/server_box_monitor /pkg/frontend /pkg/migrations \
	/pkg/config.example.toml /pkg/.env.example "$share/pkg/"
cp /pkg/install.sh /os/common/sbm-setup /os/common/NOTICE "$share/"
chmod 755 "$share/sbm-setup" "$inc/usr/local/sbin/sbm-install"

cat > config/hooks/normal/9000-sbos.hook.chroot <<'EOF'
#!/bin/sh
set -e
systemctl enable systemd-networkd systemd-resolved ssh chrony docker \
	var-lib-docker.mount sbm-setup.service
# The console is a root shell, as on sbOS musl (sshd refuses an empty
# password). Set one after installing if the console is not yours alone.
passwd -d root
# Made per machine: host keys at sshd's start, the machine id at first boot.
rm -f /etc/ssh/ssh_host_*
: > /etc/machine-id
EOF
chmod 755 config/hooks/normal/9000-sbos.hook.chroot

lb build >/tmp/lb.log 2>&1 || { tail -60 /tmp/lb.log >&2; exit 1; }

mv "live-image-$SBM_ARCH.hybrid.iso" "/out/$OUT_NAME.img"
{
	echo "# $OUT_NAME: Debian $SUITE packages, built $built"
	echo "# Sources: https://snapshot.debian.org/archive/debian/$built/ (apt-get source <package>=<version>)"
	cat "live-image-$SBM_ARCH.packages"
} > "/out/$OUT_NAME.packages.txt"

[ -z "${OUT_OWNER:-}" ] || chown "$OUT_OWNER" "/out/$OUT_NAME.img" "/out/$OUT_NAME.packages.txt"
