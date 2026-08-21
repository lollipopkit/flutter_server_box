# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ServerBox Monitor is a Rust-based server monitoring application rewritten from Go, featuring a modern Svelte frontend. It monitors server status (CPU, memory, disk, network, temperature) and sends notifications via configurable push mechanisms (webhooks, iOS notifications) when thresholds are exceeded. This is part of the [ServerBox](https://github.com/lollipopkit/flutter_server_box) project ecosystem.

## Development Commands

### Building
```bash
# Build backend
cargo build

# Build for release
cargo build --release

# Build frontend
cd frontend && npm install && npm run build
```

### Running
```bash
# Run backend (listens on 0.0.0.0:3770 by default)
cargo run

# Run frontend dev server (separate terminal)
cd frontend && npm run dev

# Set up environment
cp .env.example .env
```

### Testing
```bash
# Run all backend tests
cargo test

# Run integration tests
cargo test --test integration_tests

# Run frontend tests
cd frontend && npm run test

# Run with coverage
cd frontend && npm run test:coverage
```

### Dependencies
```bash
# Backend dependencies
cargo update

# Frontend dependencies
cd frontend && npm install
```

### Database
```bash
# Run migrations (requires DATABASE_URL)
cargo sqlx migrate run

# Prepare SQL queries for offline compilation
cargo sqlx prepare
```

## Architecture

### Shared Parser (`../crates/sbm_parser/`, monorepo root)

Pure parsing library shared with the Flutter app via FFI (see the "Monorepo Layout" section of the root `../CLAUDE.md`). Owns the command manifest (`commands.rs`) and per-platform parsers (`linux.rs`, `bsd.rs`, `windows.rs`). Behavior is locked to the Dart implementation by `tests/dart_compat.rs`. No IO, no async — parsers take raw command output and return structured status.

`sbm_parser::capabilities::capabilities(system)` reports, per `ServerStatus` field, whether a platform `Supported`/`NotImplemented`/`HardwareDependent`-ly collects it — mechanically derived from `commands::commands(system)` wherever a field maps 1:1 to a command key, so it can't silently drift out of sync the way an empty field used to (no signal for "platform doesn't support this" vs "no hardware" vs "not refreshed yet"). Check this before assuming a `None`/empty field is a bug.

#### 已知的跨平台语义差异 (documented, not fixed — see `crates/sbm_parser/src/types.rs` and `lib.rs` doc comments for the authoritative version)

Several `ServerStatus` fields share one struct shape across `SystemType::{Linux,Bsd,Windows}` but carry different semantics per platform. Fixing these would change how already-deployed instances' historical data reads, so each is deliberately left as-is and only documented:

