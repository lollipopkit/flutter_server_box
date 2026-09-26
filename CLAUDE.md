# CLAUDE.md

Flutter app for managing servers, in a Rust workspace monorepo. Feature-specific notes live in `CLAUDE.md` files next to the code (listed at the end).

## Commands

`make help` lists everything. Common: `make deps`, `make run`, `make analyze`, `make gen` (build_runner + gen-l10n), `make build PLATFORM=<android|ios|macos|linux|windows>`, `make monitor-dev` (API :3770 + panel :3000).

### Development

- **The app is usually already running from the user's IDE — do not start a second `flutter run`.** Apply changes through the dart MCP server: `dtd` → `listDtdUris` → `connect` to this repo's instance → `hot_reload` (`hot_restart` for anything before `runApp`). `flutter run` only when no instance exists or the launch path is the subject.
- `dart run build_runner build` after changing any annotated model (freezed, json_serializable, hive, riverpod).
  - A build cache older than the tree **hangs** (0% CPU, no output) instead of failing: `make gen-build-clean`. A SIGKILLed run leaves `.dart_tool/build/lock/build_runner.lock`, and the next run waits on it silently.
- `flutter run --release -PallowDebugReleaseSigning=true` — local Android release verification only.

### Testing

- `flutter test` (`make test-one TEST=...`), `cargo test --workspace`. Use `--timeout 30s`.
- `test/unit/` is split by **feature**, not layer (`ssh/`, `terminal/`, `file/`, `server/`, `virt/`, `store/`, `monitor/`, `app/`, …). `store/` is storage infrastructure only; `app/` is what belongs to no feature. Helpers: `test/helpers/`.
- Opt-in e2e, silently skipped when unset:
  - SSH: `SBM_E2E_SSH_HOST` in the root `.env`, then `cargo test -p sbm_parser --test ssh_e2e -- --ignored`.
  - Virtualization (real libvirt/PVE hosts): `flutter test test/e2e/virt_real_test.dart`, variables in its header. dartssh2 cannot use an ssh-agent: an encrypted, agent-held key needs `SBM_E2E_SSH_IDENTITY` or `SBM_E2E_SSH_KEY_PASSPHRASE`.
- A widget test whose tree writes to a store opens the DB in memory: `openTestDb()` in `setUp`, `SqliteDb.close` in `tearDown`, the store's `forTest()`. Widgets persist on their own (pane widths, Agent mode), so this covers more trees than it looks like; a real file write in a fake-async zone hangs the run.
- Size the view, not the surface, for breakpoints: `tester.view.physicalSize` + `devicePixelRatio`.
- `pumpAndSettle` never returns with a text field or other always-scheduling widget — count frames with `pump(duration)`.

### Rust / FFI

- `cargo build -p sbm_ffi` before FFI tests (`test/helpers/rust_lib_helper.dart` loads the dylib from `target/`), and again after codegen.
- `flutter_rust_bridge_codegen generate` after changing `crates/sbm_ffi/src/api` (output `lib/src/rust/`, do not edit). **Never run `flutter_rust_bridge_codegen integrate`** — it reformats every package and submodule.
- `flutter_rust_bridge` is pinned in `pubspec.yaml` and `crates/sbm_ffi/Cargo.toml`; both must equal the codegen version that generated `lib/src/rust/`, or `RustLib.init` fails at launch. Bumping = both manifests + `cargo install flutter_rust_bridge_codegen --version <v>` + regenerate (Dependabot does only the first).
- `crates/sbm_ffi/rust-toolchain.toml` lists every shipped target; a missing one silently builds for the host. App builds compile Rust through `hook/build.dart` (no plugin, podspec or `Package.swift`).

## Architecture

- `crates/sbm_parser/` — single source of truth for the status command manifest, script generation and parsing; used by the app via FFI and by the monitor. Parsers are pure and emit raw counters; rates and time series stay with the caller. Locked by `tests/dart_compat.rs` / `script_compat.rs`. Porting rule ("test as spec"): port a module's Dart fixture tests to Rust first, delete the Dart side only after the FFI result is asserted identical.
  - The process table's `START_ID` column is what `ProcKill` checks a PID against; without it every stop silently answers "not available".
- `crates/sbm_ffi/` — FRB bindings. `crates/sbm_native/` — native sampler, monitor only (the app always collects remotely).
- `monitor/` — server-side agent (Rust + Svelte), own `monitor/CLAUDE.md`. Serves status plus opt-in `POST /exec`, `/terminal/ws`, `/fs/*`, `/stream/ws`.
- `lib/core/` utilities; `lib/view/` pages and widgets; `lib/data/{model,provider,store}/` models (freezed), Riverpod providers, stores; `lib/src/rust/` generated; `lib/hive/` legacy adapters kept only for `HiveImport` (TODO: remove with it).
- `packages/` — vendored Dart forks as submodules (dartssh2, xterm, fl_lib, fl_build, flutter_pty, redfish, …); `packages/webui` is an in-repo Svelte package. `third_party/` — `ish-arm64` (iOS Linux engine, C/meson) and `ironrdp`. `website/` — Svelte + bun.
- `lollipopkit/shellbox-rootfs` is deliberately **not** a submodule: the app consumes its signed release manifest at runtime. `assets/rootfs_manifest.json` is the offline floor; the signing key's public half is `RootfsManifestTrust.publicKey`.
- `fl_build` regenerates `lib/data/res/build_data.dart` on every build; `ScriptConstants.version` and the `v<N>` in `ScriptConstants.scriptFile` must stay equal.

