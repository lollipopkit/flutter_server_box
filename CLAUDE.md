# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

A `Makefile` wraps most common tasks — run `make help` for the full list. Preferred shortcuts:

- `make deps` / `make run` / `make analyze` (`flutter analyze lib test integration_test`)
- `make gen` - build_runner + gen-l10n in one step
- `make build PLATFORM=<android|ios|macos|linux|windows>` - wraps `dart run fl_build -p PLATFORM`
- Release packaging (macOS DMG, Homebrew cask sync): `make release-macos-dmg`, `make package-dmg`, `make sync-homebrew-cask`

### Development

- **The app is normally already running from the user's IDE (VS Code, F5). Do not start another `flutter run`** — a second debug build competes for the same window, and you end up looking at an instance the user is not. Apply changes through the dart MCP server: `dtd` → `listDtdUris` → `connect` to the instance whose workspace root is this repo, then `hot_reload` with the app's URI from `listConnectedApps`.
  - Changes to `main()`, or anything else that runs before `runApp`, need `hot_restart`: a reload does not re-run them.
  - `flutter run` is still the right call when there is no such instance, or when the point is the launch path itself (a first-launch migration, `_initApp` ordering).
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
- SSH e2e (opt-in): set `SBM_E2E_SSH_HOST=<ssh destination or ~/.ssh/config alias>` in the workspace-root `.env`, then `cargo test -p sbm_parser --test ssh_e2e` — uploads the generated script to the remote, runs it, and compares the parsed result against direct command output; silently skipped when unset
- A widget test whose tree writes to a store must open the Hive box **in memory**: `Hive.openBox<dynamic>('setting_test', bytes: Uint8List(0))`. A `testWidgets` body runs in a fake-async zone, and a real file write started there completes on a callback that zone is no longer pumping — so the box's write lock is never released, `box.close()` in `tearDown` blocks forever, and `flutter test` waits on that process. One such test hangs the whole run, with no failure and no output to say which file did it. Widgets that persist on their own (the floating Agent writes its mode on every change, panes write their width on every drag) hit this without the test writing anything itself.
- Size the view, not the surface, when a test depends on a breakpoint: `tester.view.physicalSize` + `devicePixelRatio`. `setSurfaceSize` changes what the tree is laid out in but not what `MediaQuery` reports, so a "phone" test written that way silently exercises the desktop rendering.
- `pumpAndSettle` is not usable on a tree containing a text field or another always-scheduling widget: it waits for a frame in which nothing is scheduled, and then gives up after its 10-minute default. Count the frames out with `pump(duration)` instead. `--timeout 30s` keeps any such mistake from costing ten minutes.

### Rust / FFI

- `cargo build -p sbm_ffi` - Build the FFI crate; required before running `flutter test test/frb_parser_test.dart` (`test/rust_lib_helper.dart` loads the dylib from `target/`)
- `flutter_rust_bridge_codegen generate` - Regenerate FRB bindings after changing `crates/sbm_ffi/src/api` (config: `flutter_rust_bridge.yaml`; Dart output `lib/src/rust/`, do not edit generated code)
- App builds link Rust via cargokit inside `crates/sbm_ffi/` (the crate and the Flutter FFI plugin glue share one directory), pinned to `flutter_rust_bridge: 2.12.0` in pubspec

## Architecture

This is a Flutter application for managing Linux servers with the following key architectural components:

### Monorepo Layout (Rust workspace)

- `crates/sbm_parser/` - Shared status parser (single source of truth for command manifest + parsing; used by both the app via FFI and the server-side monitor). Behavior locked by `crates/sbm_parser/tests/dart_compat.rs`
  - Parsing is pure functions: parsers emit raw counters; diff/windowed computation (speeds etc.) is provided as pure functions, mutable time-series state stays on the caller side. The FFI boundary holds no mutable state.
  - The command manifest (cmd name → per-platform command, `SrvBoxSep.<cmd>` segmenting) lives here too; the `commands::EXTENDED` keys (smartctl, AMD GPU) are split out of the fast status function into `SbStatusExt`, which both callers run minutes apart — smartctl at poll frequency keeps a disk from staying spun down
  - Script generation is shared as well (`script.rs`: build/install/exec commands + output splitting, locked by `tests/script_compat.rs`); the app calls it via FFI and merges the two functions' output, the monitor executes the script locally on its extended cycle
- `crates/sbm_ffi/` - flutter_rust_bridge binding crate + cargokit Flutter plugin glue in one directory (Dart side generated into `lib/src/rust/`)
- `monitor/` - Server-side monitoring service (Rust + Svelte frontend), has its own `monitor/CLAUDE.md`
  - It can also relay SSH for the app (`SshCredential.viaMonitor`, off by default on both sides) and serve an in-browser terminal — see the "Remote access" section there for the security model
