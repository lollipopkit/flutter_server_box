---
title: Architecture
description: Architecture patterns and design decisions
---

Server Box follows clean architecture principles with clear separation between data, domain, and presentation layers.

## Layered Architecture

```
┌─────────────────────────────────────┐
│          Presentation Layer         │
│         (lib/view/page/)            │
│  - Pages, Widgets, Controllers      │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│         Business Logic Layer        │
│      (lib/data/provider/)           │
│  - Riverpod Providers               │
│  - State Management                 │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│           Data Layer                │
│      (lib/data/model/, store/)      │
│  - Models, Storage, Services        │
└─────────────────────────────────────┘
```

## Key Patterns

### State Management: Riverpod

- **Code Generation**: Uses `riverpod_generator` for type-safe providers
- **State Notifiers**: For mutable state with business logic
- **Async Notifiers**: For loading and error states
- **Stream Providers**: For real-time data

### Immutable Models: Freezed

- All data models use Freezed for immutability
- Union types for state representation
- Built-in JSON serialization
- CopyWith extensions for updates

### Local Storage: SQLite

One encrypted file, `store.db`, opened through `package:sqlite3` with the
`sqlite3mc` cipher applied before anything reads it. There are two shapes in
it, and which one a store uses is a decision about whether its records have
relations:

- **`kv(store, key, value, updated_at)`** holds the settings and the history —
  a hundred unrelated preferences with nothing that queries by field, where
  adding one should stay a one-line change. `value` is JSON, so a value written
  here needs a `toJson`; `SqliteStore.set` answers `false` rather than throwing
  when it has none.
- **Entity tables** hold the servers, private keys, snippets, port forwards,
  connection statistics and agent conversations. Real columns, foreign keys,
  `CHECK` constraints and indexes.

Drift owns the DDL (`lib/data/store/db.dart`), and only the DDL: the app's
queries are hand-written and synchronous, because the UI reads a store while
building. Drift never opens the connection — `SqliteDb` does, applies the
cipher and the `foreign_keys` pragma, and hands the live handle over.

Two conventions the key-value layout could not hold:

- **A primary key is an id, never something the user typed.** Renaming a
  private key used to detach every server pointing at it, because the key's id
  *was* its name. Names are ordinary `UNIQUE` columns now.
- **A list or map field is a child table.** That makes "every server with this
  tag" a query rather than a decode of every row, and lets `ON DELETE CASCADE`
  clean up after a deleted server instead of six hand-written calls.

`Tables.syncRoots` names the tables that are a unit of sync. Each carries
`updated_at` and `rev`; their children carry neither and move with the parent,
so a tag cannot arrive before the server it belongs to. A delete leaves a row
in `tombstone`, without which a peer reads the record's absence as an addition
and puts it back.

### Storage migrations

`SchemaVersion` tracks the layout; Drift's own `schemaVersion` is pinned at 1
and stays there, because the steps that matter are outside what a Drift
migration can express. Two of them exist:

- `HiveImport` (m003) copies an upgrading install's Hive boxes into `kv`, once
  per device. It reads through frozen adapters in
  `lib/hive/legacy_adapters.dart` rather than through the live models — adding
  a field to a model makes a *generated* adapter unable to read any box written
  before it.
- `KvToTablesMigration` (m004) takes those rows apart into the entity tables,
  generating ids for the records that were keyed by name and rewriting every
  reference to them.

**A storage migration keeps a permanent regression test, fed by bytes the
release being migrated *from* actually wrote.** It gets one pass over a user's
records and is not repeatable, so a bug there is silence rather than a crash.
`test/fixtures/hive_v{1466,1480,1491}/` hold boxes produced by those releases'
own adapters, and `test/hive_release_migration_test.dart` runs both steps
against each. Seeding through the current adapters would only show that today's
code agrees with itself — on its first run that test found four field-name
mismatches, each of which silently dropped an entire store.

## Dependency Injection

Services and stores are injected via:

1. **Providers**: Expose dependencies to UI
2. **GetIt**: Service location (where applicable)
3. **Constructor Injection**: Explicit dependencies

## Data Flow

```
User Action → Widget → Provider → Service/Store → Model Update → UI Rebuild
```

1. User interacts with widget
2. Widget calls provider method
3. Provider updates state via service/store
3. State change triggers UI rebuild
4. New state reflected in widget

## Status Parsing: Shared Rust Library

Server status parsing (CPU, memory, disk, network, temperatures, GPU, SMART, …)
is implemented once in the Rust crate `crates/sbm_parser` and used by the app
through flutter_rust_bridge (`crates/sbm_ffi`, generated Dart in `lib/src/rust/`).
The server-side monitor uses the same crate directly, so both ends always parse
identically. Parsers are pure functions: they return raw counters, and
diff/windowed computations (e.g. network speed) are pure functions too — no
mutable state crosses the FFI boundary.

## Custom Dependencies

The project uses several custom forks to extend functionality:

- **dartssh2**: Enhanced SSH features
- **xterm**: Terminal emulator with mobile support
- **fl_lib**: Shared UI components and utilities

## Threading

- **Isolates**: Heavy computation off main thread
- **computer package**: Multi-threading utilities
- **Async/Await**: Non-blocking I/O operations