### Connection methods

A server is reached over SSH, a `monitor` agent's HTTP API, both, or is this device (`Spi.local`).

- `Spix.transport` resolves which leads (SSH when both, unless `preferredTransport` says otherwise; a preference for an unconfigured transport is ignored); `Spix.fallbackTransport` is the other. A server must have at least one (`noConnectionMethod`, DB `CHECK`).
- **`ServerNotifier.ensureExec()` is the one place a command reaches a server** (`SshExec` / `MonitorExec` over `/api/v1/exec` / `ProcessExec`), falling through to the second transport on failure. A monitor-only server never falls back to sshd. `ensureShellClient()` is SSH-only.
- **`ServerTcpDialer` (`lib/core/utils/server_tcp.dart`) is the one place a TCP connection to an address as seen from the server is made**: SSH direct-tcpip, the agent's `/stream/ws` relay (needs its `stream` grant), or a direct socket for local. Remote desktop and PVE use it.
- Ask `ServerCapabilities`, never the transport type. A both-transports server answers the **union**. Notably `byteStream` (SSH channel: SFTP, port forward) vs `tcpRelay` (either transport: remote desktop, PVE). Anything needing the agent itself reads `Spix.monitor`.
- When two transports can both do a thing, `Spix.transport` picks (terminal, file browser, `VirtKey.tmux`, the Agent's shell pane).
- The SSH byte stream is direct, jump server, or `ProxyCommand` (mutually exclusive), resolved in `genClient`; host keys are verified by the app in every case.

## Rules

- **Never run code formatters.**
- Run codegen after changing annotated models; never hand-edit `*.g.dart` / `*.freezed.dart`. `flutter gen-l10n` after ARB edits; check `libL10n` (fl_lib) before adding a string.
- GetIt for stores and services. Use `fl_lib` widgets (`CustomAppBar`, `context.showRoundDialog`, `Input`, `Btnx.cancelOk`; search with context7 `lppcg fl_lib KEYWORD`). Split UI into build / actions / utils with `extension on`.

### Storage (details: `lib/data/store/CLAUDE.md`)

- One encrypted SQLite file. Drift owns the DDL only; queries are hand-written and synchronous.
- **A schema step is three edits**: the class, `SchemaVersion.current`, `kSchemaMigrations`. Every migration keeps a permanent regression test fed by data the previous release actually wrote; never regenerate a fixture to make a test pass.
- **Changing a constraint is create-copy-drop-rename** (`m017`/`m028`): `foreign_keys` off outside the transaction and back on after, `legacy_alter_table` on — `server` parents six cascading tables.
- Primary keys are ids, never user-typed names. Lists/maps are child tables (no sync columns; editing one stamps the parent). Enums are stored by name.
- `INSERT OR REPLACE` is wrong on rows with sync columns or children — use `EntityStore.upsert`. A value passed to `SqliteStore.set` needs a `toJson`, or it is dropped silently.
- Non-user writes pass `updateLastUpdateTsOnSet: false` / an explicit `at:`. Models with a `lib/hive/` adapter get frozen legacy types, never regenerated adapters.

### Tabs

- **A new tab's single column is the subject, not its list of records**: `listBuilder` branches on `split`; one column shows the subject and the list moves behind a bar button (sheet). Worked example: `view/page/benchmark/tab.dart`.
- Bar = `SessionSwitcherLabel` on the left, `Btn.icon` actions at **18pt** on the right, same labels as the terminal tab for the same controls.
- Easy to get wrong: `detailId` must be null when the root shows; pass an explicit `leading` where `CustomAppBar`'s back button has nowhere to go; don't `ref.watch`/`ref.listen` inside `detailBuilder` (different element); the subject is a widget, not a pushed route.
- `AppTab` is positional; index 7 (was `monitorSettings`, now `virt`) stays in `_retiredIndices` — see its doc comment.

### Dialogs

- A dialog's buttons close the dialog; the page is closed by the code that awaited it. `showRoundDialog` uses the root navigator, so `context.pop()` from a dialog closes the page instead. Use `context.popDialog()`, or let `Btn.ok`/`Btnx.cancelOk` return a value.
- **Trap: `Btn.ok(onTap: f)`** — `f` must pop the dialog itself (same for `Input.onSubmitted` in a dialog). First-pass greps: `rg -U 'showRoundDialog[\s\S]*?context\.pop\(' lib`, `rg -n 'Btnx?\.\w+\(onTap:' lib`.

## Feature notes

`crates/sbm_ffi/CLAUDE.md` (native SSH crypto) · `ios/CLAUDE.md` (privacy manifests, iSH engine, LLDB) · `macos/CLAUDE.md` (per-arch builds, deployment target) · `android/CLAUDE.md` (foreground service, signing, reproducible builds) · `lib/data/store/CLAUDE.md` · `lib/data/model/file/CLAUDE.md` (SFTP/SCP) · `lib/data/model/server/benchmark/CLAUDE.md` (yabs) · `lib/core/service/CLAUDE.md` (watch and home widgets) · `lib/view/page/server/monitor_settings/CLAUDE.md` · `virt.md` (Virtualization tab) · `monitor/CLAUDE.md`.
