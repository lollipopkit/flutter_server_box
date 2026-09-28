---
title: Terminal on This Device
description: Open a shell on the device running Server Box
---

When supported by the current build, the terminal tab shows local execution
options before your remote servers: a shell on **this device** and a Linux
userland provided by Server Box.

These entries need no server connection or credentials.

## Shell on this device

This shell runs on the computer or device that runs Server Box. Where shell
selection is supported, the App starts the shell named by `$SHELL`, which is
usually the one your terminal app opens.

| Platform | Availability |
|---|---|
| Linux, Windows | Available |
| macOS (DMG build) | Available |
| macOS (App Store build) | Not available |
| Android | Available, with different shell capabilities from desktop |
| iOS | Not available |

**The macOS App Store build has no local shell.** Its sandbox prevents the App
from opening a pseudo-terminal, so the local-shell entry is hidden. The DMG
build can provide a shell. Server Box checks which build is running and shows
the entry only when that build supports it.

**iOS has no local shell.** App Store apps cannot start processes, and the
sandbox does not contain a `/bin/sh` executable.

## Linux userland

If the platform has no shell or its shell is limited, Server Box can install
an independent Linux userland. Alpine 3.22.5 is currently the default; the
release list may also include other distributions and versions, such as Debian
or Ubuntu.

The terminal tab labels it **<distribution> <version>** and lists it beside
the local shell. Choose the distribution and version when installing. Updating
keeps the existing profile and does not offer a different choice.

Android and iOS use different implementations:

- **Android:** Unpacks a Linux rootfs and enters it with `proot`. Current
  builds support arm64. The App downloads the rootfs as a tarball and checks
  it against a pinned digest.
- **iOS:** The App cannot start processes directly, so it includes a Linux
  interpreter. The userland is the filesystem that interpreter runs against.

**These features depend on the build configuration.** A build may provide only the local shell, only the Alpine userland, both, or neither. If the entry is missing from the terminal tab, the current build does not include that capability.

### Use cases

- Use `curl`, `dig`, `ssh`, or `jq` on a phone that does not include them.
- Perform temporary work that you do not want to run directly on a production server.
- Give Agent an execution target isolated from the device filesystem; see [Agent](/docs/advanced/agent/).

Each userland follows its distribution's standard layout and package manager.
For example, install packages with `apk add` on Alpine or `apt install` on
Debian and Ubuntu.

### Filesystem isolation

The Alpine userland has a separate filesystem. It cannot read phone storage,
App data, private keys, or user files. As a result, **Run commands on this
device** targets different environments: the isolated userland on mobile and
the computer's own shell on desktop.

## Differences from a server terminal

The local terminal uses the same terminal emulator, virtual keyboard, and tabs
as a server session. Only the source of terminal input and output changes.

Because it runs locally, this shell has no server host key to verify and does
not reconnect as a server session would. It is not added to the server list
and has no status charts.
