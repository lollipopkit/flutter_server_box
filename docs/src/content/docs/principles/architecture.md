---
title: Architecture Overview
description: Server Box's overall architecture and component responsibilities
---

Server Box separates UI, state coordination, local data, and external connections by responsibility. This lets SSH, Monitor agent, and local terminal backends share the same UI while keeping platform-specific code at the edges.

## Architecture layers

```text
┌─────────────────────────────────────────────────┐
│ Presentation layer                              │
│ lib/view/page/, lib/view/widget/                │
│ Pages, Widgets, and user interaction            │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ State and business coordination                 │
│ lib/data/provider/                              │
│ Riverpod providers and async state              │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ Data and service layer                          │
│ lib/data/model/, lib/data/store/                │
│ Models, local storage, and connection services  │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ External integrations                           │
│ SSH, SFTP, Monitor HTTP, and platform APIs      │
└─────────────────────────────────────────────────┘
```

## Connection methods and capabilities

A server can have SSH configured, Monitor HTTP configured, or both. `preferredTransport` controls which connection is tried first; it does not disable the other one. If the first connection fails, the App can try the other.

The UI uses `ServerCapabilities` to decide which features to offer instead of checking the active transport directly:

| Capability | SSH | Monitor HTTP |
|---|---|---|
| Shell and commands | Available | Requires `full_access` |
| Interactive terminal | Available | Requires `full_access` and the terminal endpoint |
| File browsing | SFTP | Requires `[remote_access.fs]` and `roots` |
| Byte streams (SFTP and port forwarding) | Available | Not available |
| History from before the App connected | Not available | Available |

When both transports are configured, the server exposes the union of their capabilities. Making Monitor HTTP the preferred transport therefore does not hide SFTP or port forwarding provided by SSH.

The protocol used for SSH file operations is a separate setting. SFTP is the default; SCP can be selected for hosts without an SFTP subsystem. A server configured only through Monitor HTTP uses the agent's file API and does not provide SFTP or port forwarding.

## Application foundation

### Entry point

`lib/main.dart` initializes dependencies, opens the local database, initializes the Rust bindings, and calls `runApp`.

### Root widget

The root widget provides the theme, routing structure, and Riverpod `ProviderScope` used for dependency injection.

### Home page

The home page provides tabs for servers, terminals, files, and snippets. Pages display state and receive user interaction; providers, services, and stores own the corresponding operations and state transitions.

## Core systems

### State management: Riverpod

The project uses `riverpod_generator` to generate type-safe providers:

- `NotifierProvider` manages synchronous state with update methods.
- `AsyncNotifierProvider` manages loading, success, and error states.
- `StreamProvider` exposes continuously produced data.
- Family providers maintain independent state for different servers or other parameters.

Providers do not depend on `BuildContext`, so services and business logic can be tested independently.

### Local storage: encrypted SQLite

The App's authoritative local store is the encrypted SQLite file `store.db`. `SqliteDb` opens the connection and applies database encryption and the `foreign_keys` pragma.

Data uses one of two shapes:

- **Key-value table `kv(store, key, value, updated_at)`**: settings and history that do not need relational queries. `value` is JSON, so values written through `SqliteStore.set` need a `toJson` method.
- **Entity tables**: servers, private keys, snippets, port forwards, connection statistics, Agent conversations, and related records. These use real columns, foreign keys, constraints, and indexes.

Drift owns the DDL in `lib/data/store/db.dart`, but it does not open the connection or replace the hand-written synchronous store queries. Entity primary keys are generated IDs; user-provided names are ordinary unique columns. List and map fields are stored in child tables.

### Status collection and parsing

The App has two status paths:

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

The App's SSH path calls the shared Rust parser in `crates/sbm_ffi`. Monitor agent uses `crates/sbm_native` on the server for core metrics such as CPU, memory, disk, and network, and uses the shared script on its slower extended cycle for values that still need CLI tools. The two paths share parts of the status model, but they are not identical sampling or parsing pipelines.

The parser is made of pure functions. It returns raw counters; diff and window calculations are also pure functions, and mutable state does not cross the FFI boundary.

## Storage migrations

`SchemaVersion` manages the App's storage layout while Drift's `schemaVersion` remains `1`. App migrations also read old Hive boxes, generate IDs, and rewrite references, which is outside the scope of a Drift migration.

`HiveImport` first imports data from an upgrading installation into `kv`. Registered schema migrations then split that data into entity tables. The adapters in `lib/hive/legacy_adapters.dart` are frozen readers for old releases and must not be regenerated from current models.

Every storage migration needs a permanent regression test using bytes written by the release being migrated from. A fixture generated by the current adapter only proves that the current code agrees with itself; it does not prove that an old release can still be read.

## Dependency injection

Services and stores are combined through:

1. **Providers**: expose dependencies and state to the UI.
2. **GetIt**: provide global service instances where service location is appropriate.
3. **Constructor injection**: pass dependencies explicitly between classes.

## Platform and Rust integration

Flutter provides the cross-platform UI, while platform integrations provide notifications, background services, filesystem access, and other system features. Rust APIs are exposed to Dart through `crates/sbm_ffi` and flutter_rust_bridge; generated bindings live in `lib/src/rust/`.

`crates/sbm_parser` is the shared pure parser. `crates/sbm_native` is used only by Monitor agent for sampling on the server itself. The App never calls `sbm_native` on a remote host.
