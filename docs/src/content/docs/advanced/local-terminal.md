---
title: Terminal on This Device
description: Open a shell on the machine running ServerBox
---

The terminal tab lists two things before your servers, when the build offers
them: a shell on **this device**, and a Linux container ServerBox installs.

Both are listed first for the same reason the file tab lists this device first —
it is always reachable, and it needs no credential to be.

## This device

A shell on the machine ServerBox is running on. It uses `$SHELL` where the OS
says which shell you chose, so it is the same shell your terminal app opens.

Where it is available:

| Platform | Available |
|---|---|
| Linux, Windows | yes |
| macOS (DMG build) | yes |
| macOS (App Store build) | no |
| Android | yes, though a phone's shell is a good deal less than a desktop's |
| iOS | no |

**The App Store macOS build cannot offer one.** It has to be sandboxed, and a
sandboxed process cannot open a pseudo-terminal — so the entry is simply absent
rather than present and broken. The DMG build is signed without the sandbox and
does have one. The app asks the running process rather than deciding at build
time, so a single binary is honest in both cases.

**iOS has none** for a stronger reason: an App Store app cannot start a process
at all, and there is no `/bin/sh` in its container to start.

## The Alpine container

Where the platform will not give a shell, or gives a thin one, ServerBox can
install a Linux userland of its own — Alpine 3.22.5, the same release on both
platforms.

It appears in the terminal tab as **Alpine \<version\>**, beside this device
rather than among the servers, because that is what it is: the same machine,
with a userland this app installed. When a newer release is pinned than the one
on disk, the entry offers the update.

Two platforms, two mechanisms:

- **Android** unpacks a real root filesystem and enters it with `proot`. It is
  arm64 only, and the rootfs is a tarball fetched over the network and then run,
  so its digest is pinned and checked.
- **iOS** cannot start a process, so it carries an interpreter, and the
  container is that interpreter's filesystem.

**Both are absent unless the build ships them.** Neither mechanism is included
by default, so a build may offer this device, the container, both, or neither —
the terminal tab is written to expect any of those. If you do not see it, your
build does not have it.

### What it is good for

- A `curl`, `dig`, `ssh` or `jq` on a phone that has none
- Scratch work you would rather not do on a production host
- A target for the Agent that is not your own filesystem — see
  [Agent](/docs/advanced/agent/)

It is an ordinary Alpine, so `apk add` works.

### What it cannot see

The container has its own filesystem. It cannot read the phone's storage, the
app's own data, your private keys or your files. That containment is why the
Agent's "run commands on this device" switch reads differently on mobile than on
desktop: on a phone it is offering a sandbox, on a desktop it is offering your
computer.

## How it differs from a server

Everything above the byte stream is the same — the same terminal emulator, the
same virtual keyboard, the same tabs. What changes is where the bytes come from.

A local shell has no host key to verify, no reconnection, and no server card. It
also does not appear on the server list or in status charts: it is a terminal,
not a monitored machine.
