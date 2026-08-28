---
title: Terminal on This Device
description: Open a shell on the device running Server Box
---

When the current build includes the relevant capability, the terminal tab lists a shell on **this device** and a Linux userland provided by Server Box before the remote servers.

They appear first because the device is always reachable and these entries do not require credentials.

## Shell on this device

This shell runs on the device where Server Box is running. On platforms that support choosing a shell, the App uses `$SHELL`, so it is normally the same shell opened by your terminal app.

| Platform | Availability |
|---|---|
| Linux, Windows | Available |
| macOS (DMG build) | Available |
| macOS (App Store build) | Not available |
| Android | Available, with different shell capabilities from desktop |
| iOS | Not available |

**The App Store macOS build cannot provide a local shell.** It runs in a sandbox, and a sandboxed process cannot open a pseudo-terminal, so the App omits this entry. The DMG build is not sandboxed and can provide it. The App checks the running build, so the UI reflects the actual sandbox restriction.

**iOS does not provide a local shell.** An App Store App cannot start processes, and its sandbox contains no `/bin/sh` to start.

## Alpine Linux userland

If a platform does not provide a shell, or its local shell is limited, Server Box can install an independent Linux userland. The default release is currently Alpine 3.22.5, and other releases may be available in the App's release list.

It appears in the terminal tab as **Alpine <version>**, beside the local shell because both run on the same device. When an update is available, the entry offers the newer release.

Android and iOS use different implementations:

- **Android**: Unpacks a real Linux rootfs and enters it with `proot`. Current builds support arm64; the rootfs is downloaded as a tarball and verified against a pinned digest.
- **iOS**: Cannot start processes directly, so the App includes a Linux interpreter. The userland is the filesystem used by that interpreter.

**These features depend on the build configuration.** A build may provide only the local shell, only the Alpine userland, both, or neither. If the entry is missing from the terminal tab, the current build does not include that capability.

### Use cases

- Use `curl`, `dig`, `ssh`, or `jq` on a phone that does not include them.
- Perform temporary work that you do not want to run directly on a production server.
- Give Agent an execution target isolated from the device filesystem; see [Agent](/docs/advanced/agent/).

The Alpine userland is a standard Alpine environment, so `apk add` can install packages.

### Filesystem isolation

The Alpine userland has its own filesystem and cannot read phone storage, App data, private keys, or user files. This is why **Run commands on this device** means different things on mobile and desktop: mobile uses an isolated userland, while desktop uses the computer's own shell.

## Differences from a server terminal

The terminal emulator, virtual keyboard, and tabs are shared. Only the source of the byte stream changes.

A local shell does not verify a host key and does not reconnect like a server connection. It does not appear in the server list or status charts: it is a terminal session, not a monitored server.