- **`cpu` (`CpuCore.user`/`idle`/...)**: Linux = real cumulative `/proc/stat` ticks (delta-over-time is correct); Bsd = an instantaneous percentage stored directly into the tick fields (never delta — the raw value already is the percentage); Windows = an instantaneous percentage *accumulated* onto the previous sample into a synthetic monotonic counter (`windows::parse_cpu`'s `prev` param). Three incompatible interpretations of the same fields — `monitor::monitoring::adapt_cpu` already branches on `SystemType` correctly; any new consumer must too.
- **`diskio` (`DiskIoPiece.sectors_read`/`sectors_write`)**: Linux = genuine cumulative sector counters (`/proc/diskstats`); Windows = already-computed bytes/sec rate divided by 512 and stored in the same "sectors" fields — not a cumulative count at all. A naive delta-over-two-samples on Windows data double-differentiates.
- **`sys`**: Linux uses a real distro-description parser (`common::parse_sys_version`, extracts `PRETTY_NAME`); Bsd/Windows repurpose the generic hostname-trimming helper (`common::parse_hostname`) against `uname -or`/`OsName` output — happens to work because those are single clean lines, but isn't a "system version" parser on those platforms.
- **`uptime`**: Linux/Bsd normalize the `uptime` command's varied output via `common::parse_uptime`; Windows pre-formats the duration string in PowerShell itself and the field just passes it through — presentation shape isn't guaranteed identical across platforms.

The shell-script collection path has been replaced with native per-platform sampling for the fields it can cover (`crates/sbm_native` — see below); this incidentally resolved both the `cpu` mismatch (`sysinfo`'s CPU percentage has consistent semantics across platforms) and the `diskio` mismatch (`sysinfo::Disk::usage()` is genuinely cumulative everywhere, unlike the old Windows script path's rate-mislabeled-as-sectors bug). These fixes only apply to **monitor's own native path** — `sbm_parser`'s script-based output (still used by the SSH-based Flutter app, and by monitor's own extended-cycle script for amd/sensors/SMART/battery) still has the documented mismatches, since changing that shared, App-facing behavior is out of scope here. `sys`/`uptime` still differ in string shape between native and script sources (unchanged — see their doc comments).

### Native Sampler (`../crates/sbm_native/`, monorepo root)

Monitor-only crate (the app never depends on it — it always collects over SSH and has no way to run native syscalls on a remote host). `sample(state, system) -> sbm_parser::ServerStatus` covers cpu/cpu_brand/mem/swap/disks/diskio/net/uptime/host/sys directly via syscalls (`sysinfo`, on Bsd/Windows) or direct procfs/sysfs reads feeding `sbm_parser::linux::parse_*` unmodified (on Linux, zero extra dependencies). Per-platform backends are `#[cfg(target_os)]` submodules within this one crate, not separate crates — multi-platform support is this crate's internal concern. `amd`/`sensors`/`nvidia`/`batteries`/`disk_smart` are left empty here on purpose: `nvidia` gets a dedicated one-off `nvidia-smi` subprocess call every cycle (`monitoring.rs::sample_nvidia`, no script generation involved), and the rest only refresh on monitor's slower extended cycle via the shared script (still genuinely needs CLI tools: amd-smi/rocm-smi, `sensors`, smartctl, platform battery queries). See `monitoring.rs::collect_metrics` for how the two sources merge into one `ServerStatus`.

### Backend (Rust - `src/`)

- **`main.rs`**: Application entry point, coordinates monitoring loop and web server
- **`cli/`**: clap-based CLI (`serve`, `config`, `cleanup` subcommands)
- **`core/`**: Configuration loading (`config.rs`) with .env support and TOML/legacy JSON config files
- **`api/`**: ntex-based web server (`server.rs`), JWT auth (`auth.rs`), login throttling (`ratelimit.rs`), and the WebSocket endpoints under `api/ws/` (see below)
- **`ssh/`**: shells for the browser terminal — `client.rs` (russh: connect/authenticate/PTY), `known_hosts.rs` (trust-on-first-use pinning of the local sshd), and `local_pty.rs` (the SSH-less path, a local PTY interface-compatible with the SSH one so both drive the same session machinery)
- **`monitoring/`**: Metrics collection (`monitoring.rs`: `sbm_native::sample()` covers cpu/mem/swap/disk/diskio/net/uptime/host/sys every cycle via direct syscalls/procfs reads — see `../crates/sbm_native`; `nvidia-smi` runs as one targeted subprocess call every cycle; the shared generated script from `sbm_parser::script` only still runs on the slower extended cycle, for amd/sensors/SMART/battery — the only data that genuinely needs CLI tools), rule evaluation (`rules.rs`), push notifications with rate limiting (`push.rs`), velocity/timeseries analysis
- **`db/`**: SQLite initialization/migrations (`database.rs`) and data retention cleanup (`cleanup.rs`)
- **`utils/`**: Centralized error types (`error.rs`)

### Frontend (Svelte - `frontend/src/`)

- **Svelte 5 (runes)** with TypeScript and Tailwind 4 (class-driven dark mode)
- **`pages/`**: Login.svelte, Dashboard.svelte (App.svelte gates them by auth state; no router)
- **`components/`**: Spinner, StatCard, ThemeToggle
- **`pages/Terminal.svelte`** + **`lib/terminal.svelte.ts`**: the in-browser terminal. The store owns the protocol and reconnect policy and knows nothing about xterm.js, which keeps the part worth testing free of a DOM; xterm is loaded by dynamic `import()` so it stays out of the main bundle
- **`lib/`**: fetch-based API client, module-level rune stores (auth/theme), Poller
- **`types/`**: TypeScript type definitions
- Tests: vitest + @testing-library/svelte; type gate via svelte-check (part of `npm run build`)
- Multi-server: the panel keeps a server list (per-server URL + session) in localStorage; it can be served by an agent itself (same-origin) or hosted statically (e.g. Cloudflare Pages) talking to several agents

### Hosting the panel on Cloudflare Pages

- Pages project settings (the live project's **root directory is `monitor/frontend`**, confirmed from a build log — not the repo root): build command `npm run build`, output directory `dist` (relative to the root directory, so this resolves to `monitor/frontend/dist`)
  - `@serverbox/webui` is a `file:../../packages/webui` dependency, so an install here only symlinks it — *webui's own* devDependencies (svelte, clsx, tailwind-variants, ...) are never fetched, and `svelte-check` reads its source. Without them it reports `Cannot find module` for every file under `packages/webui/src` and fails with 8 errors.
  - **`frontend/package.json` handles that in `prebuild`**, so a bare `npm run build` is enough and every builder gets it the same way. It used to be asked of each one instead — the Pages build command, `RUN npm install --prefix /app/packages/webui` in the Dockerfile — and Pages was found running a bare `npm run build`, failing on exactly this. A setting in a dashboard is not somewhere this repo can keep a build step.
  - If the root directory setting is ever changed to the repo root instead, use `cd monitor/frontend && npm ci && npm run build` with output directory `monitor/frontend/dist`.
  - `frontend/.node-version` pins Node for Pages, which reads it from the **root directory** — hence `monitor/frontend/`, not the repo root. 24 (Krypton) is the active LTS; a build log had it on 22.22.0, which node-build itself warns is "in LTS Maintenance mode and nearing its end of life". The Dockerfile (`node:24-alpine`) and `monitor-release.yml` (`node-version: 24`) are the same line. Whatever it says has to satisfy `vite` 8, which declares `^20.19.0 || >=22.12.0`.
- Each agent must allow the panel origin: `cors_allowed_origins` in config.toml or `SBM_CORS_ORIGINS` env (comma-separated)
- Agents must be reachable over HTTPS (browser mixed-content policy): use the built-in TLS (`--cert/--key` / `SBM_TLS_*`) or a reverse proxy / Cloudflare Tunnel
- An agent without the panel: just don't ship `frontend/dist`; the API works standalone

### Remote access (`api/ws/`, `ssh/`, `core/remote_access.rs`)

The WebSocket terminal reaches the local sshd. It is **off by default** and
configured only in `config.toml` (deliberately absent from `PUT /settings`, so
the panel password can't switch it on); shared admission checks live in
`api/ws/mod.rs`.
- **`POST /api/v1/exec`** — one command, its output, its exit code, for the
  pages that parse what a command printed (processes, units, containers,
  snippets, power). A request rather than a stream because none of those
  callers streams or types. Deliberately not the terminal endpoint with an
  `exec` frame: a PTY is one stream shared with what the user is typing, so a
  command written into it lands in their shell — which is why `terminal.rs`
  rejects such a frame, locked by a test. `{cmd, stdin?, env?}` in, `{exit_code,
  stdout, stderr, truncated, timed_out}` out: `stdin` is how a sudo password
  gets in with no terminal to type it into, and `env` is a field rather than
  `export` lines the caller prepends so a value never has to survive shell
  quoting. Output is capped (1 MiB per stream) and the command is killed after
  60s, both reported rather than silently applied. `tests/exec_api.rs`.
- **`GET/PUT /api/v1/custom-cmds`** — the user's custom status commands, which
  are files in `~/.config/server_box/custom_cmds` (`sbm_parser::script`) rather
  than anything in this agent's config. The same directory the app writes over
  SSH and the generated status script reads, so the panel and the app edit one
  set; the extended cycle picks up a change with nothing having to be told.
  A PUT replaces the whole set in order — the order is what is stored (the
  files' name prefixes), so a move has no smaller expression. **Writing is
  gated on `full_access`**, the same grant as the shell and `/exec`: a file in
  that directory is run on every extended cycle, so adding one is arranging for
  code to run as the agent's user. Reading needs only the panel login, and the
  response says `editable` so the editor can go read-only instead of failing on
  save. The store is `monitoring::custom_cmds` (write-aside-and-rename, stray
  files skipped, names never logged — only the audit `subject`).
- **`/api/v1/fs/*`** — list, stat, read, write, mkdir, rename, chmod, remove,
  for the app's file browser. Its own switch (`[remote_access.fs] enabled`), not
  folded into `full_access`: that grant means "a shell as the agent's user",
  this one means "these directories", and folding them would make the narrower
  thing cost the wider one.
  **`[remote_access.fs] roots` is the boundary and there is no default.** Every request is
  resolved to a canonical path — symlinks followed, `..` refused outright —
  and then checked component-wise against the roots (`core/fs_roots.rs`), so a
  link inside a root pointing at `/etc` is a refusal rather than a way out.
  Resolving *before* checking is the whole point; checking the string the
  client sent would pass `/srv/data/link/passwd`. Every refusal answers 403
  with the same body, and a path outside the roots is reported as absent, so
  the endpoint can't be used to map the filesystem one status code at a time.
  Writes stream to `<path>.sbm-part-<pid>-<n>` and rename, so an interrupted
  one leaves no half-file under the name something else is about to open.
  `GET /fs/roots` hands the roots themselves to an authenticated caller — the
  one endpoint here that answers about the confinement rather than about a path
  inside it. Not a hole in it: they are the operator's decision, every other
  handler re-resolves per request, and a client can discover them one 403 at a
  time anyway. It exists because without it a client can only start at `/`, be
  refused, and have nothing to show for it; the app's file browser turns this
  into the chips it offers on a refusal. It answers 403 when the API is off, so
  "no roots" can never be read as "no limit".
  `roots = ["/"]` makes this equivalent to a shell (anyone who can write
  `~/.ssh/authorized_keys` has one) and is warned about at startup.
  Known limitation, stated rather than papered over: resolution and use are two
  steps, so a symlink swapped in between them would be followed. Closing that
  needs `openat`+`O_NOFOLLOW` per component, which is not portable across the
  platforms monitor runs on — the roots are the real boundary.
  `tests/fs_roots.rs` locks every escape route.
- **`/api/v1/terminal/ws`** — the panel's terminal. The agent is an SSH *client*
  rather than a shell spawner, so a session carries the privileges of the SSH
  account the browser authenticated as; the panel password alone grants no
  shell. Frame type is the channel selector: Binary = PTY bytes, Text = control
  JSON (`api/ws/terminal.rs` documents the messages).

Things that are easy to get wrong here, and are locked by tests:

- **Auth for the upgrade is a single-use ticket** (`api/ws/ticket.rs`), not the
  JWT: browsers can't set headers on a WebSocket handshake, and a token in the
  query string lands in ntex's access log. Purpose-bound, ~30s, burned even on
  a wrong secret.
- **`is_secure_transport` treats loopback as secure** even without TLS. That is
  the same-host reverse proxy / `cloudflared` case, which really is encrypted;
  refusing it would push people to `terminal.allow_insecure` and switch the check off for
  genuinely plaintext setups too. It never consults `X-Forwarded-Proto`, which
  the client controls.
- **Terminal sessions outlive their WebSocket** (`api/ws/session.rs`) so a
  reconnect rejoins the same shell. The handle is a bearer capability for an
  *already authenticated* shell: 256 bits, bound to the panel account, constant-
  time compared, memory-only. An `attach` takes over from the previous
  connection rather than being refused — after a network drop the old socket
  often isn't known to be dead yet.
- **Replay is incremental.** The client reports how many bytes it has rendered;
  if that point is still in the ring buffer only the gap is sent, so the screen
  is never cleared for a short outage. `ready.since` is *the absolute position
  the following byte stream starts at* — echoing back `next_seq` instead would
  make the client double-count the replay. `ready` must also precede any output.
- **`full_access` is a deliberate reversal of the model above.**
  With `remote_access.full_access` on (default: Linux only), a panel login
  reaches the machine directly — a local PTY as the agent's own user, a command
  run as that user, a TCP connection made from it — with no sshd and no SSH
  credentials, so none of sshd's authentication, logging or second factor
  applies. `install.sh` therefore runs the agent as an **ordinary account** by
  default, whichever init system it finds: a `systemctl --user` service under
  systemd, and under OpenRC — which has no user services — a script in
  `/etc/init.d` with `command_user` set to the account that invoked `sudo`.
  The point is not where the service file lives; it is that "the agent's own
  user" is not root. The switch is checked at the moment of use
  (`AppState::full_access_allowed`), not only in the UI, since the UI is not
  a boundary. `DELETE /api/v1/remote-access/full-access` lets the panel turn
  it off and has no counterpart that turns it on — narrowing what the agent
  exposes is always safe, widening is a config-file decision.
  It is one switch and not one per feature: anyone who can open a shell can run
  anything in it and connect anywhere from it, so a grant that gives the
  terminal and withholds the rest withholds nothing.
- **Capacities are derived from physical memory** (`core/remote_access.rs`), not
  constants: monitor runs on everything from a 512 MiB VPS to a 256 GiB server.
  Explicit config always wins; the resolved values are logged at startup.

`tests/fake_sshd/` is an in-process SSH server, so `tests/terminal_ws.rs`
exercises the real connect → authenticate → PTY → data path without needing an
sshd on the machine running the tests. `a_real_sshd_produces_a_working_shell`
additionally targets a real one when `SBM_E2E_TERMINAL_*` is set, and is
silently skipped otherwise.

### Key Design Patterns

1. **Async-first architecture**: Uses tokio for async runtime with concurrent tasks
2. **Type-safe database**: sqlx with compile-time query verification
3. **JWT authentication**: Secure token-based API access
4. **Configuration-driven monitoring**: Rules and push configs in TOML/env files
5. **Rate limiting**: Hand-rolled sliding window for push notifications (`monitoring/push.rs`); failure-backoff throttling for `/login`, keyed by both source address and username (`api/ratelimit.rs`)
6. **Separation of concerns**: Clean module boundaries between monitoring, API, and notifications

### Configuration

Uses environment variables (.env file) and TOML config files:
- **Environment**: Database URL, JWT secret, server host/port, TLS settings
- **TOML Config**: Monitoring rules, push notification settings, thresholds
- **Configuration file**: Defaults to `config.toml` (with JSON fallback support for `config.json`)

Settings are grouped into subsections by **what they act on**, not by a shared
name prefix — `[remote_access.terminal]`, `[remote_access.fs]`,
`[monitoring.extended]`,
`[monitoring.extended.idle_pause]`. Two consequences worth knowing before
adding a key:

- Where a key lives is a claim about its scope, and the code is arranged to
  match: `allow_insecure` sits under `terminal` because the terminal is the
  only endpoint it gates, and `idle_pause` under `extended` because that is the
  only cycle it can pause. What stays at a section's own level is what more
  than one subsection reads (`ssh_addr`, `full_access`). Adding a key to the
  wrong level makes the file lie about what it does.
- The resolved runtime structs (`RemoteAccess`, with `Terminal`/`Fs`)
  mirror the file's shape, so `terminal.available()` and `fs.available()` are
  methods on the part they answer for.

The **flat pre-Aug-2026 layout is not read at all** (`fs_enabled`,
`terminal_enabled`, `idle_pause_enabled`, ...). serde
ignores unknown keys, so an old file parses and every switch in it silently
reverts to off — a deliberate hard cut, since the safe direction is "feature
disabled". `[server] name` and `[monitoring] push_rate` were also top-level Go
keys and moved into sections; `Config::legacy` still reads the Go agent's flat
`config.json` keys once, at the `config.json` → `config.toml` migration, and
`normalize()` clears them so they are never written back.

### Database Schema

SQLite database with migrations in `migrations/`:
- System metrics history
- User authentication
- Configuration storage
- `access_log` — who opened a terminal, from where, and whether it
  worked. Never records a credential; cleaned up by the existing
  `retention_policies` mechanism (`DataCleanupService::POLICY_TABLES`)
- `ssh_known_hosts` — the pinned host key of the sshd the terminal connects to

`core/config_file.rs` owns runtime writes to `config.toml`: atomic replace via
`rename`, bounded backups, and a diagnosable read error. Callers hold
`AppState.config_write` across the whole read-modify-write, since atomicity
alone doesn't stop two handlers clobbering each other's fields.

## Release and Deployment

### Docker
```bash
# Build with Docker
docker build -t server-box-monitor .

# Run with Docker
docker run -p 3770:3770 -v $(pwd)/data:/app/data server-box-monitor
```

### Installation
```bash
# systemd: as yourself, a `systemctl --user` service
./install.sh install

# OpenRC (Alpine): needs root to write /etc/init.d, but still runs the agent
# as the account you sudo'd from
sudo ./install.sh install

# Either one, as root: `--system`
sudo ./install.sh install --system

# Without a release to fetch — offline, or an unreleased build
SBM_INSTALL_PKG=/path/to/server-box-monitor ./install.sh install

# Manual production deployment
cargo build --release
cd frontend && npm run build
./target/release/server_box_monitor
```

### Environment Variables

- `SBM_HOST`: Server host (default: 0.0.0.0)
- `SBM_PORT`: Server port (default: 3770)
- `SBM_TLS_CERT`: TLS certificate path
- `SBM_TLS_KEY`: TLS private key path
- `DATABASE_URL`: SQLite database URL
- `JWT_SECRET`: JWT signing secret
- `RUST_LOG`: Logging level

## Common Development Tasks

### Adding New API Endpoints
Add routes in `src/api/server.rs` following the existing ntex pattern with JWT middleware.

### Adding New Monitoring Metrics
Extend `src/monitoring/monitoring.rs` and update the database schema with new migrations.

### Updating Frontend Components
Use existing patterns in `frontend/src/components/` with TypeScript and TailwindCSS.

### Fixing Database Issues
Ensure `DATABASE_URL` is set or run `cargo sqlx prepare` to update query cache for offline compilation.
