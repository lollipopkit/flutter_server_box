# Development setup

For building and running ServerBox from source. The user-facing install is
`app-usage.md`; deploying the agent on a server is `monitor-deploy.md`.

`CONTRIBUTING.md` is the short authoritative version of this file, and
`docs/src/content/docs/development/` (`building`, `codegen`, `testing`,
`structure`, `architecture`, `state`) is the long one. Prefer both over what is
written here whenever the checkout is available.

## Prerequisites

| Tool | Needed for | Where the requirement is written |
|---|---|---|
| Flutter (stable) >= 3.44.9 | Everything in the app | `environment:` in `pubspec.yaml` |
| Dart SDK >= 3.11.0 | Ships with Flutter | same |
| Rust 1.97.1 via rustup | `crates/sbm_ffi` is compiled into **every** app build | `crates/sbm_ffi/rust-toolchain.toml` |
| Node 24 | Monitor panel, docs site, project website | `monitor/frontend/.node-version` |
| Xcode / Android Studio / Visual Studio | Only the platform you build for | — |

Rust is the one people skip because the project looks like a pure Flutter app.
It is not: `hook/build.dart` builds the FFI crate through
`flutter_rust_bridge_hooks` and hands the library to the SDK as a code asset,
on all five platforms. `rustup` reads `rust-toolchain.toml` and installs the
pinned channel on first use, so the pin needs rustup rather than a distro
`rustc`.

Regenerating the FFI bindings additionally needs the codegen binary at the
matching version:

```sh
cargo install flutter_rust_bridge_codegen --version 2.13.0-beta.6
```

## Bootstrap

```sh
git clone https://github.com/lollipopkit/flutter_server_box
cd flutter_server_box
git submodule update --init --recursive   # packages/* are path dependencies
make deps                                 # flutter pub get
make run                                  # flutter run
```

Generated files (`*.g.dart`, `*.freezed.dart`, `lib/generated/l10n/`,
`lib/src/rust/`) are committed, so a fresh clone does not need `make gen`
before it will run. You need it after *changing* an annotated model.

`scripts/check-env.sh` in this skill verifies the four things that go wrong
here — toolchain versions, submodule state, whether `pub get` has run, and the
flutter_rust_bridge version parity — without changing anything.

## The loop

```sh
make run                    # or run from the IDE
make gen                    # after touching @freezed / @JsonSerializable / @riverpod / ARB
make analyze                # flutter analyze lib test integration_test
cargo build -p sbm_ffi      # before `make test`: one suite loads this dylib
make test                   # flutter test
cargo test --workspace      # sbm_parser, sbm_native, sbm_ffi, monitor
```

`cargo build -p sbm_ffi` is not optional before `flutter test`, and it is not
skipped when missing: `test/frb_parser_test.dart` throws
`sbm_ffi native library not found` and the suite fails. CI builds it between
analyzing and testing for the same reason.

`make gen` is `build_runner build --delete-conflicting-outputs` followed by
`flutter gen-l10n`. New user-facing strings go into `lib/l10n/app_en.arb`
first; other locales are edited by hand and partial translations are fine.

**Do not run formatters.** Match the style of the file you are editing.

**Do not start a second `flutter run`** when the app is already running from
the user's IDE — a second debug build competes for the same window. Connect
through the dart MCP server (`dtd` → `listDtdUris` → `connect` → `hot_reload`).
Anything running before `runApp` needs `hot_restart`, since a reload does not
re-run it.

### Tests that need something extra

| Suite | Needs |
|---|---|
| `flutter test test/frb_parser_test.dart` | `cargo build -p sbm_ffi` first — the test loads the dylib out of `target/` |
| `integration_test/*` | A connected device or simulator; `flutter test` alone never runs them |
| `cargo test -p sbm_parser --test ssh_e2e` | `SBM_E2E_SSH_HOST` in the workspace-root `.env`; silently skipped without it |
| `cargo test -p server_box_monitor --test terminal_ws` | `SBM_E2E_TERMINAL_*` for the real-sshd case; the in-process fake sshd covers the rest |
| `cd monitor/frontend && npm run test` | `npm ci` once; `npm run check` is the type gate |

Two traps specific to this suite, both of which produce a hang rather than a
failure:

