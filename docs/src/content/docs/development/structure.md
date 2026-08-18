---
title: Project Structure
description: Understanding the Server Box codebase
---

The Server Box project is a monorepo: the Flutter app lives at the repository root, alongside a Rust workspace and the server-side monitor.

## Monorepo Layout

```
flutter_server_box/
├── lib/               # Flutter app (see below)
├── crates/
│   ├── sbm_parser/    # Shared status parser (single source of truth,
│   │                  # used by the app via FFI and by the monitor)
│   ├── sbm_ffi/       # flutter_rust_bridge binding crate + cargokit
│   │                  # Flutter plugin glue (one directory)
│   └── sbm_native/    # Native per-platform sampler (monitor only)
├── monitor/           # Server-side monitor (Rust service + Svelte frontend)
├── packages/          # Vendored Dart forks (path dependencies), plus
│                      # webui: shared Svelte UI for monitor and website
├── docs/              # This documentation site (Astro Starlight)
├── website/           # Project website
└── Cargo.toml         # Rust workspace root
```

## App Directory Structure

```
lib/
├── core/              # Core utilities and extensions
├── data/              # Data layer
│   ├── model/         # Data models by feature
│   ├── provider/      # Riverpod providers
│   ├── store/         # Local storage (Hive)
│   ├── helper/        # Data-layer helpers
│   ├── res/           # Resources and constants
│   └── ssh/           # SSH session management
├── view/              # UI layer
│   ├── page/          # Main pages
│   └── widget/        # Reusable widgets
├── generated/         # Generated localization
├── l10n/              # Localization ARB files
├── hive/              # Hive adapters
└── src/rust/          # Generated flutter_rust_bridge bindings (do not edit)
```

## Core Layer (`lib/core/`)

Contains utilities, extensions, and routing configuration:

- **Extensions**: Dart extensions for common types
- **Routes**: App routing configuration
- **Utils**: Shared utility functions

## Data Layer (`lib/data/`)

### Models (`lib/data/model/`)

Organized by feature:

- `server/` - Server connection and status models
- `container/` - Docker container models
- `ssh/` - SSH session models
- `sftp/` - SFTP file models
- `app/` - App-specific models

### Providers (`lib/data/provider/`)

Riverpod providers for dependency injection and state management:

- Server providers
- UI state providers
- Service providers

### Stores (`lib/data/store/`)

Hive-based local storage:

- Server storage
- Settings storage
- Cache storage

## View Layer (`lib/view/`)

### Pages (`lib/view/page/`)

Main application screens:

- `server/` - Server management pages
- `ssh/` - SSH terminal pages
- `container/` - Container pages
- `setting/` - Settings pages
- `storage/` - SFTP pages
- `snippet/` - Snippet pages

### Widgets (`lib/view/widget/`)

Reusable UI components:

- Server cards
- Status charts
- Input components
- Dialogs

## Generated Files

- `lib/generated/l10n/` - Auto-generated localization
- `*.g.dart` - Generated code (json_serializable, freezed, hive, riverpod)
- `*.freezed.dart` - Freezed immutable classes

## Packages Directory (`/packages/`)

Contains custom forks of dependencies, referenced by path from `pubspec.yaml`:

- `dartssh2/` - SSH library
- `xterm/` - Terminal emulator
- `fl_lib/` - Shared utilities
- `fl_build/` - Build system
- `circle_chart/` - Chart widget
- `plain_notification_token/` - Push token plugin
- `watch_connectivity/` - Apple Watch connectivity

One directory here is not a Dart fork: `webui/` (`@serverbox/webui`) is a
Svelte package of shared UI primitives and design tokens, consumed as a `file:`
dependency by both `monitor/frontend` and `website/`.

## Rust Side

- `crates/sbm_parser/` - Parses raw command output into structured server status.
  Shared by the app (via FFI) and the monitor, so both always agree on parsing.
- `crates/sbm_ffi/` - Thin flutter_rust_bridge wrapper around `sbm_parser`.
  The generated Dart side lives in `lib/src/rust/`.
- `crates/sbm_native/` - Per-platform native sampling, used by the monitor only.
  It reads cpu/memory/swap/disk/network/uptime directly through syscalls or
  procfs instead of running shell commands. The app never depends on it: it
  collects over SSH and cannot run syscalls on a remote host.
- `monitor/` - Standalone monitoring service with its own docs in `monitor/README.md`.
