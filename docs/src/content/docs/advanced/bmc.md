---
title: BMC (Redfish)
description: Configure and use out-of-band management when the host is unavailable
---

:::caution[Beta]
Only the read path (power state and sensors) has been verified against one real device. Power control has no automated verification yet. Compatibility with other vendors and models still needs to be established; see [Hardware tested](/docs/principles/bmc/#hardware-tested).

Treat power operations like pressing a physical power button on a remote server.
:::

A BMC (Baseboard Management Controller) is an independent computer on the server motherboard with its own power and network connection. It can respond when the host is powered off, hung, or has no operating system installed. SSH and Monitor agent cannot work in those situations.

Server Box communicates with the BMC through **Redfish**, a common HTTPS API for enterprise servers. Devices that support only IPMI are outside the current scope; see [BMC design](/docs/principles/bmc/) for the reason.

## What it provides

- **Power state**: Determine whether a host is on or off even when SSH and Monitor agent are unreachable.
- **Hardware sensors**: Read inlet and CPU temperatures, fan speeds, and chassis power draw from the BMC rather than the operating system.
- **Power control**: Power on a host, request an operating-system shutdown or restart, or perform a power cycle or force-off operation.

BMC is a complementary management path, not a replacement for SSH. A server can have SSH, Monitor agent, and BMC configured at the same time.

## Configure a BMC

1. Open the server edit page and find **BMC (Redfish)**.
2. Enter the BMC's address, not the host operating system's address, for example `https://10.0.0.9`. Enter only the scheme, host, and port; the App handles the Redfish path.
3. Select an existing BMC account or create one.
4. Open **Certificate**, compare the fingerprint with the one shown by the BMC's own web interface, and accept it only after verifying the device.
5. Save the server configuration.

The server detail page then shows a BMC card and hardware-level power operations.

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
