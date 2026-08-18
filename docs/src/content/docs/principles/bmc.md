---
title: BMC (Redfish)
description: How out-of-band management reaches a server whose OS is not answering
---

:::caution[Not shipped yet]
This page describes a design being built, not behaviour you can use today. It
is here because the vendor differences below are what the implementation has to
be shaped around, and they are worth writing down once rather than rediscovering
per pull request. Anything stated in the present tense is what the code will do,
not what it does.
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
  String user;
  String? pwd;
  String? certSha256;   // pinned on first sight — see below
}
```

Nested rather than flat fields on `ServerCustom` (where PVE's three settings
live): flat cannot express "not configured", which is the same reason the SSH
fields were extracted into `SshCredential`.

## Layers

The split exists so that the half worth testing does not need a server.

```
BmcCfg                    what the user configured
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
