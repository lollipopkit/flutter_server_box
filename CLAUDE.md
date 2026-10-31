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
- Opt-in e2e, skipped when unset: `SBM_E2E_SSH_HOST` in `.env` + `cargo test -p sbm_parser --test ssh_e2e -- --ignored` (libvirt: `-p sbm_virt`); RDP: `SBM_E2E_RDP_{HOST,PORT,USER,PASSWORD}` + `cargo test -p sbm_ffi --lib rdp_e2e -- --ignored` (an alpine `xrdp xorgxrdp` container serves); `flutter test test/e2e/virt_real_test.dart` (variables in its header; dartssh2 has no ssh-agent, so use `SBM_E2E_SSH_IDENTITY` or `SBM_E2E_SSH_KEY_PASSPHRASE`).
- Widget tests whose tree writes a store: `openTestDb()` in `setUp`, `SqliteDb.close` in `tearDown`, the store's `forTest()` — many widgets persist on their own, and a real file write in fake-async hangs.
- Breakpoints: size `tester.view.physicalSize` + `devicePixelRatio`. `pumpAndSettle` never returns with a text field; use `pump(duration)`.

### CI

- `iOS Linux engine`, `macOS build`, `Windows build` (`analysis.yml`) are manual: `gh workflow run analysis.yml --ref <branch>`, and wait before marking a PR ready. Otherwise say in the PR they were not needed.
  - iOS: `ios/`, `third_party/`, `crates/sbm_ffi/`, `packages/{fl_tty,fl_pi_llm}`, `plain_notification_token`, `watch_connectivity`.
  - macOS / Windows: `macos/`, `windows/`, `hook/`, `crates/`, `Cargo.{toml,lock}`, `packages/{fl_tty,fl_pi_llm}`.
  - All three: `pubspec.{yaml,lock}`, `.github/actions/`, `analysis.yml`. Not on its own: `lib/`, `test/`, a pure-Dart submodule bump, a `pubspec` change that only names a pure-Dart package already in the lock (the lock's diff is `transitive` → `direct main`, no version or package change).
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
- **LK Cloud** (the lollipopkit account: IdP Rauthy at auth.lolli.tech, client `serverbox`; homebase at api.lolli.tech): the app is fl_lib's `LkcClient` (`lib/core/lkc.dart`, `Lkc.enabled`), the agent `crates/sbm_lkc` (device code, `monitor/src/lkc.rs`), which follows `LkcClient`. **Never refresh before the access token's last 45 s** (`LkcTokens.refreshWindow`, `sbm_lkc::REFRESH_WINDOW`): Rauthy takes an earlier refresh for a leak and ends every session of the person; a refresh the IdP refuses itself (a 4xx with its own `error` but a 429; Rauthy never says `invalid_grant`) signs out both (the app's `LkcClient` also on homebase's `perm`; the agent does not trust its clock with that). `cargo run -p sbm_lkc --example device_sign_in` signs in for real.
- Theme packages (`.fsbt`) and the theme store are read and checked in Rust, in fl_lib: `packages/fl_lib/rust/theme` (`fl_theme`, its own Cargo workspace), which the agent depends on by path and the app reaches through fl_lib's build hook. Flutter tests load `build/native_assets/<os>/libfl_lib_ffi.*`, which fl_lib's build hook writes (`test/flutter_test_config.dart`).
- `crates/sbm_ffi/` — FRB bindings. `crates/sbm_native/` — native sampler, monitor only.
- `monitor/` — the agent (Rust + Svelte panel), see `monitor/CLAUDE.md`. `monitor/sdk/`: what installed desk apps use: `serverbox-desk` (the bridge client, on npm; Apache-2.0 for closed third-party apps; it also puts the desk's design system, served by the agent, on the app's page) and a template. Machine pages are listed as `features` in `/capabilities`.
- `lib/core/` utilities, `lib/view/` UI, `lib/data/{model,provider,store}/`, `lib/src/rust/` generated, `lib/hive/` legacy adapters for `HiveImport` only (TODO: remove).
- `packages/` — Dart forks as submodules (dartssh2, xterm, fl_lib, fl_build, …) and the in-repo `webui`. `packages/fl_tty` — the shell on this device, shared with LLMBox: pty, rootfs (`Rootfs`, manifest), proot (Android) and ish-arm64 (iOS, `packages/fl_tty/third_party/ish-arm64`), all built by its hook; ServerBox sets it up in `lib/core/tty.dart` and names the device in `lib/core/utils/local_device.dart`. `third_party/` — `ironrdp`. `website/` — Svelte + bun.
- `third_party/ironrdp` is upstream IronRDP's **main** plus ServerBox's commits (branch `serverbox`, squash-merged; the commits live on the latest `patches/upstream-<sha>` tag); `sbm_ffi` takes every IronRDP crate from it by path, on ring. Following upstream: `docs/dev/ironrdp.md`.
- **The Agent is `packages/fl_pi_llm`** (submodule shared with GPT Box and the monitor, its own Cargo workspace; PR changes there). Memory, skills and MCP tools are its Rust (`rust/src/{memory,skills,mcp}.rs`); `ui` keeps files, fetching and the mcp_dart client. This app hooks in at `lib/core/llm/` (`LlmHost`, `AgentTools`, `AgentScope`/`TerminalHosts`/`AgentChats`). `.claude/skills/serverbox-help` ships as assets: a new file needs its directory in `pubspec.yaml`, and its docs links must exist (`builtin_skill_test.dart`). Tests load `build/native_assets/<os>/libfl_pi_llm.*`.
- Themes are fl_lib's (`package:fl_lib/theme.dart`); this app describes itself in `lib/core/service/theme_host.dart`. `SettingStore` keys are fixed — renaming one loses it. `store/` is the official theme repository (and `store/apps/`, the Monitor's web apps: the `serverbox-webapp` skill) (details: `docs/src/content/docs/development/themes.md`, the `serverbox-theme` skill); no store theme is bundled in the app (a committed `.fsbt` is a binary git cannot diff).
- `lollipopkit/shellbox-rootfs` is not a submodule: fl_tty reads its signed manifest (`packages/fl_tty/assets/rootfs_manifest.json` offline, URL and key `RootfsManifestConfig.shellbox`, verified by `RootfsManifestTrust`).
- `ScriptConstants.version` and the `v<N>` in `ScriptConstants.scriptFile` must stay equal.
- **A breaking change to the agent API raises `sbm_parser::protocol::PROTOCOL`**, and both sides keep answering / reading the previous one (`monitor/CLAUDE.md`).

