# CLAUDE.md

Flutter app for managing servers, in a Rust workspace monorepo. Feature notes live in `CLAUDE.md` files next to the code (listed at the end).

## Commands

`make help` lists everything: `make deps`, `make run`, `make analyze`, `make gen` (build_runner + gen-l10n), `make build PLATFORM=<android|ios|macos|linux|windows>`, `make monitor-dev` (API :3770 + panel :3000).

### Development

- **The app is usually already running from the user's IDE — do not start a second `flutter run`.** Use the dart MCP server: `dtd` → `listDtdUris` → `connect` → `hot_reload` (`hot_restart` for anything before `runApp`).
- `dart run build_runner build` after changing an annotated model (freezed, json_serializable, hive, riverpod). A stale build cache **hangs** silently: `make gen-build-clean`; a killed run leaves `.dart_tool/build/lock/build_runner.lock`.
- `flutter run --release -PallowDebugReleaseSigning=true` — local Android release checks only.

### Testing

- `flutter test --timeout 30s` (`make test-one TEST=...`), `cargo test --workspace`.
- Kotlin: from `android/`, `./gradlew :app:testDebugUnitTest -x :app:compileFlutterBuildDebug`.
- `test/unit/` is split by **feature** (`ssh/`, `terminal/`, `file/`, `server/`, `virt/`, `monitor/`, …); `store/` is storage infrastructure, `app/` what belongs to no feature. Helpers: `test/helpers/`.
- Opt-in e2e, skipped when unset: `SBM_E2E_SSH_HOST` in `.env` + `cargo test -p sbm_parser --test ssh_e2e -- --ignored` (libvirt: `-p sbm_virt`); `flutter test test/e2e/virt_real_test.dart` (variables in its header; dartssh2 has no ssh-agent, so use `SBM_E2E_SSH_IDENTITY` or `SBM_E2E_SSH_KEY_PASSPHRASE`).
- Widget tests whose tree writes a store: `openTestDb()` in `setUp`, `SqliteDb.close` in `tearDown`, the store's `forTest()` — many widgets persist on their own, and a real file write in fake-async hangs.
- Breakpoints: size `tester.view.physicalSize` + `devicePixelRatio`. `pumpAndSettle` never returns with a text field; use `pump(duration)`.

### CI

- `iOS Linux engine`, `macOS build`, `Windows build` (`analysis.yml`) are manual: `gh workflow run analysis.yml --ref <branch>`, and wait before marking a PR ready. Otherwise say in the PR they were not needed.
  - iOS: `ios/`, `third_party/`, `crates/sbm_ffi/`, `scripts/build-ish-ios.sh`, `scripts/check-ish-linkage.sh`, `packages/{flutter_pty,fl_pi_llm}`, `plain_notification_token`, `watch_connectivity`.
  - macOS / Windows: `macos/`, `windows/`, `hook/`, `crates/`, `Cargo.{toml,lock}`, `packages/{flutter_pty,fl_pi_llm}`.
  - All three: `pubspec.{yaml,lock}`, `.github/actions/`, `analysis.yml`. Not on its own: `lib/`, `test/`, a pure-Dart submodule bump.
- Caches save from main only. A job's own `cargo` uses `Swatinem/rust-cache`; `flutter build`/`test` build `sbm_ffi` through the hook into `.dart_tool/hooks_runner` (env allowlist: no `RUSTC_WRAPPER`/`RUSTUP_TOOLCHAIN`), cached by `.github/actions/build-hook-cache`.

### Rust / FFI

- `cargo build -p sbm_ffi` before FFI tests (`test/helpers/rust_lib_helper.dart` loads it from `target/`) and after codegen.
- `flutter_rust_bridge_codegen generate` after changing `crates/sbm_ffi/src/api` (output `lib/src/rust/`, never edit). **Never run `flutter_rust_bridge_codegen integrate`.**
- `flutter_rust_bridge` in `pubspec.yaml` and `crates/sbm_ffi/Cargo.toml` must equal the codegen version, or `RustLib.init` fails. A bump is both manifests + `cargo install flutter_rust_bridge_codegen --version <v>` + regenerate.
- `crates/sbm_ffi/rust-toolchain.toml` lists every shipped target (a missing one silently builds for the host). Rust is built by `hook/build.dart`.

