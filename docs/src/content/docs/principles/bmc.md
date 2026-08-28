---
title: BMC (Redfish)
description: BMC design, limitations, and hardware compatibility
---

:::caution[Beta]
Only the read path (power state and sensors) has been verified against one real device. Power control has not been verified automatically. The vendor and model differences below come from vendor documentation, recorded responses, and a local test service; they are not a hardware compatibility list.

Treat power operations like pressing a physical power button on a remote server.
:::

SSH and Monitor agent both require the host operating system to be running. SSH needs `sshd`, while Monitor agent needs a process running on the host. When the host is powered off, hung, or rebooting, both usually report only a connection failure.

A BMC (Baseboard Management Controller) is an independent computer on the motherboard with its own power and network connection. It may still respond when the host's other services are unavailable, and can provide power state, hardware sensor readings, and hardware events that the operating system cannot provide.

## Why Redfish

Server Box communicates with the BMC through Redfish's HTTPS/JSON API. Redfish is a common out-of-band management interface for modern servers.

| | Redfish | IPMI 2.0 over LAN |
|---|---|---|
| Transport | HTTPS + JSON | RMCP+ over UDP 623, binary protocol |
| Implementation cost in this project | `dio` is sufficient; no native code required | No Dart implementation exists; a client would need to be implemented in `crates/` behind FFI |
| Data model | Self-describing resources connected by links | SDR, SEL, and chassis commands plus vendor-specific raw data |
| Authentication | TLS + session token | RAKP |
| Hardware coverage | Generally devices from around 2016 onward | Also covers older and entry-level devices |
| Specification status | Actively maintained | Last revised in 2013 |

IPMI's main advantages are support for older hardware and Serial-over-LAN. This project does not currently include an IPMI client; supporting pre-Redfish hardware would require a separate decision about an FFI client and another security model.

## Where it fits in the application model

BMC is an out-of-band management channel and an independent side channel in the server configuration. SSH and Monitor HTTP determine where status data and normal operations come from; BMC reads hardware state and performs power operations when the host operating system is unavailable.

BMC is nested in `Spi`, alongside Wake-on-LAN's `wolCfg`:

```dart
class Spi {
  SshCredential? ssh;
  MonitorHttpCredential? monitorHttp;
  WakeOnLanCfg? wolCfg;
  BmcCfg? bmc;          // null when BMC is not configured
}

final class BmcCfg {
  String addr;          // https://...
  String? credId;       // BmcCredential shared by several servers
  String? certSha256;   // pinned after user confirmation
}

class BmcCredential {
  String id;            // generated ID, not the display name
  String name;          // unique name shown in the picker
  String user;
  String? pwd;
}
```

A BMC account is a separate record referenced by ID. Servers in one rack commonly share an account, so changing it once updates every server that references it. Deleting an account uses `ON DELETE SET NULL`, so it does not delete the server configurations that used it.

The address and certificate fingerprint belong to one BMC and stay on `BmcCfg`. Different BMCs may present different certificates; storing the fingerprint on a shared account would verify one device with another device's fingerprint.

Physical hosts and virtual machines may point to the same BMC. A power operation from any of those records affects the physical host, and `PowerState` reports the host rather than the guest. The current model does not represent this host/guest relationship; configure BMC only on the physical-host record.

## Layers

The layers keep the code that can be tested with fixtures independent of real servers:

```text
BmcCfg + BmcCredential    user configuration                 App
  ↓
RedfishClient             TLS trust, sessions, GET/POST      package:redfish
RedfishDiscovery          one-time resource discovery        package:redfish
resources / sensors       JSON → models, no IO                package:redfish
  ↓
BmcNotifier               state and independent polling      App
```

Only `RedfishClient` accesses the network. Lower-level parsers receive decoded JSON maps and return models, so vendor differences can be tested against saved responses rather than hardware.

## TLS and trust on first use

BMCs commonly use self-signed certificates. A BMC has power-control authority, so accepting any certificate at its address could allow another service to impersonate it. Server Box therefore uses a trust-on-first-use flow similar to SSH host-key verification:

1. The first connection displays the certificate's SHA-256 fingerprint.
2. Compare it with the fingerprint shown by the BMC's own web interface and confirm it.
3. The App stores the accepted fingerprint and accepts only a matching certificate later.
4. If the fingerprint changes, the App refuses the connection, shows the old and new values, and asks for verification again.

A BMC may legitimately change its fingerprint after regenerating a certificate or upgrading firmware. A man-in-the-middle attack produces the same symptom, so verify the BMC before accepting a new certificate.

## Vendor differences

Everything in this section must be discovered from Redfish resources rather than assumed from a vendor name or a common path.

### Resource IDs are not fixed

`/redfish/v1/` is the fixed entry point, but the IDs below `Systems` and `Chassis` are vendor-defined:

| Vendor | Typical system ID |
|---|---|
| Supermicro | `1` |
| Dell iDRAC | `System.Embedded.1` |
| OpenBMC | `system` |

A client should walk `/redfish/v1/Systems`, read the collection's `Members`, and then access the concrete resources.

### Sensor models may come in two forms

Redfish 2020.4 deprecated `Chassis/{id}/Thermal` and `/Power` in favor of `ThermalSubsystem`, `PowerSubsystem`, and a unified `Sensors` collection. Many firmware versions still implement only the legacy model; some expose both.

The client should inspect the links actually provided by the `Chassis` resource, prefer a complete modern model, and fall back to the legacy model when necessary. It should not infer the model from the vendor name.