### Connection methods

A server is reached over SSH, a monitor agent, both, or is this device (`Spi.local`).

- `Spix.transport` picks the lead (SSH when both, unless `preferredTransport`); `Spix.fallbackTransport` is the other. At least one is required (DB `CHECK`).
- **`ServerNotifier.ensureExec()` is the one place a command reaches a server**, falling back to the other transport; a monitor-only server never uses sshd. `ensureShellClient()` is SSH-only.
- **`ServerTcpDialer` is the one place a TCP connection from the server's side is made** (SSH direct-tcpip, the agent's `/stream/ws`, or local).
- A long-lived user of an agent (status poll, Monitor tab, web apps, files, Agent tasks, tunnels, forwards) holds the server's shared client through `MonitorClientLease` (one sign-in per agent); a provider that polls one goes through `AgentPoll` (one read at a time, none in the background).
- Ask `ServerCapabilities`, never the transport (both transports answer the union: `byteStream` for SFTP/forwards, `tcpRelay` for remote desktop/PVE); the agent itself is `Spix.monitor`.
- SSH is direct, jump server or `ProxyCommand` (`genClient`); host keys are always verified.

## Rules

- **Never run code formatters.**
- Git LFS holds images, fonts, `.fsbt` and PDFs under `monitor/`, `docs/`, `website/`, `store/` only: F-Droid clones without LFS, so nothing the app's build or `fastlane/` reads goes there (`.gitattributes`). `scripts/check-lfs.sh` fails a build that finds a pointer.
- Never hand-edit `*.g.dart` / `*.freezed.dart`. `flutter gen-l10n` after ARB edits; check `libL10n` (fl_lib) first.
- GetIt for stores and services. `fl_lib` widgets (`CustomAppBar`, `context.showRoundDialog`, `Input`, `Btnx.cancelOk`; context7 `lppcg fl_lib KEYWORD`). Split UI into build / actions / utils with `extension on`.

### Storage (`lib/data/store/CLAUDE.md` before any change)

- One encrypted SQLite file; Drift owns the DDL, queries are hand-written and synchronous. Ids as keys, never names; lists/maps are child tables; enums by name.
- **A schema step is three edits** (the class, `SchemaVersion.current`, `kSchemaMigrations`) plus a permanent test fed by data the previous release wrote; never regenerate a fixture to pass.
- **A backup is an age file** (fl_lib `AgeCryptor`: passphrase mode, armored, `age -d` opens it), gzip inside, under the versioned sync name `Miscs.bakFileName` (a build that cannot read a format must never see its file). `LKFL_ENC` (`Cryptor`) and the older names are read only (TODO: remove); `test/fixtures/backup/` holds one backup in every envelope, never regenerated.

### Tabs

- **A tab's single column is the subject**; the list moves behind a bar button (`view/page/benchmark/tab.dart`).
- **A narrow (one-column) tab bar is a `SwitcherBar`** (fl_lib): a `SessionSwitcherLabel` left, `BarAction`s right (folded into ⋮ when short; `BarAction.listen` for live state; `.button()` for a wide pane's own header). It keeps clear of the iPadOS window controls; a hand-built top bar must wrap itself in `WindowControlsInset`. Wide two-pane layouts keep their own headers.
- `detailId` is null at the root; give `leading` where the back button has nowhere to go; no `ref.watch`/`ref.listen` in `detailBuilder`; the subject is a widget, not a route.
- `AppTab` is positional; index 7 stays in `_retiredIndices`.

### Dialogs

- `showRoundDialog` uses the root navigator: close a dialog with `context.popDialog()` or a returning `Btn.ok`/`Btnx.cancelOk`, never `context.pop()`.
- **Trap: `Btn.ok(onTap: f)`** and `Input.onSubmitted` in a dialog — `f` must pop. Greps: `rg -U 'showRoundDialog[\s\S]*?context\.pop\(' lib`, `rg -n 'Btnx?\.\w+\(onTap:' lib`.
- **Trap: a page embedding `SSHPage`** inherits `PopScope(canPop: false)`; a plain `BackButton()` types Esc. Use `onPressed: () => context.pop()`.

## Feature notes

`crates/sbm_ffi/CLAUDE.md` (SSH crypto) · `ios/CLAUDE.md` · `macos/CLAUDE.md` · `android/CLAUDE.md` · `lib/data/store/CLAUDE.md` · `lib/data/model/file/CLAUDE.md` (SFTP/SCP) · `lib/data/model/server/benchmark/CLAUDE.md` · `lib/core/service/CLAUDE.md` (watch, home widgets) · `lib/view/page/server/monitor_settings/CLAUDE.md` · `monitor/CLAUDE.md` · `monitor/frontend/src/desk/CLAUDE.md` (the panel's desk). References in `docs/dev/`: `virt.md`, `monitor-api.md`, `monitor-permissions.md`, `desk.md`, `desk-sys.md`, `ironrdp.md`.