- A widget test whose tree writes to a store must open the database **in
  memory** (`openTestDb()` from `test/helpers/test_db.dart`, `SqliteDb.close`
  in `tearDown`, the store's `forTest()` constructor). Widgets that persist on
  their own — the floating Agent, resizable panes — write without the test
  asking them to, so this applies to more trees than it looks like.
- `pumpAndSettle` never returns on a tree containing a text field or anything
  else that always schedules a frame; it gives up after its ten-minute default.
  Count frames with `pump(duration)` instead, and pass `--timeout 30s`.

### Storage migrations

A migration gets one pass over a user's records and is not repeatable, so a bug
there is silence rather than a crash. Every one keeps a permanent regression
test fed by bytes the release being migrated *from* actually wrote — the
fixtures in `test/fixtures/hive_v{1466,1480,1491}/`, read by
`test/hive_release_migration_test.dart`. Seeding through today's adapters only
proves today's code agrees with itself. Never regenerate a fixture to make a
failing test pass. `docs/src/content/docs/development/testing.md` has the
recipe for adding one.

## Monitor development

```sh
make monitor-dev     # backend on :3770, panel vite dev server on :3000
```

The first run installs the panel's dependencies. Run the two halves separately
when you need to:

```sh
cd monitor && cargo run -p server_box_monitor -- serve
cd monitor/frontend && npm run dev
```

- Config is `monitor/config.toml`, every key documented in
  `config.example.toml`; `cargo run -- config` prints the resolved values.
- The panel is served by the agent itself when `frontend/dist` exists, so a
  production build is `npm run build` in `monitor/frontend`.
- `npm run build` runs a `prebuild` that installs `packages/webui`'s own
  dependencies. `@serverbox/webui` is a `file:` dependency, so an ordinary
  install only symlinks it and `svelte-check` then cannot resolve anything
  under its `src/`. Run the npm script rather than calling vite directly.
- sqlx verifies queries at compile time: set `DATABASE_URL`, or refresh the
  offline cache with `cargo sqlx prepare`.
- `monitor/CLAUDE.md` is the detailed map of that side, including the remote
  access model and what its tests lock down.

## Building releases

```sh
make build PLATFORM=<android|ios|macos|linux|windows>   # dart run fl_build -p ...
```

- **Android release builds use the real keystore from `key.properties`.** The
  debug-signing fallback exists for local verification and has to be asked for
  explicitly with `-PallowDebugReleaseSigning=true`. Never use it for a release
  artifact.
- CI splits Android releases per ABI, so a local fat APK is not a fair size
  comparison. `dart run fl_build -p android` reproduces the CI shape.
- macOS DMG, notarisation and the Homebrew cask are `make release-macos-dmg`,
  `make package-dmg`, `make sync-homebrew-cask`; secrets come from
  `.env.release` (see `.env.release.example`).
- The monitor is released separately by the `workflow_dispatch`-only
  `monitor-release.yml`, under `monitor-v*` tags.

## Symptom to cause

| Symptom | Cause | Fix |
|---|---|---|
| `flutter pub get` fails on a missing path under `packages/` | Submodules not initialised | `git submodule update --init --recursive` |
| App throws in `RustLib.init` at startup | `flutter_rust_bridge` versions differ between `pubspec.yaml` and `crates/sbm_ffi/Cargo.toml` | Make them equal; both are pinned deliberately |
| `test/frb_parser_test.dart` cannot load the dylib | The FFI crate was never built | `cargo build -p sbm_ffi` |
| iOS link fails on `build/ish/build-ios-arm64/lib{ish,ish_emu,fakefs}.a` | `flutter clean` removed the out-of-tree engine build; the checkout still looks clean | `scripts/build-ish-ios.sh device` (also `simulator`, `macos`) |
| A Rust target silently builds for the host | That target is missing from `crates/sbm_ffi/rust-toolchain.toml` — not an error, a fallback | Add it to `targets` |
| `svelte-check` reports `Cannot find module` for `packages/webui/src/*` | vite or svelte-check was run directly, skipping the `prebuild` | `npm run build` in `monitor/frontend` |
| sqlx macros fail to compile | No `DATABASE_URL` and a stale offline cache | Set it, or `cargo sqlx prepare` |
| `flutter test` hangs with no output naming a file | A widget test wrote to a real on-disk database inside the fake-async zone | Use `openTestDb()` and `forTest()` |
| Changing a model breaks the Hive import | Generated adapters emit `fields[n] as String` for a new non-nullable field, so a box written before it fails to open | Freeze the type in `lib/hive/legacy_adapters.dart` instead of regenerating |

## Before pushing

```sh
make analyze
cargo build -p sbm_ffi
make test
cargo test --workspace
cd monitor/frontend && npm run test && npm run check   # only if you touched the panel
```

Commit messages are one lowercase prefix and an imperative description:
`feat:`, `fix:`, `docs:`, `opt.:`, `rm:`, `migrate:`, `refactor:`, `test:`,
`chore:`. Commit messages and code comments are written in English.

Editing the documentation site means editing both `docs/src/content/docs/**`
and its `zh/` mirror — the build runs `scripts/check-locale-parity.mjs` and
fails on a missing counterpart.

Every contributor signs the CLA once, by leaving a single comment on their
first pull request. `CONTRIBUTING.md` explains the two things that trip the
automated check: commits authored by an email not attached to the GitHub
account, and co-authored commits, where everyone signs.