## Architecture

- **Rust owns what is said to a server; each client owns its state and UI.** Every command, its parser and its model live in Rust (`sbm_parser` and the crates split from it); the app calls them over FFI (`sbm_ffi`), the panel through the agent. Dart and Svelte never build a command or parse output. New features start in Rust. Exceptions: HTTP JSON clients (PVE API) and live protocols (tmux control mode). Worked example: system users (`sbm_parser::users`, `sbm_ffi::api::users`, Dart `UserManager`). Large models are FRB mirrors of `sbm_parser` types (`sbm_ffi::api::firewall`).
- `crates/sbm_parser/` — status command manifest, scripts, parsers (pure, raw counters; rates stay with the caller), locked by `tests/dart_compat.rs` / `script_compat.rs`. Porting: move a module's Dart tests to Rust first, delete the Dart side only once the FFI result matches. `ProcKill` checks a PID against the process table's `START_ID`.
- `crates/sbm_virt/` — one virtualization model for libvirt (pure command layer) and the PVE API client (session, TOTP, tickets, pinning, console; over a stream the caller dials: `TcpDial` agent, `LoopbackDial` app).
- `crates/sbm_redfish/` — the BMC client; app via `sbm_ffi::api::bmc`. Also decides PVE certificate pins (`certPinAccepts`); pins are SHA-256 lowercase hex.
- `crates/sbm_theme/` — `.fsbt` theme packages (fl_lib's validation, the seed → scheme of `ColorScheme.fromSeed`, the theme store); used by the agent, the app later through FFI (TODO).
- `crates/sbm_ffi/` — FRB bindings. `crates/sbm_native/` — native sampler, monitor only.
- `monitor/` — the agent (Rust + Svelte panel), see `monitor/CLAUDE.md`. `monitor/sdk/`: what installed desk apps use: `desk-sys` (the bridge client, Apache-2.0 for closed third-party apps; it also puts the desk's design system, served by the agent, on the app's page) and a template. Machine pages are listed as `features` in `/capabilities`.
- `lib/core/` utilities, `lib/view/` UI, `lib/data/{model,provider,store}/`, `lib/src/rust/` generated, `lib/hive/` legacy adapters for `HiveImport` only (TODO: remove).
- `packages/` — Dart forks as submodules (dartssh2, xterm, fl_lib, fl_build, flutter_pty, …) and the in-repo `webui`. `third_party/` — `ish-arm64`, `ironrdp`. `website/` — Svelte + bun.
- **The Agent is `packages/fl_pi_llm`** (submodule shared with GPT Box, its own Cargo workspace; PR changes there). This app hooks in at `lib/core/llm/` (`LlmHost`, `AgentTools`, `AgentScope`/`TerminalHosts`/`AgentChats`). `.claude/skills/serverbox-help` ships as assets: a new file needs its directory in `pubspec.yaml`, and its docs links must exist (`builtin_skill_test.dart`). Tests load `build/native_assets/<os>/libfl_pi_llm.*`.
- Themes are fl_lib's (`package:fl_lib/theme.dart`); this app describes itself in `lib/core/service/theme_host.dart`. `SettingStore` keys are fixed — renaming one loses it. `store/` is the official theme repository (details: `docs/src/content/docs/development/themes.md`, the `serverbox-theme` skill); **editing a theme bundled as `assets/store_themes/<id>.fsbt` means repacking it** (`theme_bundled_test.dart`).
- `lollipopkit/shellbox-rootfs` is not a submodule: the app reads its signed manifest (`assets/rootfs_manifest.json` offline, key `RootfsManifestTrust.publicKey`).
- `ScriptConstants.version` and the `v<N>` in `ScriptConstants.scriptFile` must stay equal.

### Connection methods

A server is reached over SSH, a monitor agent, both, or is this device (`Spi.local`).

- `Spix.transport` picks the lead (SSH when both, unless `preferredTransport`); `Spix.fallbackTransport` is the other. At least one is required (DB `CHECK`).
- **`ServerNotifier.ensureExec()` is the one place a command reaches a server**, falling back to the other transport; a monitor-only server never uses sshd. `ensureShellClient()` is SSH-only.
- **`ServerTcpDialer` is the one place a TCP connection from the server's side is made** (SSH direct-tcpip, the agent's `/stream/ws`, or local).
- Ask `ServerCapabilities`, never the transport (both transports answer the union: `byteStream` for SFTP/forwards, `tcpRelay` for remote desktop/PVE); the agent itself is `Spix.monitor`.
- SSH is direct, jump server or `ProxyCommand` (`genClient`); host keys are always verified.

