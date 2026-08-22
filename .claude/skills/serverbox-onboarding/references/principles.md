# How ServerBox works

A map, not a replacement for the documentation. The long explanations are in
`docs/src/content/docs/principles/` and `docs/src/content/docs/development/`;
the working rules for changing the code are in `CLAUDE.md` and
`monitor/CLAUDE.md`. What follows is the handful of decisions that explain the
most behaviour, so you can route to the right file in one step.

## The shape of it

The app is Flutter, layered: `lib/view/` renders, `lib/data/provider/` holds
Riverpod state, `lib/data/model/` and `lib/data/store/` are the data layer.
Status parsing is not Dart at all — it is a Rust crate shared with the
server-side agent, so both always agree about what a command's output means.

## A server is reached one way, and features ask rather than test

`ServerConnectCredential.fromSpi` picks by whether `Spi.monitorHttp` is set. A
monitor server carries no `SshCredential`; the edit page enforces the same
exclusivity with one switch.

What a transport can do is asked through `ServerCapabilities`, so a feature
needing a shell never has to know that "SSH" is the thing that provides one:

- `SshCapabilities` answers yes to everything except `storedHistory` — one
  connection already carries a shell, a PTY and a channel, and sampling starts
  when the app connects, so a page opened now starts with an empty buffer.
- `MonitorHttpCapabilities` answers with what the agent reported on
  `GET /api/v1/capabilities`. `byteStream` is false, which is why SFTP and port
  forwarding are absent: the agent has no endpoint that relays a connection to
  an address the app names. `storedHistory` is true, since the agent was
  sampling before the app asked.

`ServerNotifier.ensureExec()` is the single place that decides how a command
reaches a server. A monitor server never falls back to sshd — falling back
would mean asking for credentials the user deliberately did not give.
`ensureShellClient()` is the SSH path only, and uses a separate `TryLimiter`
key so a shell that will not open does not also stop the status page
refreshing.

Where the SSH byte stream comes from is a separate axis, resolved in `genClient`
(`lib/core/utils/server.dart`): direct, through a jump server, or through a
`ProxyCommand`. The last two are mutually exclusive. Everything above
`SSHSocket` is identical either way, and the app verifies the host key itself in
every case.

## Status parsing lives in Rust, and is pure

`crates/sbm_parser` owns the command manifest (command name → per-platform
command, `SrvBoxSep.<cmd>` segmenting), the parsers, and the script generation.
The app calls it through `crates/sbm_ffi` / flutter_rust_bridge; the monitor
links it directly. Parsers emit raw counters; anything windowed, such as
network speed, is a pure function over two samples, and the mutable time series
stays on the caller's side. **No mutable state crosses the FFI boundary.**

`commands::EXTENDED` (smartctl, AMD GPU) is split out of the fast path and run
minutes apart, because polling smartctl keeps a disk from ever spinning down.
The monitor additionally has `crates/sbm_native`, which samples cpu, memory,
disks, network and uptime through syscalls instead of shell commands — an
option the app does not have, since it is always looking at a remote host.

`crates/sbm_parser/tests/dart_compat.rs` locks the behaviour against the
original Dart implementation's fixtures. When porting anything else to Rust,
the rule is test-as-spec: port the fixtures first, assert the FFI result is
identical, delete the Dart last.

## Storage is one encrypted SQLite file

`store.db`, opened through `package:sqlite3` with the `sqlite3mc` cipher. Two
shapes, and which one a store uses is a decision:

- **`kv(store, key, value, updated_at)`** holds settings and history — a
  hundred unrelated preferences where adding one should stay a one-line change.
  `value` is JSON, so anything written here needs a `toJson`; `SqliteStore.set`
  answers `false` rather than throwing when it has none, which makes a missing
  one silent.
- **Entity tables** hold servers, private keys, snippets, port forwards,
  connection statistics and agent conversations, with foreign keys and indexes.

