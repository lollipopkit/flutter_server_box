---
title: BMC (Redfish)
description: Reach a server's baseboard management controller when the host is not answering
---

A BMC is a small computer on the server's motherboard with its own power rail
and its own network port. It answers while the host is off, hung, or has no
operating system on it at all — which is the one thing SSH and a monitor agent
cannot do.

ServerBox talks to it over **Redfish**, the HTTPS API most enterprise hardware
from roughly 2016 on provides. Older machines that only speak IPMI are not
supported; see [How it works](/principles/bmc/) for why that line is where it
is.

## What it gives you

- **Power state while the server is unreachable.** `Power: on` means the
  machine is running and something else is wrong; `Power: off` means it is off.
  Those are different problems and the server card cannot otherwise tell them
  apart.
- **Hardware sensors** — inlet and CPU temperatures, fan speeds, chassis power
  draw — read from the BMC rather than from inside the OS.
- **Power control**: power on a machine that is off, and shut down, restart,
  power cycle or force off one that is not responding.

A BMC sits *beside* SSH rather than instead of it. One server can have both,
and normally does.

## Setting one up

1. Open the server's edit page and find the **BMC (Redfish)** section.
2. **Address** — the BMC's own address, not the host's. `https://10.0.0.9`.
   Only the scheme, host and port are used; the rest of the path is fixed by
   the specification.
3. **Account** — pick one, or create one. See below.
4. **Certificate** — tap it, compare what is shown against what the BMC's own
   web interface reports, and accept.

The BMC card then appears on the server's detail page, and the power button
gains the hardware operations.

## Accounts are shared

A BMC account is a record of its own, not a username and password typed into
each server. BMCs are provisioned a rack at a time and usually answer to one
account, so twenty machines share one — and rotating that password is one edit
rather than twenty.

Manage them at **Settings → BMC accounts**. Each entry shows how many servers
use it, because editing one changes what all of them use.

Deleting an account does not delete the servers that used it. They keep their
address and lose the account, which the editor then says.

## The certificate

BMCs ship self-signed certificates, so there is nothing for a certificate
authority to vouch for. ServerBox does not offer an "ignore the certificate"
switch here — a management interface holding power control is the worst place
to have one.

Instead it works the way SSH host keys already do in this app: you look at the
certificate once and accept it, and from then on only that exact certificate is
accepted.

**Compare the fingerprint against the BMC's own web interface before
accepting.** That is the step that makes this worth anything.

If the fingerprint later changes, the app refuses the connection and says so.
That happens legitimately when a BMC regenerates its certificate or its
firmware is updated — and it is also what an interception looks like. Check
before accepting the new one.

Many BMCs ship certificates that expired years ago. ServerBox says so and lets
you accept anyway; refusing them would refuse most of the hardware this is for.

## Power operations

The power button offers the OS operations and the hardware ones together.
They are not the same thing:

| | Goes through the OS | Effect |
|---|---|---|
| Shut down | yes | asks the OS to shut down; needs a running OS |
| Restart | yes | asks the OS to restart |
| Power on | no | the only one that works on a machine that is off |
| Force off | no | cuts power. Unsaved work is lost, filesystems are not unmounted |
| Power cycle | no | off, then on |

**A graceful operation is a request, not a result.** ServerBox sends it and
then watches the reported power state rather than trusting the HTTP response —
some firmware accepts a graceful shutdown and reports success without the OS
having done anything. When the state does not move within the wait, the app
reports *accepted* rather than *confirmed*, and means it.

What the service actually allows differs per vendor, and ServerBox asks rather
than assumes: an operation this machine has no equivalent for is not offered at
all, instead of failing when pressed.

## What is not here

The event log, storage inventory, boot device override and virtual media are
not implemented. Neither is reaching a BMC through a monitor agent, which is
what a BMC on an isolated management network would need — the phone has to be
able to route to the BMC directly.

Guests of one physical host are not modelled. Several virtual machines running
on one server would all point at that server's BMC, where a power operation on
any of them cuts all of them and the reported power state is the host's rather
than the guest's. Configure the BMC on the host.
