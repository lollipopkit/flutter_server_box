# shellcheck disable=SC2034  # read by mkimage.sh
# The ServerBox Monitor image: Alpine's standard ISO (BIOS and UEFI) with
# Docker, and the agent installed from its release package on boot.

profile_sbm() {
	profile_standard
	profile_abbrev="sbm"
	title="ServerBox Monitor"
	desc="Alpine with ServerBox Monitor and Docker.
		Runs from the medium, or installs on a disk with sbm-install."
	arch="x86_64 aarch64"
	image_name="server-box-monitor"
	hostname="serverbox"
	apkovl="genapkovl-sbm.sh"
	# The system: what the initramfs installs at boot and setup-disk on a
	# disk (/etc/apk/world). Docker for the web apps, openssl for the agent's
	# first certificate.
	SBM_WORLD="alpine-base openssh chrony tzdata ca-certificates curl openssl
		docker docker-cli-compose util-linux"
	# On the medium as well (not installed): what setup-disk adds to install
	# offline — partitioning, filesystems, bootloaders.
	apks="$apks $SBM_WORLD sfdisk e2fsprogs dosfstools grub grub-efi syslinux"
	export SBM_WORLD
}