Conventions worth knowing before touching the schema:

- **A primary key is an id, never something the user typed.** A private key's id
  used to be its name, so renaming one detached every server pointing at it.
- **A list or map field is a child table**, not a JSON array in a column. A
  child carries no sync columns and moves with its parent.
- **`INSERT OR REPLACE` is wrong** on a row with sync columns or children: it
  deletes and reinserts, resetting `rev` and cascading the children away.
- **Enums are stored by name**, because an index silently changes meaning when
  a case is inserted and these values outlive the build that wrote them.
- **Drift owns the DDL and only the DDL.** Queries are hand-written and
  synchronous, because the UI reads a store while building.

`Tables.syncRoots` names what sync moves as a unit; each root carries
`updated_at` and `rev`, and a delete leaves a `tombstone` row, without which a
peer reads the absence as an addition and puts the record back.

Migrations are covered in `dev-setup.md` and, at length, in
`docs/src/content/docs/development/testing.md`. The short version: a migration
gets one pass over real user data and a bug there is silence, so each one keeps
a permanent test fed by bytes an older release actually wrote.

## State, and one navigator trap

Riverpod with code generation for providers, freezed for immutable models,
GetIt for service location. `docs/src/content/docs/principles/state.md` is the
long form.

The trap that has produced the most bugs: **`showRoundDialog` puts the dialog on
the root navigator**, while a page's `context` finds the navigator holding the
page — and inside a pane or a tab those differ. A `context.pop()` reached from a
dialog button closes the *page* and leaves the dialog on screen, and the awaited
future never completes. Close a dialog with `context.popDialog()`, or better,
let it answer: `await context.showRoundDialog<bool>(...)` with `Btnx.cancelOk`.
Passing an `onTap` to `Btn.ok` is what breaks it, because that replaces the
button's own correct navigator resolution.

## Cross-platform

Five platforms from one codebase, with two pieces of native machinery worth
knowing about:

- **`third_party/ish-arm64`** is a fork of iSH, the Linux userland the iOS build
  can run locally. It is off by default (`SBM_ISH=0`) and built out of tree by
  `scripts/build-ish-ios.sh`, which is why `flutter clean` breaks it.
- **CocoaPods is gone from iOS and macOS.** `hook/build.dart` and the
  `packages/flutter_pty` fork replaced the per-platform build integrations with
  Dart build hooks, so there is no `Podfile` and nothing to add one back to.

Localization is ARB files in `lib/l10n/`, reached through `l10n` for this
project and `libL10n` for the strings `fl_lib` already has. Prefer an existing
`libL10n` string even when the meaning is not an exact match.

## Which document answers which question

| Question | File |
|---|---|
| How the layers, connection methods and core systems fit together | `docs/src/content/docs/principles/architecture.md` |
| Connection flow, authentication, host key verification, session lifecycle | `docs/src/content/docs/principles/ssh.md` |
| File operations, path handling, transfers, editing | `docs/src/content/docs/principles/sftp.md` |
| Where terminal bytes come from, tabs, virtual keyboard, selection | `docs/src/content/docs/principles/terminal.md` |
| Provider types, update patterns, persistence, testing with Riverpod | `docs/src/content/docs/principles/state.md` |
| Where a file belongs in the tree | `docs/src/content/docs/development/structure.md` |
| Which generator to run and why an adapter is frozen | `docs/src/content/docs/development/codegen.md` |
| Test strategy, fixtures, integration tests | `docs/src/content/docs/development/testing.md` |
| The agent's API surface, remote access model, panel | `monitor/CLAUDE.md` |
| Rules for changing this codebase | `CLAUDE.md` |

The `docs/src/content/docs/` pages above each have a `zh/` counterpart, and
`scripts/check-locale-parity.mjs` fails the build when one is missing. The two
`CLAUDE.md` files are not documentation pages and have no translation — they
are instructions for whoever is changing the code.