## Rules

- **Never run code formatters.**
- Never hand-edit `*.g.dart` / `*.freezed.dart`. `flutter gen-l10n` after ARB edits; check `libL10n` (fl_lib) first.
- GetIt for stores and services. `fl_lib` widgets (`CustomAppBar`, `context.showRoundDialog`, `Input`, `Btnx.cancelOk`; context7 `lppcg fl_lib KEYWORD`). Split UI into build / actions / utils with `extension on`.

### Storage (`lib/data/store/CLAUDE.md`)

- One encrypted SQLite file; Drift owns the DDL, queries are hand-written and synchronous.
- **A schema step is three edits**: the class, `SchemaVersion.current`, `kSchemaMigrations`, plus a permanent test fed by data the previous release wrote; never regenerate a fixture to pass.
- **A constraint change is create-copy-drop-rename** (`m017`/`m028`): `foreign_keys` off outside the transaction, `legacy_alter_table` on.
- Ids as keys, never names. Lists/maps are child tables. Enums by name. Use `EntityStore.upsert`, not `INSERT OR REPLACE`. `SqliteStore.set` values need `toJson`. Non-user writes: `updateLastUpdateTsOnSet: false` / `at:`. `lib/hive/` adapters are frozen.

### Tabs

- **A tab's single column is the subject**; the list moves behind a bar button (`view/page/benchmark/tab.dart`).
- Bar: `SessionSwitcherLabel` left, `Btn.icon` at **18pt** right, labels as in the terminal tab.
- `detailId` is null at the root; give `leading` where the back button has nowhere to go; no `ref.watch`/`ref.listen` in `detailBuilder`; the subject is a widget, not a route.
- `AppTab` is positional; index 7 stays in `_retiredIndices`.

### Dialogs

- `showRoundDialog` uses the root navigator: close a dialog with `context.popDialog()` or a returning `Btn.ok`/`Btnx.cancelOk`, never `context.pop()`.
- **Trap: `Btn.ok(onTap: f)`** and `Input.onSubmitted` in a dialog — `f` must pop. Greps: `rg -U 'showRoundDialog[\s\S]*?context\.pop\(' lib`, `rg -n 'Btnx?\.\w+\(onTap:' lib`.
- **Trap: a page embedding `SSHPage`** inherits `PopScope(canPop: false)`; a plain `BackButton()` types Esc. Use `onPressed: () => context.pop()`.

## Feature notes

`crates/sbm_ffi/CLAUDE.md` (SSH crypto) · `ios/CLAUDE.md` · `macos/CLAUDE.md` · `android/CLAUDE.md` · `lib/data/store/CLAUDE.md` · `lib/data/model/file/CLAUDE.md` (SFTP/SCP) · `lib/data/model/server/benchmark/CLAUDE.md` · `lib/core/service/CLAUDE.md` (watch, home widgets) · `lib/view/page/server/monitor_settings/CLAUDE.md` · `docs/dev/virt.md` · `monitor/CLAUDE.md` · `monitor/frontend/src/desk/CLAUDE.md` (the panel's desk).
