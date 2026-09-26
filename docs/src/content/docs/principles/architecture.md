---
title: System Architecture
description: How Server Box connects its UI, state, storage, and platform layers
---

Server Box assigns UI, state coordination, local storage, and external
connections to separate layers. SSH, Monitor agent, and local terminal can
therefore use the same UI while platform-specific work stays at the edges.

This page describes the system model and two design choices that shape most
features: a server may provide two transports, and either transport may
provide status. For source directories, the App entry point, dependency
injection, and Rust integration, see
[Implementation architecture](/docs/development/architecture/).

## Architecture layers

```text
┌─────────────────────────────────────────────────┐
│ Presentation layer                              │
│ lib/view/page/, lib/view/widget/                │
│ Pages, Widgets, and user interaction            │
└─────────────────────────────────────────────────┘
                      │
┌─────────────────────────────────────────────────┐
│ State and business coordination                 │
│ lib/data/provider/                              │
│ Riverpod providers and async state              │
└─────────────────────────────────────────────────┘
                      │
┌─────────────────────────────────────────────────┐
│ Data and service layer                          │
│ lib/data/model/, lib/data/store/                │
│ Models, local storage, and connection services  │
└─────────────────────────────────────────────────┘
                      │
┌─────────────────────────────────────────────────┐
│ External integrations                           │
│ SSH, SFTP, Monitor HTTP, and platform APIs      │
└─────────────────────────────────────────────────┘
```

## Connection methods and capabilities

A server may have SSH, Monitor HTTP, or both configured. The
`preferredTransport` setting chooses which one the App tries first. It does
not turn the other transport off; the App may fall back to it if the first
connection fails.

The UI checks `ServerCapabilities` to decide which actions are available. It
does not infer them from the transport currently in use:

| Capability | SSH | Monitor HTTP |
|---|---|---|
| Shell and commands | Available | Requires `full_access` |
| Interactive terminal | Available | Requires `full_access` and the terminal endpoint |
| File browsing | SFTP | Requires `[remote_access.fs]` and `roots` |
| Byte streams (SFTP and port forwarding) | Available | Not available |
| History from before the App connected | Not available | Available |

With both transports configured, the server exposes the capabilities of both.
For example, preferring Monitor HTTP does not remove SFTP or port forwarding
available through SSH.

The file protocol is configured separately from the transport preference. SSH
file operations use SFTP by default; choose SCP for hosts without an SFTP
subsystem. A Monitor HTTP-only server uses the agent's file API and has no
SFTP or port forwarding.

## Status collection and parsing

The App has two status paths.

**SSH path:**

```text
Timer
  → Provider
  → SSH command script
  → sbm_parser through sbm_ffi
  → ServerStatus
  → UI rebuild
```

**Monitor HTTP path:**

```text
Timer
  → GET /api/v1/metrics
  → MonitorMetrics JSON
  → applyMonitorMetrics
  → ServerStatus
  → UI rebuild
```

The App's SSH path calls the shared Rust parser through `crates/sbm_ffi`.
Monitor agent samples core metrics such as CPU, memory, disk, and network on
its host with `crates/sbm_native`. On a slower extended cycle, it also runs the
shared script to collect values that still require CLI tools. The paths reuse
parts of the status model but have different sampling and parsing behavior.

The parser uses pure functions and returns raw counters. Difference and
window calculations are pure as well. Mutable state does not cross the FFI
boundary.

## Storage migrations

`SchemaVersion` controls the App's storage layout. Drift's `schemaVersion`
stays at `1` because App migrations do more than change Drift tables: they
import old Hive boxes, generate IDs, and rewrite references.

During an upgrade, `HiveImport` first copies data from the old installation
into `kv`. Registered schema migrations then move relational data into entity
tables. The adapters in `lib/hive/legacy_adapters.dart` are frozen readers for
released formats; do not regenerate them from current models.

Keep a regression test for every storage migration, using bytes written by
the release being migrated from. A fixture created by the current adapter
tests only the current code against itself; it does not prove compatibility
with an older release.

## Security

- **Credentials and trusted host fingerprints** are stored in the encrypted
  SQLite database. The setting store keeps fingerprints in
  `sshKnownHostFingerprints`; the database key is held in platform secure
  storage (Keychain or Keystore).
- **Sessions** are not persisted.
- **Host keys** are verified by the App for every connection, including
  connections through a jump server or `ProxyCommand`.
