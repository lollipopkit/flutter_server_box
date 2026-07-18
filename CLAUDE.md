# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

A `Makefile` wraps most common tasks — run `make help` for the full list. Preferred shortcuts:

- `make deps` / `make run` / `make analyze` (`flutter analyze lib test`)
- `make gen` - build_runner + gen-l10n in one step
- `make build PLATFORM=<android|ios|macos|linux|windows>` - wraps `dart run fl_build -p PLATFORM`
- Release packaging (macOS DMG, Homebrew cask sync): `make release-macos-dmg`, `make package-dmg`, `make sync-homebrew-cask`

### Development

- `flutter run` - Run the app in development mode
- `flutter run --release -PallowDebugReleaseSigning=true` - Run Android release locally with explicit debug-signing fallback for verification only
- `dart run fl_build -p PLATFORM` - Build the app for specific platform (see fl_build package)
- `dart run build_runner build --delete-conflicting-outputs` - Generate code for models with annotations (json_serializable, freezed, hive, riverpod)
  - Every time you change model files, run this command to regenerate code (Hive adapters, Riverpod providers, etc.)
  - Generated files include: `*.g.dart`, `*.freezed.dart` files

### Testing

- `flutter test` - Run unit tests
- `flutter test test/disk_test.dart` - Run specific test file (or `make test-one TEST=test/disk_test.dart`)
- `cargo test --workspace` - Run all Rust tests (parser, FFI shell, monitor)

### Rust / FFI

- `cargo build -p sbm_ffi` - Build the FFI crate; required before running `flutter test test/frb_parser_test.dart` (`test/rust_lib_helper.dart` loads the dylib from `target/`)
- `flutter_rust_bridge_codegen generate` - Regenerate FRB bindings after changing `crates/sbm_ffi/src/api` (config: `flutter_rust_bridge.yaml`; Dart output `lib/src/rust/`, do not edit generated code)
- App builds link Rust via cargokit inside `crates/sbm_ffi/` (the crate and the Flutter FFI plugin glue share one directory), pinned to `flutter_rust_bridge: 2.12.0` in pubspec

## Architecture

This is a Flutter application for managing Linux servers with the following key architectural components:

### Monorepo Layout (Rust workspace)

- `crates/sbm_parser/` - Shared status parser (single source of truth for command manifest + parsing; used by both the app via FFI and the server-side monitor). Behavior locked by `crates/sbm_parser/tests/dart_compat.rs`
  - Parsing is pure functions: parsers emit raw counters; diff/windowed computation (speeds etc.) is provided as pure functions, mutable time-series state stays on the caller side. The FFI boundary holds no mutable state.
  - The command manifest (cmd name → per-platform command, `SrvBoxSep.<cmd>` segmenting) lives here too; commands are flagged `core` vs on-demand (monitor periodically runs core only; GPU/SMART etc. are app-triggered)
- `crates/sbm_ffi/` - flutter_rust_bridge binding crate + cargokit Flutter plugin glue in one directory (Dart side generated into `lib/src/rust/`)
- `monitor/` - Server-side monitoring service (Rust + React frontend), has its own `monitor/CLAUDE.md`
- Root `Cargo.toml` is the workspace; build/test all Rust with `cargo test --workspace`
- FFI parity test: `flutter test test/frb_parser_test.dart` (requires `cargo build -p sbm_ffi` first)
- Migration rule ("test as spec"): before moving a parsing module to Rust, port its Dart fixture tests to Rust; only delete the Dart implementation after the FFI result is asserted identical against the same fixtures
- Remaining migration work: switch app production code module-by-module to FFI and delete Dart parsers, switch script generation to the shared `command_specs`, CI cross-compile verification for all five platforms

### Project Structure

- `lib/core/` - Core utilities, extensions, and routing
- `lib/data/` - Data layer with models, providers, and storage
  - `model/` - Data models organized by feature (server, container, ssh, etc.)
  - `provider/` - Riverpod providers for state management
  - `store/` - Local storage implementations using Hive
