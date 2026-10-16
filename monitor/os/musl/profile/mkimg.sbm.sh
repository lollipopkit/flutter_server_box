# shellcheck disable=SC2034  # read by mkimage.sh
# sbOS (musl): Alpine's standard hybrid image (BIOS and UEFI) with Docker,
# and ServerBox Monitor installed from its release package on boot.

profile_sbm() {
	profile_standard
	profile_abbrev="sbm"
	title="sbOS"
	desc="ServerBox Monitor and Docker, on Alpine.
		Runs from the medium, or installs on a disk with sbm-install."
	arch="x86_64 aarch64"
	image_name="sbos"
	hostname="sbos"
	apkovl="genapkovl-sbm.sh"
	# The system: what the initramfs installs at boot and setup-disk on a
	# disk (/etc/apk/world). Docker for the web apps, openssl for the agent's
	# first certificate.
	SBM_WORLD="alpine-base openssh chrony tzdata ca-certificates curl openssl
		docker docker-cli-compose util-linux"
	# On the medium as well (not installed): what setup-disk adds to install
	# offline — partitioning, filesystems, bootloaders.
	apks="$apks $SBM_WORLD sfdisk e2fsprogs dosfstools grub grub-efi"
	# BIOS exists on x86 only.
	case "$ARCH" in
		x86_64) apks="$apks syslinux" ;;
	esac
	export SBM_WORLD
}
