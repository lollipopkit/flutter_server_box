---
title: BMC (Redfish)
description: Configure and use out-of-band management when the host is unavailable
---

:::caution[Beta]
Only the read path (power state and sensors) has been verified against one real device. Power control has no automated verification yet. Compatibility with other vendors and models still needs to be established; see [Hardware tested](/docs/principles/bmc/#hardware-tested).

Treat power operations like pressing a physical power button on a remote server.
:::

A BMC (Baseboard Management Controller) is a small computer on the server's
motherboard. It has its own power and network connection, so it can remain
reachable when the host is off, unresponsive, or has no operating system. SSH
and Monitor agent depend on the host, so they cannot provide access in those
states.

Server Box connects to the BMC through **Redfish**, an HTTPS management API
used by enterprise servers. BMCs that expose only IPMI are not supported; see
[BMC design](/docs/principles/bmc/) for the design rationale.

## What it provides

- **Power state:** Check whether the host is on or off, even if SSH and Monitor
  agent are unavailable.
- **Hardware sensors:** Read inlet and CPU temperatures, fan speeds, and
  chassis power draw reported by the BMC.
- **Power control:** Turn on the host, ask its operating system to shut down or
  restart, or directly power-cycle or force it off.

Use BMC alongside SSH; it does not replace normal host access. You can
configure SSH, Monitor agent, and BMC on the same server.

## Configure a BMC

1. Open the server's edit page and locate **BMC (Redfish)**.
2. Enter the BMC address, not the host's operating-system address. For
   example, use `https://10.0.0.9`; enter the scheme, host, and port only. The
   App adds the Redfish path.
3. Choose a saved BMC account or create one.
4. Open **Certificate** and compare its fingerprint with the value shown in
   the BMC's web interface. Accept it only after confirming the device.
5. Save the server.

The server detail page will show a BMC card with its reported state and
hardware-level power controls.

## BMC accounts

A BMC account is a separate record, so you do not need to enter the username and password repeatedly for each server. BMCs in one rack commonly share an account; changing it once updates every server that references it.

Manage accounts at **Settings → BMC accounts**. Each account shows how many servers use it, because editing the account affects all of them.

Deleting an account does not delete the servers that reference it. Those servers keep the BMC address but no longer have a usable account; the edit page indicates that state.

## Certificate verification

BMCs commonly use self-signed certificates. Server Box does not provide an “ignore certificate” option here: a BMC has power-control authority, and disabling verification would allow another service at that address to impersonate it.

The App uses a trust-on-first-use flow similar to SSH host-key verification:

1. The first connection shows the certificate fingerprint.
2. Compare it with the fingerprint shown by the BMC web interface and confirm it.
3. The App stores the accepted fingerprint and accepts only a matching certificate later.
4. If the fingerprint changes, the App refuses the connection, shows the old and new values, and asks you to verify the device again.

A BMC may legitimately change its fingerprint after regenerating a certificate or upgrading firmware. A man-in-the-middle attack produces the same symptom, so verify the BMC before accepting a new certificate.

Some BMCs ship with expired certificates. The App reports the expiry but still lets you accept the certificate after you have verified the device identity.

## Power operations

Power operations either ask the operating system to act or operate on the hardware directly:

| Operation | Through the OS | Effect |
|---|---|---|
| Shut down | Yes | Requests an OS shutdown; requires a running OS |
| Restart | Yes | Requests an OS restart |
| Power on | No | Powers on a host that is off |
| Force off | No | Cuts power; unsaved data is lost and filesystems are not cleanly unmounted |
| Power cycle | No | Turns power off, then on again |

**A graceful shutdown or restart is an accepted request, not proof of completion.** The App polls the BMC's reported power state instead of trusting a successful HTTP response. Some firmware accepts a request even when the operating system does not act on it.

If the power state does not change before the wait expires, the App reports *accepted*, not *confirmed*. *Accepted* means the BMC received the request; *confirmed* means the App observed the expected state change.

The supported `ResetType` values vary by BMC. The App reads the device's advertised operations and shows only operations that the device exposes.

## Current limitations

The following features are not implemented:

- Event logs
- Storage inventory
- Boot-device override
- Virtual media
- Relaying BMC access through Monitor agent

If a BMC is on an isolated management network, the phone must be able to route to it directly. Monitor agent cannot currently proxy BMC access.

The App does not model physical-host and virtual-machine relationships. Several virtual machines may point to one physical host's BMC; a power operation from any of them affects the entire physical host and all its guests, and the reported power state belongs to the host. Configure BMC on the physical-host record only.
