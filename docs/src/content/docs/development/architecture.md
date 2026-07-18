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

### Local Storage: Hive

- **hive_ce**: Community edition of Hive
- Follow the existing model pattern: most stores use `hive_ce`, while some tracked models still declare `@HiveType` and `@HiveField` explicitly
- Type adapters auto-generated
- Persistent key-value storage

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
