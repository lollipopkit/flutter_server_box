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

Pure parsing library shared with the Flutter app via FFI (see `../doc/adr/0001-monorepo-shared-parser.md`). Owns the command manifest (`commands.rs`) and per-platform parsers (`linux.rs`, `bsd.rs`, `windows.rs`). Behavior is locked to the Dart implementation by `tests/dart_compat.rs`. No IO, no async — parsers take raw command output and return structured status.

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
- **`core/`**: Configuration management (`config.rs`, `config_manager.rs`) with .env support and TOML/JSON config files
- **`api/`**: ntex-based web server (`server.rs`) and JWT auth (`auth.rs`)
- **`monitoring/`**: Metrics collection (`monitoring.rs`: `sbm_native::sample()` covers cpu/mem/swap/disk/diskio/net/uptime/host/sys every cycle via direct syscalls/procfs reads — see `../crates/sbm_native`; `nvidia-smi` runs as one targeted subprocess call every cycle; the shared generated script from `sbm_parser::script` only still runs on the slower extended cycle, for amd/sensors/SMART/battery — the only data that genuinely needs CLI tools), rule evaluation (`rules.rs`), push notifications with rate limiting (`push.rs`), velocity/timeseries analysis
- **`db/`**: SQLite initialization/migrations (`database.rs`) and data retention cleanup (`cleanup.rs`)
- **`utils/`**: Centralized error types (`error.rs`)

### Frontend (Svelte - `frontend/src/`)

- **Svelte 5 (runes)** with TypeScript and Tailwind 4 (class-driven dark mode)
- **`pages/`**: Login.svelte, Dashboard.svelte (App.svelte gates them by auth state; no router)
- **`components/`**: Spinner, StatCard, ThemeToggle
- **`lib/`**: fetch-based API client, module-level rune stores (auth/theme), Poller
- **`types/`**: TypeScript type definitions
- Tests: vitest + @testing-library/svelte; type gate via svelte-check (part of `npm run build`)
- Multi-server: the panel keeps a server list (per-server URL + session) in localStorage; it can be served by an agent itself (same-origin) or hosted statically (e.g. Cloudflare Pages) talking to several agents

### Hosting the panel on Cloudflare Pages

- Pages project settings: build command `npm install --prefix packages/webui && cd monitor/frontend && npm ci && npm run build`, output directory `monitor/frontend/dist`
  - The `npm install --prefix packages/webui` step is required: `@serverbox/webui` is a `file:../../packages/webui` dependency, and `npm ci` inside `monitor/frontend` only symlinks it — it never installs *webui's own* devDependencies (svelte, clsx, tailwind-variants, ...). Without this step `svelte-check` fails with "Cannot find module" for every file under `packages/webui/src` (same class of bug the Dockerfile hit — see `RUN npm install --prefix /app/packages/webui` there)
- Each agent must allow the panel origin: `cors_allowed_origins` in config.toml or `SBM_CORS_ORIGINS` env (comma-separated)
- Agents must be reachable over HTTPS (browser mixed-content policy): use the built-in TLS (`--cert/--key` / `SBM_TLS_*`) or a reverse proxy / Cloudflare Tunnel
- An agent without the panel: just don't ship `frontend/dist`; the API works standalone

### Key Design Patterns

1. **Async-first architecture**: Uses tokio for async runtime with concurrent tasks
2. **Type-safe database**: sqlx with compile-time query verification
3. **JWT authentication**: Secure token-based API access
4. **Configuration-driven monitoring**: Rules and push configs in TOML/env files
5. **Rate limiting**: Built-in rate limiting for push notifications
6. **Separation of concerns**: Clean module boundaries between monitoring, API, and notifications

### Configuration

Uses environment variables (.env file) and TOML config files:
- **Environment**: Database URL, JWT secret, server host/port, TLS settings
- **TOML Config**: Monitoring rules, push notification settings, thresholds
- **Configuration file**: Defaults to `config.toml` (with JSON fallback support for `config.json`)

### Database Schema

SQLite database with migrations in `migrations/`:
- System metrics history
- User authentication
- Configuration storage

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
# Install as systemd service
sudo ./install.sh install

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