- `lib/view/` - UI layer with pages and widgets
- `lib/generated/` - Generated localization files
- `lib/hive/` - Hive adapters for local storage
- `lib/src/rust/` - Generated FRB bindings (do not edit)
- `packages/` - Vendored Dart forks referenced by path from pubspec (dartssh2, xterm, fl_lib, fl_build, etc.)
- `website/` - Project website (Svelte + bun; deployed via `scripts/build-cloudflare-pages.sh`)

### Key Technologies

- **State Management**: Riverpod with code generation (riverpod_annotation)
- **Local Storage**: Hive for persistent data with generated adapters
- **SSH/SFTP**: Custom dartssh2 fork for server connections
- **Terminal**: Custom xterm.dart fork for SSH terminal interface
- **Networking**: dio for HTTP requests
- **Charts**: fl_chart for server status visualization
- **Localization**: Flutter's built-in i18n with ARB files
- **Code Generation**: Uses build_runner with json_serializable, freezed, hive_generator, riverpod_generator

### Data Models

- Server management models in `lib/data/model/server/`
- Container/Docker models in `lib/data/model/container/`
- SSH and SFTP models in respective directories
- Most models use freezed for immutability and json_annotation for serialization

### Features

- Server status monitoring (CPU, memory, disk, network)
- SSH terminal with virtual keyboard
- SFTP file browser
- Docker container management
- Process and systemd service management
- Server snippets and custom commands
- Multi-language support (12+ languages)
- Cross-platform support (iOS, Android, macOS, Linux, Windows)

### State Management Pattern

- Uses Riverpod providers for dependency injection and state management
- Uses Freezed for immutable state models
- Providers are organized by feature in `lib/data/provider/`
- State is often persisted using Hive stores in `lib/data/store/`

### Build System

- Uses custom `fl_build` package for cross-platform building
- `make.dart` script handles pre/post build tasks (metadata generation)
- Supports building for multiple platforms with platform-specific configurations
- Many dependencies are custom forks hosted on GitHub (dartssh2, xterm, fl_lib, etc.)

### Important Notes

- **Never run code formatting commands** - The codebase has specific formatting that should not be changed
- **Always run code generation** after modifying models with annotations (freezed, json_serializable, hive, riverpod)
- Generated files (`*.g.dart`, `*.freezed.dart`) should not be manually edited
- AGAIN, NEVER run code formatting commands.
- USE dependency injection via GetIt for services like Stores, Services and etc.
- Generate all l10n files using `flutter gen-l10n` command after modifying ARB files.
- USE `hive_ce` not `hive` package for Hive integration.
  - Which no need to config `HiveField` and `HiveType` manually.
- USE widgets and utilities from `fl_lib` package for common functionalities.
  - Such as `CustomAppBar`, `context.showRoundDialog`, `Input`, `Btnx.cancelOk`, etc.
  - You can use context7 MCP to search `lppcg fl_lib KEYWORD` to find relevant widgets and utilities.
- USE `libL10n` and `l10n` for localization strings.
  - `libL10n` is from `fl_lib` package, and `l10n` is from this project.
  - Before adding new strings, check if it already exists in `libL10n`.
  - Prioritize using strings from `libL10n` to avoid duplication, even if the meaning is not 100% exact, just use the substitution of `libL10n`.
- Split UI into Widget build, Actions, Utils. use `extension on` to achieve this
- Android release signing:
  - Normal release builds must use the real release keystore from `key.properties`.
  - Debug-signing fallback is for local verification only and must be enabled explicitly with `-PallowDebugReleaseSigning=true`.
  - Do not use debug-signing fallback for formal release artifacts.
- Android release artifacts:
  - CI release builds for Android are split per ABI, not a single fat APK.
  - Do not judge release size from a local `flutter build apk --release` fat APK.
  - To reproduce CI-style Android artifacts locally, use `dart run fl_build -p android` or `flutter build apk --release --split-per-abi`.
