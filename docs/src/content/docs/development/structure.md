---
title: Project Structure
description: Understand the Server Box codebase
---

Server Box uses a monorepo: the Flutter App lives at the repository root alongside the Rust workspace, Monitor agent, documentation site, and project website.

## Monorepo layout

```text
flutter_server_box/
├── lib/               # Flutter App
├── crates/
│   ├── sbm_parser/    # Shared status parser for App and Monitor
│   ├── sbm_ffi/       # flutter_rust_bridge binding crate
│   └── sbm_native/    # Native sampler used by Monitor
├── monitor/           # Monitor agent (Rust service + Svelte panel)
├── packages/          # Path-dependent Dart forks and shared webui package
├── docs/              # Astro Starlight documentation site
├── website/           # Project website
└── Cargo.toml         # Rust workspace root
```

## Flutter App directories

```text
lib/
├── core/              # Core utilities, extensions, and routing
├── data/              # Models, providers, stores, and SSH sessions
│   ├── model/
│   ├── provider/
│   ├── store/         # SQLite storage
│   ├── helper/
│   ├── res/
│   └── ssh/
├── view/              # Pages and reusable Widgets
├── generated/         # Generated localization code
├── l10n/              # Localization source ARB files
├── hive/              # Legacy Hive adapters used only for migration
└── src/rust/          # Generated flutter_rust_bridge bindings
```

`lib/src/rust/`, `lib/generated/`, `*.g.dart`, and `*.freezed.dart` are generated outputs. Do not edit them directly.

## Core code

### `lib/core/`

Cross-feature extensions, routing, and utility functions live here. Page-specific business state belongs in the relevant provider or service instead.

### `lib/data/model/`

Models are grouped by feature:

- `server/`: Server configuration, credentials, and status
- `container/`: Docker and Podman containers
- `ssh/`: SSH session models
- `sftp/`: Remote file models
- `app/`: App configuration and state

### `lib/data/provider/`

Riverpod providers handle dependency injection, asynchronous state, and state shared across pages. Providers normally call services or stores rather than putting data-access logic in UI Widgets.

### `lib/data/store/`

The local data layer uses one encrypted SQLite database:

- `SqliteStore`: key-value data such as settings and history
- Entity stores: relational data such as servers, private keys, and snippets
- Migrations: cross-version storage migrations

### `lib/view/`

`page/` contains main screens. `widget/` contains reusable UI components such as server cards, status charts, inputs, and dialogs.

## Packages

Most directories in `packages/` are path-dependent forks:

- `dartssh2/`: SSH client
- `xterm/`: Terminal emulator
- `fl_lib/`: Shared UI components and utilities
- `fl_build/`: Cross-platform build tool
- Other platform plugins and component packages

`packages/webui/` is the exception. It is a Svelte package shared by the Monitor panel and project website, providing UI primitives and design tokens.

## Rust workspace

- `crates/sbm_parser/`: Parses command output into structured server status. The App calls it through FFI, and Monitor uses it for its script path.
- `crates/sbm_native/`: Native sampler used only by Monitor on the server itself. It reads core metrics through syscalls, procfs, or sysfs. The App collects remote data over SSH and never calls this crate on a remote host.
- `crates/sbm_ffi/`: Exposes Rust APIs to Flutter, including the parser and native SSH crypto; generated Dart bindings are in `lib/src/rust/`.
- `monitor/`: Standalone Monitor agent; see `monitor/README.md` for its own documentation.

The App samples remote servers over SSH, while Monitor samples its own host. They share selected models and parser code, but their sampling pipelines are not identical.
