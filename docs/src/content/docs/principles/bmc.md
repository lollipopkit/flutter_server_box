---
title: BMC (Redfish)
description: How out-of-band management reaches a server whose OS is not answering
---

:::caution[Read verified on one machine; power control on none]
Phase 1 is implemented and the read half has been run against real firmware —
see [Hardware this has run against](#hardware-this-has-run-against), which is
one model. Every other vendor difference below is handled against recorded
responses and a local TLS server: enough to be sure of the decisions, not
enough to be sure of a machine.

Power control has never been performed by anything automated, deliberately.
See the header of `packages/redfish/test/power_test.dart`.
:::

Every other way this app reaches a server needs the host operating system to be
running. SSH needs sshd; a monitor agent is a process on the machine. When the
host is powered off, hung, or mid-reboot, all of them report the same thing —
a connection failure — and the app has nothing further to say.

A BMC is the other path. It is a small computer on the motherboard with its own
power rail and its own network port, and it stays reachable when nothing else
on the machine is. It can answer three questions the host cannot answer about
itself: what the power state is, what the hardware sensors read, and what the
hardware event log holds.

## Why Redfish and not IPMI

| | Redfish | IPMI 2.0 over LAN |
|---|---|---|
| Transport | HTTPS + JSON | RMCP+ over UDP 623, binary |
| Cost in this repo | `dio`, no native code | no Dart implementation exists; a client in `crates/` behind FFI |
| Data model | self-describing, navigable | SDR / SEL / chassis commands, then vendor-specific raw bytes |
| Auth | TLS + a session token | RAKP, with weaknesses firmware cannot fix |
| Hardware | roughly 2016 and later | older and entry-level too |
| Spec | active | last revised 2013 |

IPMI's remaining advantages are pre-Redfish hardware and Serial-over-LAN.
Neither is worth an FFI client and a second security model here, so **IPMI is
not implemented and not planned**. If pre-Redfish hardware turns out to matter,
that is a new decision with its own justification, not a phase of this one.

## Where it sits in the model

A BMC is not a way of reaching the host, so it is not on the
`ServerConnectCredential` axis — that axis answers "where does this server's
*status* come from", and a `ServerCapabilities` implementation exists per
transport on it. A BMC answers about the machine when the host is absent.

It is a side channel, modelled the way Wake-on-LAN already is: an optional
nested config on `Spi`, beside `wolCfg`.

```dart
class Spi {
  SshCredential? ssh;
  MonitorHttpCredential? monitorHttp;
  WakeOnLanCfg? wolCfg;
  BmcCfg? bmc;          // ← null when not configured
}

final class BmcCfg {
  String addr;          // https://...
  String? credId;       // → BmcCredential, shared between servers
  String? certSha256;   // reviewed and pinned — see below
}

class BmcCredential {   // its own table, its own sync root
  String id;            // generated; never the name
  String name;          // unique, what the picker lists
  String user;
  String? pwd;
}
```

Nested rather than flat fields on `ServerCustom` (where PVE's three settings
live): flat cannot express "not configured", which is the same reason the SSH
fields were extracted into `SshCredential`.

The account is a record of its own, referenced by id. BMCs are provisioned a
rack at a time and answer to one directory or one factory password, so the
normal case is many servers to one account — stored per server it would be
typed once per machine and, on a rotation, changed once per machine, with no
way to tell whether one was missed except by a machine that stops answering.
The reference is `ON DELETE SET NULL`: losing an account must not lose the
servers that used it.

What stays on `BmcCfg` is what belongs to one device. The address, obviously —
and the certificate fingerprint, less obviously: two BMCs never present the
same certificate, so a fingerprint on a shared record would be the first
device's used to verify the second, which is the check not happening at all.

A shared *account* is not a shared *BMC*. Several servers that are guests of
one physical host would be pointing at one device, where a power action on any
of them cuts all of them and the reported `PowerState` is the host's rather
than the guest's. That is a host/guest relation, not a storage question, and it
is not modelled here.

## Layers

The split exists so that the half worth testing does not need a server.

```
BmcCfg + BmcCredential    what the user configured
  ↓
RedfishClient             transport: TLS trust, session lifetime, GET/POST
  ↓
RedfishService            one-time discovery, cached: which ids, which schemas
  ↓
redfish/*.dart (pure)     JSON → typed models, no IO
  ↓
BmcNotifier (riverpod)    state, and a poll cycle of its own
```

Only `RedfishClient` touches the network. Everything below it takes a decoded
JSON map and returns a model, which is what makes vendor differences testable
against saved responses instead of against hardware.

## TLS: trust on first use, not "ignore the certificate"

BMCs ship self-signed certificates. There are two existing places in this app
that meet a self-signed HTTPS endpoint — a monitor agent and PVE — and both
offer the user a switch that sets `badCertificateCallback` to accept anything.

That is not extended here. A BMC sits on a management network and holds power
control; turning verification off for it means accepting any certificate from
anything answering on that address.

Instead it works the way SSH host keys already do in this app
(`HostKeyVerifier`): the certificate's SHA-256 fingerprint is recorded the
first time it is seen, after the user agrees; a fingerprint that later differs
raises the question again and names both; a refusal is never recorded. The
verifier is written to be reusable, so PVE and the monitor agent can adopt it
later — but changing their behaviour is a separate decision, and this page is
not it.

## What varies between vendors

Everything in this section is a thing that has to be discovered rather than
assumed. A client that hardcodes any of it works on the machine it was written
against and fails on the next one.

### Resource ids are not stable

The service root is the only fixed path. Below it, the id of the system and of
the chassis differs by vendor:

| Vendor | Typical system id |
|---|---|
| Supermicro | `1` |
| Dell iDRAC | `System.Embedded.1` |
| OpenBMC | `system` |

So a client walks `/redfish/v1/Systems` and reads the collection's `Members`,
rather than building a path.

### There are two sensor models, and both may be present

Redfish 2020.4 deprecated `Chassis/{id}/Thermal` and `/Power` in favour of
`ThermalSubsystem`, `PowerSubsystem` and a unified `Sensors` collection.
Firmware lags the schema by years and unevenly — Supermicro switched at the X14
generation, so X11 through X13 still present the old model.

Transitional firmware exposes **both**. The rule: look at which links the
`Chassis` resource actually has, prefer the new model where it exists, fall
back to the old one, and never assume from the vendor name.

### `ResetType` is advertised, which is not the same as implemented

`ComputerSystem.Reset` takes a `ResetType`, and the values a given service
accepts are in `ResetType@Redfish.AllowableValues` on the action. They differ
per vendor, and `Nmi` and `PowerCycle` in particular are commonly advertised
but unimplemented or license-gated.

An intent — "restart this machine" — is therefore mapped onto whatever the
service allows, with a fallback chain, and an intent with nothing to map onto
is not offered in the UI at all.

### `ResetType` may be a name the specification does not have

An H3C R5350 G6 advertises `ForcePowerCycle`, which is not in the Redfish
`ResetType` enum, and advertises nothing else that cuts power. Matching only
the standard names meant the power-cycle intent fell through to
`ForceRestart` — a different operation, under a button that said power cycle.

So the candidate list per intent carries vendor names as fallbacks, after the
standard ones. Measured, not read: this is the kind of thing that only appears
when a real machine answers.

### A sensor with nothing to say may not say null

The specification suggests `null` for a sensor that has no reading. Some
firmware sends a sentinel instead. The same H3C reports `4294967295` —
`0xFFFFFFFF`, unsigned -1 — for every temperature it cannot read, which was 18
of its 20. Taken at face value that reaches the UI as `4294967295 Cel`.

Readings are therefore filtered by plausibility rather than by matching known
sentinels: the next vendor's is `65535` or `127`, and a list of them is always
one short. Nothing real falls in the gaps — a chassis sensor below absolute
zero or above a thousand degrees is not a reading, and no fan turns at four
billion RPM.

The limit is deliberate. `-1` is a sentinel for some firmware and is also what
a cold inlet reads, so it is kept: deleting a real measurement to hide a fake
one is the worse of the two mistakes, and the only one nobody can see.

### HPE iLO's graceful operations are advisory

HPE documents that the behaviour of `GracefulShutdown` and `GracefulRestart`
depends on the OS, and that iLO does not distinguish them at the OS level. A
`204 No Content` therefore means the request was accepted, not that anything
happened.

Power operations are confirmed by polling `PowerState` until it changes or a
timeout expires — the HTTP status is not the result.

### Sessions leak, and the limit is low

Redfish session auth is a `POST` to `SessionService/Sessions`, which returns an
`X-Auth-Token`. A session that is never deleted stays on the BMC until its
timeout, and BMCs allow few concurrent sessions — enough leaked sessions lock
the management interface out entirely until the timeout expires or the BMC is
reset by hand.

So: one login per client, `DELETE` of the session resource when the client is
disposed, on the failure path as much as the normal one. A single unauthenticated
probe of the service root needs no session at all.

### Licensing gates some of it

Supermicro's `SFT-OOB-LIC` / `SFT-DCMS-SINGLE` keys gate firmware update and
virtual media rather than reads, and in practice read-only GETs and
`ComputerSystem.Reset` work without them on X11 through X13 — but that is field
experience rather than documented policy.

Which means a `401` or `403` on a sub-resource is an ordinary answer to be
reported, not a bug and not a reason to fail the whole fetch.

## Polling

A BMC is slow; a single thermal fetch can take seconds. It gets a cycle of its
own rather than riding on the status poll, the same way the extended status
commands are split out from the fast one (`_extendedStatusInterval`).

Discovery — which ids, which sensor model, which reset types — happens once per
client and is cached. Re-deriving it on every poll is work the device can least
afford.

## What Phase 1 covers

- Detection: `GET /redfish/v1/` and the collections below it
- `Systems/{id}`: power state, model, serial, BIOS version, health rollup
- `Chassis/{id}`: temperatures, fan speeds, power draw, by whichever sensor
  model the firmware presents
- `ComputerSystem.Reset`, behind a confirmation dialog, with the reset type
  negotiated and the result confirmed by polling

Not in Phase 1: the event log, storage inventory, boot device override, virtual
media, and relaying Redfish through a monitor agent for BMCs on a management
network a phone cannot route to.

## Hardware this has run against

One machine, and it is worth being exact about that: the table below is what
has answered, not what is supported. Everything else in this page comes from
vendor documentation and recorded responses, which is a different kind of
confidence — the two entries under [What varies between
vendors](#what-varies-between-vendors) marked as measured are the ones that
came from here, and both were things no amount of reading had turned up.

| | |
| --- | --- |
| Model | H3C R5350 G6 |
| BIOS | 6.30.50 |
| Redfish version | 1.15.1 |
| `Vendor` / `Product` at the root | **both absent** — do not rely on them to identify a service |
| System id | `Systems/1` |
| Chassis id | `Chassis/1` |
| Sensor model | legacy (`Thermal` + `Power`). `Sensors` is linked but `ThermalSubsystem` is not, so the modern model is not fully present and is correctly not used |
| `ResetType` allowed | `ForceOff`, `ForcePowerCycle`, `ForceRestart`, `GracefulShutdown`, `Nmi`, `On` |
| Temperatures | 20 reported, 18 of them the `0xFFFFFFFF` sentinel |
| Fans | 8 positions, each reported twice with different readings — dual rotor, and the two share a name |
| Chassis power | 48 W reported through `PowerControl` |
| Sessions | one open while one client is connected; released on close |
| Certificate | self-signed, within its validity dates |
| Run | 2026-08-23 |

What that does **not** cover, and what to add a row for when someone has one:
Dell (`System.Embedded.1`), OpenBMC (`system`), Supermicro X11–X13 against X14
(the sensor-model switch), HPE iLO's graceful operations, and any machine that
publishes more than one system.

## Checking it against real hardware

Everything above is verified against recorded vendor responses and a local TLS
server, which settles the decisions and settles nothing about a machine. Two
things are left to a person.

**The read half** is `packages/redfish/test/e2e_test.dart`, opt-in and read-only. It
skips silently unless the workspace-root `.env` carries:

```
SBM_E2E_BMC_URL=https://10.0.0.9
SBM_E2E_BMC_USER=...
SBM_E2E_BMC_PWD=...
```

It prints what it found rather than asserting a shape — the id this vendor uses,
which sensor model the firmware presents, which reset types it advertises and
what each intent resolves to. A fourth id shape is something to learn, not a
failure. It reads the reset action and **never posts to it**.

**The power half** has no automated form and is not going to get one. To check
it by hand, on a machine nobody is using:

1. Configure the BMC on that server and review its certificate.
2. Confirm the card shows a power state matching the machine.
3. Press *Restart*. The dialog names the `ResetType` that was negotiated —
   check it is the one that hardware should be getting.
4. Watch that the result reported is *confirmed* rather than *accepted*. On iLO
   a graceful operation may legitimately report accepted; on hardware that does
   distinguish them, accepted means the machine did not move and is worth
   looking into.
