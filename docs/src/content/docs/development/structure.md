---
title: Project Structure
description: Understand the Server Box codebase
---

The repository is a monorepo. The Flutter App is at the root, alongside the
Rust workspace, Monitor agent, documentation site, and project website.

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
│   ├── service/       # systemd/procd/OpenRC and cron/user managers
│   └── ssh/
├── view/              # Pages and reusable Widgets
├── generated/         # Generated localization code
├── l10n/              # Localization source ARB files
├── hive/              # Legacy Hive adapters used only for migration
└── src/rust/          # Generated flutter_rust_bridge bindings
```

These paths and files are generated outputs: `lib/src/rust/`,
`lib/generated/`, `*.g.dart`, and `*.freezed.dart`. Make changes in their
source definitions and regenerate them; do not edit the outputs by hand.

## Core code

### `lib/core/`

Contains extensions, routing, and utilities shared across features. Keep
page-specific business state in its provider or service.

### `lib/data/model/`

Models are organized by feature:

- `server/`: Server configuration, credentials, and status
- `container/`: Docker and Podman containers
- `file/`: Remote file models
- `ssh/`: SSH session models
- `ai/`: AI conversation and command models
- `app/`: App configuration and state

### `lib/data/provider/`

Riverpod providers coordinate dependencies, asynchronous operations, and state
shared across pages. They generally call services or stores; keep data access
out of UI Widgets.

### `lib/data/store/`

The local data layer uses an encrypted SQLite database:

- `SqliteStore` handles key-value data, including settings and history.
- Entity stores handle relational data, including servers, private keys, and snippets.
- Migrations upgrade stored data between App versions.

### `lib/view/`

`page/` contains the main screens. `widget/` contains reusable components,
such as server cards, status charts, inputs, and dialogs.

## Packages

Most directories in `packages/` are forks referenced through local path
dependencies:

- `dartssh2/`: SSH client
- `xterm/`: Terminal emulator
- `fl_lib/`: Shared UI components and utilities
- `fl_build/`: Cross-platform build tool
- Other platform plugins and component packages

`packages/webui/` is shared by the Monitor panel and project website. This
Svelte package provides UI primitives and design tokens.

## Rust workspace

- `crates/sbm_parser/` parses command output into structured server status. The App calls it through FFI; Monitor uses it in its script collection path.
- `crates/sbm_native/` samples metrics on the host running Monitor, using syscalls, procfs, or sysfs. The App collects remote data over SSH and does not call this crate on a remote host.
- `crates/sbm_ffi/` exposes Rust APIs to Flutter, including the parser and native SSH cryptography. Generated Dart bindings are in `lib/src/rust/`.
- `monitor/` contains the standalone Monitor agent. See `monitor/README.md` for its documentation.

The App collects metrics from remote servers over SSH. Monitor collects them
from the host where it runs. The projects share selected models and parser
code, while using separate collection pipelines.
