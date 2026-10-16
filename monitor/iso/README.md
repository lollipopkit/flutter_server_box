# ServerBox Monitor image

An Alpine Linux 3.24 ISO (x86_64 BIOS/UEFI, aarch64 UEFI) with Docker and the
ServerBox Monitor agent. Write it to a USB stick (`dd`, Etcher, Ventoy) or boot
it in a virtual machine.

## Using it

On boot the console shows:

```
ServerBox Monitor: https://192.168.1.20:3770
Certificate SHA-256: 3A:9F:...
First password (as root): cat /home/sbm/.local/share/server-box-monitor/initial-admin-credentials.txt
```

- The agent listens over HTTPS with a self-signed certificate made on the
  machine's first boot. The browser warns about it; compare the fingerprint
  with the one on the console before accepting it. Replace it by pointing
  `SBM_TLS_CERT`/`SBM_TLS_KEY` in the agent's `.env` at another certificate.
- The console is a root shell. The first password is in the file above (only
  root and the agent's account can read it); change it after signing in.
- The agent runs as the account `sbm` (in the `docker` group), installed by
  `install.sh` as on any OpenRC machine: `install.sh upgrade` and `uninstall`
  work as documented in `monitor/README.md`.

### Live or installed

Booted from the medium the system runs from RAM: the database, Docker's images
and the apps' data are gone after a reboot. To keep them, install it on a disk:

```sh
sbm-install /dev/sda      # erases the disk; asks you to type its name
```

`sbm-install` runs Alpine's `setup-disk -m sys`: the system's packages come
from the medium, the kernel and firmware from Alpine's mirror (the network is
needed). The configuration under `/etc` is carried over;
the agent installs itself again on the disk's first boot, with a new database
and a new certificate.

## Building it

Docker is the only requirement (macOS or Linux):

```sh
./build.sh                          # the version in monitor/Cargo.toml, the host's arch
./build.sh --version 0.2.0 --arch x86_64
./build.sh --pkg path/to/server-box-monitor_v0.2.0_linux_amd64.tar.gz
```

Without `--pkg`, the release tarball of that version is downloaded and checked
against its `SHA256SUMS`. The output is `out/server-box-monitor-<version>-<arch>.iso`
and its `.sha256`. Another architecture than the host's needs qemu's binfmt
(`docker run --privileged --rm tonistiigi/binfmt --install arm64`).
`monitor-release.yml` builds both and attaches them to the release.

| Path | Role |
|---|---|
| `build.sh` | Fetches the package, adds this checkout's `install.sh`, runs the container |
| `mkiso.sh` | In the container: aports' `mkimage.sh` (pinned commit) with the `sbm` profile |
| `profile/mkimg.sbm.sh` | The package list: on the medium and the system's `/etc/apk/world` |
| `profile/genapkovl-sbm.sh` | The overlay: runlevels, network, the package in `/usr/share/server-box-monitor` |
| `overlay/etc/init.d/sbm-setup` | On boot: the account, the certificate, `install.sh install` when missing, the console text |
| `overlay/etc/apk/protected_paths.d/server-box-monitor.list` | Makes `setup-disk` carry the package to the disk |
| `overlay/usr/local/sbin/sbm-install` | `setup-disk -m sys` with a confirmation |

Moving to a new Alpine release: `ALPINE_BRANCH` and `APORTS_COMMIT` in
`mkiso.sh` (a commit of the matching `*-stable` branch). `BUILDER_IMAGE` in
`build.sh` stays older until aports' `mkimage.sh` stops passing
`apk add --no-chown`.
