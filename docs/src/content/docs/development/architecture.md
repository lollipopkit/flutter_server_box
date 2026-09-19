---
title: Implementation Architecture
description: Implementation details for Server Box's Flutter, storage, connection, and native layers
---

This page covers where the code lives and how the app is wired together. For the system-level model — layers, transports and capabilities, the two status paths, migrations and security — see [System Architecture](/docs/principles/architecture/).

## Layers

```text
┌─────────────────────────────────────┐
│ Presentation                        │
│ lib/view/                           │
│ Pages, Widgets, and user interaction│
└─────────────────────────────────────┘
                  │
┌─────────────────────────────────────┐
│ State and business coordination     │
│ lib/data/provider/                  │
│ Riverpod providers and async state  │
└─────────────────────────────────────┘
                  │
┌─────────────────────────────────────┐
│ Data and services                   │
│ lib/data/model/, lib/data/store/    │
│ Models, storage, and connections    │
└─────────────────────────────────────┘
                  │
┌─────────────────────────────────────┐
│ External integrations               │
│ SSH, SFTP, Monitor HTTP, platform APIs│
└─────────────────────────────────────┘
```

## Application foundation

`lib/main.dart` initializes dependencies, opens the encrypted local database, initializes the Rust bindings, and calls `runApp`. The root Widget provides the theme, routing structure, and Riverpod `ProviderScope` used for dependency injection.

The home page provides tabs for servers, terminals, files, and snippets. Pages display state and receive user interaction; providers, services, and stores own operations and state transitions.

## State management: Riverpod

The project uses `riverpod_generator` to generate type-safe providers:

- `NotifierProvider` manages synchronous state with update methods.
- `AsyncNotifierProvider` manages loading, success, and error states.
- `StreamProvider` exposes continuously produced data.
- Family providers maintain independent state for different servers or other parameters.

Providers do not depend on `BuildContext`, so services and business logic can be tested independently. [Riverpod patterns](/docs/development/state/) covers the declaration and lifecycle detail.

## Data persistence: encrypted SQLite

The App's authoritative local store is the encrypted SQLite file `store.db`. `SqliteDb` opens the connection and applies database encryption and the `foreign_keys` pragma.

Data uses one of two shapes:

- **Key-value table `kv(store, key, value, updated_at)`**: settings and history that do not need relational queries. Values are JSON and require `toJson` when written through `SqliteStore.set`.
- **Entity tables**: servers, private keys, snippets, port forwards, connection statistics, Agent conversations, and related records. These use real columns, foreign keys, constraints, and indexes.

Drift owns the DDL in `lib/data/store/db.dart`, but does not open the connection or replace the hand-written synchronous store queries. Entity primary keys are generated IDs; user-provided names are ordinary unique columns. List and map fields are stored in child tables.

## Dependency injection

Services and stores are combined through:

1. **Providers**: expose dependencies and state to the UI.
2. **GetIt**: provide global service instances where service location is appropriate.
3. **Constructor injection**: pass dependencies explicitly between classes.

## Platform and Rust integration

Flutter provides the cross-platform UI. Platform integrations provide notifications, background services, filesystem access, and other system features. Rust APIs are exposed to Dart through `crates/sbm_ffi` and flutter_rust_bridge; generated bindings live in `lib/src/rust/`.

`crates/sbm_parser` is the shared pure parser. `crates/sbm_native` is used only by Monitor agent for sampling on the server itself. The App never calls `sbm_native` on a remote host.