### `ResetType` advertisements may be unreliable

The `ComputerSystem.Reset` action advertises supported values through `ResetType@Redfish.AllowableValues`. The supported values differ by device; `Nmi` and `PowerCycle` may be advertised but unavailable because of firmware behavior or licensing.

The App maps intents such as “restart” and “power cycle” to values advertised by the device and uses a fallback order when needed. If no value can implement an intent, the corresponding button is not shown.

### Vendors may extend `ResetType`

An H3C R5350 G6 advertises `ForcePowerCycle`, which is not part of the standard Redfish enum, and does not advertise another power-cut operation. Matching only standard names would incorrectly map “power cycle” to `ForceRestart`.

The candidate list for each intent therefore includes known vendor extensions after the standard names. These extensions come from real device responses and cannot be inferred from the specification alone.

### Sensors may return sentinel values

The specification recommends `null` when a sensor has no reading, but some firmware sends a sentinel instead. For example, the tested H3C device returns `4294967295` (`0xFFFFFFFF`) for temperatures it cannot read.

The App filters readings by a plausible range rather than matching a fixed list of sentinel values. The current range rejects temperatures below absolute zero or above 1000°C and implausible fan speeds. `-1` is retained because it may be a sentinel or a real cold-inlet reading.

### Graceful operations only confirm a request

HPE iLO documents that `GracefulShutdown` and `GracefulRestart` depend on the operating system. A `204 No Content` response means that the request was accepted, not that the operating system acted on it.

The App polls `PowerState` until it changes or the timeout expires. The HTTP status code is not treated as the operation's result.

### Sessions are limited

Redfish sessions are created with `POST` to `SessionService/Sessions`, which returns an `X-Auth-Token`. An undeleted session remains on the BMC until it expires, and BMCs commonly support only a small number of concurrent sessions. Too many leaked sessions can block the management interface.

Each client creates one session and deletes its session resource when disposed. Both normal and failure paths must release the session. Probing the service root does not require a session.

### Licensing may limit features

Some Supermicro licenses gate firmware updates and virtual media. Tests indicate that read-only GET requests and `ComputerSystem.Reset` work without those licenses on some X11 through X13 devices; this is field experience, not a policy for every model.

A `401` or `403` from a sub-resource should be reported as that resource being unavailable and should not fail the entire fetch.

## Polling

BMC responses are usually slower than operating-system APIs; reading sensors may take several seconds. BMC therefore uses its own polling cycle instead of sharing the normal server-status timer.

Resource IDs, sensor model, and supported reset types are discovery results. Each client discovers them once and caches them; later polls read and convert live values without rediscovering the device structure.

## Phase 1 scope

- Probe `GET /redfish/v1/` and its collections
- Read `Systems/{id}`: power state, model, serial number, BIOS version, and health rollup
- Read `Chassis/{id}`: temperatures, fan speeds, and power draw using the model provided by the device
- Call `ComputerSystem.Reset` with a confirmation dialog, negotiated reset type, and polling-based result confirmation

Not included: event logs, storage inventory, boot-device override, virtual media, or relaying access through Monitor agent to BMCs on an isolated management network.

## Hardware tested

The table below records a device that has actually responded; it is not a compatibility list. Other behavior comes from vendor documentation, recorded responses, and a local test service.

| Item | Value |
|---|---|
| Model | H3C R5350 G6 |
| BIOS | 6.30.50 |
| Redfish version | 1.15.1 |
| Root `Vendor` / `Product` | Both absent; do not rely on them to identify the service |
| System ID | `Systems/1` |
| Chassis ID | `Chassis/1` |
| Sensor model | Legacy (`Thermal` + `Power`); `Sensors` is linked but `ThermalSubsystem` is incomplete, so the legacy model is used |
| `ResetType` | `ForceOff`, `ForcePowerCycle`, `ForceRestart`, `GracefulShutdown`, `Nmi`, `On` |
| Temperatures | 20 reported; 18 returned the `0xFFFFFFFF` sentinel |
| Fans | 8 positions, with two different readings reported for each position |
| Chassis power | 48 W through `PowerControl` |
| Sessions | One session per connected client, released on close |
| Certificate | Self-signed and valid at test time |
| Test date | 2026-08-23 |

Not yet covered: Dell (`System.Embedded.1`), OpenBMC (`system`), the Supermicro X11–X14 sensor-model transition, HPE iLO graceful operations, and devices that publish multiple systems.

## Testing against real hardware

### Read-only test

`packages/redfish/test/e2e_test.dart` is an opt-in, read-only test. It connects to a real device only when these variables are present in the workspace-root `.env`; otherwise it skips silently:

```bash
SBM_E2E_BMC_URL=https://10.0.0.9
SBM_E2E_BMC_USER=...
SBM_E2E_BMC_PWD=...
```

The test prints discovered resource IDs, sensor model, reset types, and intent mappings. It does not assert that every vendor uses one resource shape. It reads the reset action but never posts to it.

### Power operations

Power control has no automated test. If you verify it manually, use a machine that carries no important workload:

1. Configure the BMC and verify its certificate fingerprint.
2. Confirm that the App shows the actual power state.
3. Press **Restart** and verify the negotiated `ResetType` in the confirmation dialog.
4. Check whether the result is *confirmed* or *accepted*. For iLO graceful operations, *accepted* can be correct; on hardware that distinguishes request from result, it means no state change has been observed and needs investigation.
