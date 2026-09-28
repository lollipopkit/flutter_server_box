---
title: Implementation Architecture
description: Implementation details for Server Box's Flutter, storage, connection, and native layers
---

This page maps the source tree to the App's implementation. For the broader
system design—including layers, transports, capabilities, status collection,
migrations, and security—see [System Architecture](/docs/principles/architecture/).

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

`lib/main.dart` initializes dependencies, opens the encrypted local database,
initializes Rust bindings, and starts Flutter with `runApp`. The root Widget
sets up the theme and routes and creates the Riverpod `ProviderScope` used for
dependency injection.

The home page provides tabs for servers, terminals, files, and snippets. Pages
render state and handle interaction. Providers, services, and stores perform
operations and manage state changes.

## State management: Riverpod

The project uses `riverpod_generator` to generate typed providers:

- `NotifierProvider` manages synchronous state with update methods.
- `AsyncNotifierProvider` manages loading, success, and error states.
- `StreamProvider` exposes continuously produced data.
- Family providers maintain independent state for different servers or other parameters.

Providers do not require `BuildContext`. This keeps services and business
logic independent of the Widget tree. See [Riverpod patterns](/docs/development/state/)
for provider declarations and lifecycle details.

## Data persistence: encrypted SQLite

The encrypted SQLite file `store.db` is the App's source of truth for local
data. `SqliteDb` opens it, configures database encryption, and enables the
`foreign_keys` pragma.

Data uses one of two shapes:

- **Key-value table `kv(store, key, value, updated_at)`** holds settings and
  history that do not need relational queries. Values are JSON; values written
  through `SqliteStore.set` must provide `toJson`.
- **Entity tables** hold servers, private keys, snippets, port forwards,
  connection statistics, Agent conversations, and related records. They use
  columns, foreign keys, constraints, and indexes.

Drift defines the DDL in `lib/data/store/db.dart`. `SqliteDb` manages the
connection, and store queries remain hand-written and synchronous. Entity
primary keys are generated IDs; user-provided names are ordinary columns with
unique constraints. Lists and maps are stored in child tables.

## Dependency injection

Services and stores receive dependencies through three patterns:

1. **Providers**: expose dependencies and state to the UI.
2. **GetIt**: provide global service instances where service location is appropriate.
3. **Constructor injection**: pass dependencies explicitly between classes.

## Platform and Rust integration

Flutter supplies the cross-platform UI. Platform integrations provide
notifications, background services, filesystem access, and other operating
system features. The App exposes Rust APIs to Dart through `crates/sbm_ffi`
and flutter_rust_bridge; generated bindings are in `lib/src/rust/`.

`crates/sbm_parser` contains parsing logic shared by the projects.
`crates/sbm_native` collects metrics for Monitor agent on the machine running
the agent. The App does not invoke `sbm_native` on remote servers.
