---
name: serverbox-onboarding
description: Orientation for ServerBox (flutter_server_box) — installing and using the app, deploying and configuring the ServerBox Monitor agent on a server, bootstrapping the Flutter + Rust + Node development environment, and explaining how the project actually works (SSH vs monitor HTTP, the shared Rust parser, SQLite storage, Riverpod state). Use this whenever someone asks how to install, set up, run, build, deploy, configure, contribute to, or understand any part of ServerBox or its monitor agent — including questions that never name the project outright, such as "how do I get this repo running", "pub get fails after cloning", "why is the terminal button missing on this server", "what does full_access actually grant", "where does the status data come from", or a first-time contributor asking where to start.
---

# ServerBox onboarding

ServerBox is a Flutter app (iOS, Android, macOS, Linux, Windows, watchOS) for
managing Linux, BSD and Windows servers: status charts, SSH terminal, SFTP,
containers, processes, systemd. The repository is a monorepo:

| Path | What it is |
|---|---|
| `lib/` | The Flutter app |
| `crates/sbm_parser` | Shared status parser — one source of truth for the command manifest and the parsing, used by the app over FFI and by the monitor |
| `crates/sbm_ffi` | flutter_rust_bridge binding crate, built into the app by `hook/build.dart` |
| `crates/sbm_native` | Native per-platform sampler, monitor only |
| `monitor/` | ServerBox Monitor: a Rust agent installed on a server, plus its Svelte panel |
| `packages/` | Vendored Dart forks, each a submodule, referenced by path from `pubspec.yaml` |
| `docs/` | The documentation site (Astro Starlight), English with a `zh/` mirror |

A server is reached over **SSH or through a monitor agent's HTTP API, never
both**. That single fact explains most "why can't I do X on this server"
questions — see `references/principles.md`.

## Work out which question this is first

People arrive at this project from two directions, and the answers barely
overlap. Read the one reference that matches, not all of them.

| The person wants to | Read |
|---|---|
| Install the app and connect it to a server | `references/app-usage.md` |
| Install, configure or secure the monitor agent on a server | `references/monitor-deploy.md` |
| Build and run the project from source, or contribute | `references/dev-setup.md` |
| Understand how something works, or why it was built that way | `references/principles.md` |

Mixed asks are common and the wording rarely says which is which. "The
terminal button disappeared" is the agent's capability model
(`monitor-deploy.md`), not a bug. "`flutter pub get` fails right after
cloning" is almost always uninitialised submodules (`dev-setup.md`). When it is
genuinely ambiguous, ask whether they are running ServerBox or working on it.

## The repository outranks this skill

Versions, ports and command names drift; a skill file that quietly disagrees
with the repo is worse than no skill. Inside a checkout, prefer these:

| Question | Authoritative file |
|---|---|
| What commands exist | `make help` (the `Makefile`) |
| Flutter / Dart minimum | `environment:` in `pubspec.yaml` |
| Rust channel and shipped targets | `crates/sbm_ffi/rust-toolchain.toml` |
| Node version | `monitor/frontend/.node-version` |
| Every agent config key | `monitor/config.example.toml` |
| Contribution rules and checks | `CONTRIBUTING.md` |
| Working rules for agents | `CLAUDE.md`, `monitor/CLAUDE.md` |
| User-facing documentation | `docs/src/content/docs/**` |

Outside a checkout the reference files here are the fallback. Say so when you
are answering from them — the numbers below were true when this was written and
nothing keeps them current.

`scripts/check-env.sh` reports what is installed against what the repo asks
for, and changes nothing. Run it before diagnosing a build failure by hand;
most first-run failures are one of the four things it checks.

## The commands that cover most of it

```sh
make deps        # flutter pub get
make run         # flutter run
make gen         # build_runner + gen-l10n — after touching any annotated model
make analyze     # flutter analyze lib test integration_test
make test        # flutter test
cargo test --workspace          # parser, native sampler, FFI, monitor
make monitor-dev                # agent API on :3770 + panel dev server on :3000
make build PLATFORM=<android|ios|macos|linux|windows>
```

Values as of writing: Flutter >= 3.44.9, Dart SDK >= 3.11.0, Rust pinned to
1.97.1 for the FFI crate, Node 24 for the monitor panel and the docs site.

## What costs people an afternoon

Each of these has bitten someone. The reason matters more than the fix, because
the symptom rarely names the cause.

- **Initialise submodules before fetching Dart dependencies.** `packages/*` are
  path dependencies, so `flutter pub get` fails on a missing directory rather
  than on anything that mentions submodules:
  `git submodule update --init --recursive`.
- **Rust is not optional, even for `flutter run`.** `hook/build.dart` compiles
  `crates/sbm_ffi` into every app build as a code asset. No Rust toolchain, no
  app.
- **`flutter_rust_bridge` is pinned to the same prerelease in two files** —
  `pubspec.yaml` and `crates/sbm_ffi/Cargo.toml`. When they disagree,
  `RustLib.init` throws at startup and the message does not mention versions.
- **Regenerate after changing an annotated model** (`freezed`,
  `json_serializable`, `riverpod`, hive): `make gen`. Never hand-edit
  `*.g.dart`, `*.freezed.dart` or anything under `lib/src/rust/`.
- **Never run a formatter.** The formatting in this codebase is deliberate, and
  a reformat buries the actual change in noise.
- **Do not start a second `flutter run`** when the user already has the app
  running from their IDE. Two debug builds compete for the same window and you
  end up inspecting an instance nobody is looking at. Hot reload through the
  dart MCP server instead (`CLAUDE.md` has the sequence).
- **`flutter clean` deletes the out-of-tree iSH engine build** and leaves a
  checkout that looks fine, so the next iOS build dies in the linker on three
  missing `.a` files. Only affects a checkout that turned `SBM_ISH` on.

## Answering "how does X work"

The deep explanations already exist in `docs/src/content/docs/principles/`
(architecture, ssh, sftp, terminal, state) — 250 to 400 lines each, and worth
reading rather than paraphrasing from memory. `references/principles.md` is the
map: what each one answers, plus the handful of design decisions that explain
the most behaviour, so you can route in one step instead of grepping.

When the answer is about code rather than design, read the code. The docs
describe intent; `lib/data/provider/`, `lib/data/store/` and
`monitor/src/api/` are what actually runs.

## Reference files

| File | Covers |
|---|---|
| `references/dev-setup.md` | Toolchain bootstrap, the run/test/build loop, monitor development, and a symptom-to-cause table for first-run failures |
| `references/monitor-deploy.md` | Installing the agent, `config.toml`, the security switches and what each one really grants, connecting the app, troubleshooting |
| `references/app-usage.md` | Where to download the app per platform, adding a server over SSH or through an agent, what each feature needs, where the advanced guides are |
| `references/principles.md` | How the app is put together and which document answers which question |
| `scripts/check-env.sh` | Read-only environment check: toolchain versions, submodules, dependency state, FFI version parity |