- Root `Cargo.toml` is the workspace; build/test all Rust with `cargo test --workspace`
- FFI parity test: `flutter test test/frb_parser_test.dart` (requires `cargo build -p sbm_ffi` first)
- Migration rule ("test as spec"): before moving a parsing module to Rust, port its Dart fixture tests to Rust; only delete the Dart implementation after the FFI result is asserted identical against the same fixtures
- Remaining migration work: CI cross-compile verification for all five platforms

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
- `packages/` - Vendored Dart forks referenced by path from pubspec (dartssh2, xterm, fl_lib, fl_build, etc.), each a submodule
- `third_party/ish-arm64` - The iOS Linux engine, a submodule of the `lollipopkit/ShellBox` fork. Not in `packages/` because it is C built by meson and consumed by the Xcode project rather than by pubspec. Which revision builds is the gitlink, not a hash in a script: move it with `git submodule update --remote third_party/ish-arm64` and `git add`. `scripts/build-ish-ios.sh` builds it out of tree into `build/ish/build-<arch>/`, so a build never leaves the submodule dirty
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

### Connection methods

A server is reached over SSH, over a `monitor` agent's HTTP API, or both — see
`ServerConnectCredential` and `ServerCapabilities`. The UI asks capabilities
rather than testing which transport is in use, so a feature needing a shell
never has to know that "SSH" is the thing that provides one.

Where the SSH byte stream comes from is a separate axis, resolved in
`genClient` (`lib/core/utils/server.dart`): direct, through a jump server,
through a `ProxyCommand`, or — for hosts whose SSH port isn't reachable —
relayed by that server's monitor agent (`SshCredential.viaMonitor`,
`MonitorTunnelSocket`). At most one applies; `Spix.validate()` enforces that.
Everything above `SSHSocket` is unchanged either way, which is why terminal,
SFTP, containers and port forwarding all work over the tunnel without knowing
it exists — and why this app still verifies the host key itself, so the agent
in the middle can't impersonate the server.

Monitor-backed servers connect SSH **lazily**, on first shell use
(`ServerNotifier.ensureShellClient`): holding a tunnel open for every server
that merely *could* open a terminal would defeat the point of polling over
HTTP. Their shell failures use a separate `TryLimiter` key (`${id}#shell`), so
a host with no sshd doesn't also stop the status page refreshing.

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
- A dialog's buttons close the dialog. The page is closed by the code that awaited it.
  - `showRoundDialog` puts the dialog on the **root** navigator. A page's `context` finds the navigator holding the *page*, and inside a pane or a tab those are two different navigators. So a `context.pop()` reached from a dialog button closes the page and leaves the dialog on screen — and the awaited future never completes, so whatever the caller meant to do next never runs either.
  - Close the dialog with `context.popDialog()`, which is explicit about the root navigator. Better, let the dialog answer: `Btn.ok`/`Btnx.cancelOk` already pop a value, so `await context.showRoundDialog<bool>(...)` returns it.
  - Then do the work and close the page in the *caller*, which is on the page. A callback that does both sees two navigators and has to get each `pop`'s target right, silently.
  - **The trap is `Btn.ok(onTap: f)`.** With no `onTap`, `Btn` resolves the navigator from the *button's* own context — inside the dialog — and is correct. Passing an `onTap` replaces that, so `f` must pop the dialog itself. Every instance found so far was this, and so was `onSubmitted:` on an `Input` in a dialog.
  - **The rule is about what a button reaches, not about what is lexically inside the call.** Nine of the ten instances found in Aug 2026 called a named function that popped several lines away, which is why this grep found none of them — including `_showTextDialog` in `setting/entry.dart`, the shared helper most settings dialogs go through:
    - `rg -U 'showRoundDialog[\s\S]*?context\.pop\(' lib` — a first pass only. Clean does not mean correct.
    - `rg -n 'Btn\.ok\(onTap:|Btnx?\.\w+\(onTap:' lib` — the candidates worth reading. For each, follow the callback and check that every `pop` in it is a `popDialog`.
- Android release signing:
  - Normal release builds must use the real release keystore from `key.properties`.
  - Debug-signing fallback is for local verification only and must be enabled explicitly with `-PallowDebugReleaseSigning=true`.
  - Do not use debug-signing fallback for formal release artifacts.
- Android release artifacts:
  - CI release builds for Android are split per ABI, not a single fat APK.
  - Do not judge release size from a local `flutter build apk --release` fat APK.
  - To reproduce CI-style Android artifacts locally, use `dart run fl_build -p android` or `flutter build apk --release --split-per-abi`.
