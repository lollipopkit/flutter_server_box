# sbOS

ServerBox Monitor and Docker as a bootable system. Two flavours, one
behaviour:

| Image | Based on | Init | Boots |
|---|---|---|---|
| `sbOS_musl_x64.img`, `sbOS_musl_arm64.img` | Alpine Linux 3.24 | OpenRC | x64 BIOS and UEFI, arm64 UEFI |
| `sbOS_GNU_x64.img`, `sbOS_GNU_arm64.img` | Debian 13 | systemd | x64 BIOS and UEFI, arm64 UEFI |

Write one to a USB stick (`dd`, Etcher, Ventoy) or boot it in a virtual
machine. sbOS is not affiliated with Alpine Linux or Debian; Debian is a
registered trademark owned by Software in the Public Interest, Inc. See
[`common/NOTICE`](common/NOTICE) (also in the image, in
`/usr/share/server-box-monitor/`).

## Using it

On boot the console shows:

```
sbOS: ServerBox Monitor at https://192.168.1.20:3770
Certificate SHA-256: 3A:9F:...
First password (as root): cat /home/sbm/.local/share/server-box-monitor/initial-admin-credentials.txt
```

- The agent listens over HTTPS with a self-signed certificate made on the
  machine's first boot. The browser warns about it; compare the fingerprint
  with the one on the console before accepting it. Another certificate:
  `SBM_TLS_CERT`/`SBM_TLS_KEY` in the agent's `.env`.
- The console is a root shell without a password (sshd refuses an empty one).
  Set a root password if others can reach the console.
- The agent runs as the account `sbm` (in the `docker` group), installed by
  `install.sh` in its default form: an OpenRC service with `command_user` on
  musl, a systemd user service (lingering) on GNU. `install.sh upgrade` and
  `uninstall` work as documented in `monitor/README.md`.

### Live or installed

Booted from the medium the system runs from RAM: the database, Docker's images
and the apps' data are gone after a reboot. To keep them, install it on a disk:

```sh
sbm-install /dev/sda      # erases the disk; asks you to type its name
```

The agent installs itself again on the disk's first boot, with a new database
and a new certificate.

- musl: Alpine's `setup-disk -m sys`. The system's packages come from the
  medium, the kernel and firmware from Alpine's mirror (the network is
  needed); `/etc` is carried over.
- GNU: the image's root filesystem is copied as it was built (no network
  needed), with GRUB for UEFI and, on x64, BIOS.

## Building it

Docker is the only requirement (macOS or Linux):

```sh
./build.sh musl                         # the host's arch, the version in monitor/Cargo.toml
./build.sh gnu --arch arm64 --version 0.2.0
./build.sh gnu --pkg path/to/server-box-monitor_v0.2.0_linux_amd64.tar.gz
```

Without `--pkg`, the release tarball of that version is downloaded and checked
against its `SHA256SUMS`. The output in `out/`: the image, its `.sha256`, and
`.packages.txt`, which lists every distribution package inside and where its
source is (Alpine's aports commit and distfiles; snapshot.debian.org at the
build's date). Another architecture than the host's needs qemu's binfmt
(`docker run --privileged --rm tonistiigi/binfmt --install arm64`).
`monitor-release.yml` builds all four and attaches them to the release.

| Path | Role |
|---|---|
| `build.sh` | Fetches the package, adds this checkout's `install.sh`, runs the flavour's build in a container |
| `common/sbm-setup` | On boot (both): the account, the certificate, `install.sh install` when missing, the console text |
| `common/NOTICE` | Trademarks, licences, where the sources are |
| `musl/mkimage.sh` | In `alpine:3.22`: aports' `mkimage.sh` (pinned commit) with the `sbm` profile |
| `musl/profile/` | The package list (`SBM_WORLD`: the system; `apks`: the medium) and the overlay |
| `musl/overlay/` | OpenRC's `sbm-setup`, `sbm-install`, what `setup-disk` carries (`protected_paths.d`) |
| `gnu/mkimage.sh` | In `debian:trixie` (privileged): live-build, its package list and hook |
| `gnu/includes/` | systemd units (`sbm-setup`, network, host keys, Docker's live data), `sbm-install` |

Moving to a new release: musl `ALPINE_BRANCH` and `APORTS_COMMIT` in
`musl/mkimage.sh` (`alpine:3.22` stays until aports' `mkimage.sh` stops
passing `apk add --no-chown`, which apk-tools 3 refuses as root); GNU `SUITE`
in `gnu/mkimage.sh` and the container in `build.sh`.
