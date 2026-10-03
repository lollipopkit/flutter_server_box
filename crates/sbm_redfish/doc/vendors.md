# What varies between vendors

Every entry here is something a client has to *discover* rather than assume.
Hardcode any of them and it works on the machine it was written against.

Two kinds of entry, kept apart on purpose:

- **Read** — from vendor documentation or a published mockup. Reliable about
  what a vendor says it does.
- **Measured** — observed on hardware listed under [Hardware this has run
  against](#hardware-this-has-run-against). These are the ones no amount of
  reading found.

## Resource ids are not stable — *read*

Supermicro uses `1`, Dell `System.Embedded.1`, OpenBMC `system`. None can be
derived from the others.

Walk `Systems` and `Chassis` and take what the collection lists. Never build a
path.

## There are two sensor models, and both may be present — *read*

Redfish 2020.4 deprecated `Thermal` and `Power` in favour of
`ThermalSubsystem`, `PowerSubsystem` and a unified `Sensors` collection.
Firmware follows unevenly — Supermicro switched at X14, so X11 through X13 are
still on the old one — and transitional firmware carries **both**.

Branch on which links the `Chassis` resource has. The new model wins where it
is fully present, which means `Sensors` *and* one of the two subsystems:
`Sensors` alone is not enough to read through the new path.

## `ResetType` is advertised, which is not the same as implemented — *read*

`ResetType@Redfish.AllowableValues` is a statement, not a guarantee. `Nmi` and
`PowerCycle` in particular are commonly listed and either unimplemented or
license-gated.

Negotiate an intent against the list with a fallback chain, and offer nothing
that maps to nothing. An operation with nothing behind it should not appear,
rather than appear and fail when pressed.

## `ResetType` may be a name the specification does not have — *measured*

An H3C R5350 G6 advertises `ForcePowerCycle`, which is not in the Redfish
`ResetType` enum, and advertises nothing else that cuts power. Matching only
standard names sent the power-cycle intent to `ForceRestart` — a different
operation.

Vendor names belong in the candidate chain, after the standard ones.

## A sensor with nothing to say may not say null — *measured*

The specification suggests `null`. Some firmware sends a sentinel instead. The
same H3C reports `4294967295` — `0xFFFFFFFF`, unsigned -1 — for every
temperature it cannot read, which was 18 of its 20.

Filter by plausibility rather than by matching known sentinels: the next
vendor's is `65535` or `127`, and a list of them is always one short. Nothing
real falls in the gaps — below absolute zero or above a thousand degrees is not
a chassis reading, and no fan turns at four billion RPM.

The limit is deliberate: `-1` is a sentinel for some firmware and is also what
a cold inlet reads, so it is kept. Deleting a real measurement to hide a fake
one is the worse of the two mistakes, and the only one nobody can see.

## Graceful operations are advisory — *read*

HPE documents that `GracefulShutdown` and `GracefulRestart` depend on the
operating system and that iLO does not distinguish them at the protocol level.
A `204` is acceptance, not a result.

Poll `PowerState` and report what it did, distinguishing *confirmed* from
*accepted*. A transitional state is not arrival.

## Sessions leak, and the limit is low — *read, and measured*

BMCs allow few concurrent sessions — about four is typical. Enough leaked ones
lock the management interface out until they time out or someone resets the
device by hand, and that failure looks like the device being broken rather than
like the client that caused it.

One login per client, `DELETE` on the failure path as much as the normal one,
and wait for a login still in flight before closing — otherwise the session it
is about to create is created after the delete.

## Licensing gates some of it — *read*

Supermicro's licenses gate firmware update and virtual media, not reads. A
`401` or `403` on a sub-resource is an ordinary answer about that resource, not
grounds to fail the whole fetch.

## The service root may not identify itself — *measured*

`Vendor` and `Product` are both absent on the H3C. They are free text and worth
displaying, but nothing may be decided by them.

## Allowable values may be in an `ActionInfo` — *measured*

OpenBMC's bmcweb lists nothing inline on `#ComputerSystem.Reset`: the action
carries `@Redfish.ActionInfo` instead, and the `ResetType` parameter of that
resource holds the allowable values. A client that reads only
`ResetType@Redfish.AllowableValues` offers no power action on an OpenBMC
machine at all — which the Dart client did. Read the inline list, and the
`ActionInfo` when it is empty.

# Hardware this has run against

Two services, one of them emulated. This is what has answered, not what is supported — everything
marked *read* above comes from documentation, which is a different kind of
confidence.

| | |
| --- | --- |
| Model | H3C R5350 G6 |
| BIOS | 6.30.50 |
| Redfish version | 1.15.1 |
| `Vendor` / `Product` at the root | both absent |
| System id | `Systems/1` |
| Chassis id | `Chassis/1` |
| Sensor model | legacy. `Sensors` is linked but `ThermalSubsystem` is not |
| `ResetType` allowed | `ForceOff`, `ForcePowerCycle`, `ForceRestart`, `GracefulShutdown`, `Nmi`, `On` |
| Temperatures | 20 reported, 18 of them the `0xFFFFFFFF` sentinel |
| Fans | 8 positions, each reported twice with different readings — dual rotor, sharing a name |
| Chassis power | 48 W through `PowerControl` |
| Sessions | one open while one client is connected; released on close |
| Certificate | self-signed, within its validity dates |
| Run | 2026-08-23 |

| | |
| --- | --- |
| Model | OpenBMC `romulus` (AST2500), **emulated**: `qemu-system-arm -M romulus-bmc`, the OpenBMC CI `latest-master` image |
| Redfish version | 1.17.0 |
| `Vendor` / `Product` at the root | both absent |
| System id | `Systems/system` |
| Chassis id | `Chassis/chassis` |
| Sensor model | modern (`Sensors`, `ThermalSubsystem`, `PowerSubsystem`), no members — there is no host to measure |
| `ResetType` allowed | through `ResetActionInfo` only: `ForceOff`, `PowerCycle`, `Nmi`, `GracefulShutdown`, `On`, `ForceOn`, `GracefulRestart`, `ForceRestart` |
| Sessions | released on close |
| Certificate | self-signed (`CN=testhost`) |
| Run | 2026-10-03 |

Not covered, and worth a row when someone has one: Dell, OpenBMC on real hardware, the
Supermicro X13/X14 sensor-model switch, HPE iLO's graceful operations, and any
machine publishing more than one system.

**A run that finds nothing new is worth a row too.** That is how this stops
being one machine.
