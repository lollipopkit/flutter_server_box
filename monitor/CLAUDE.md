# CLAUDE.md

ServerBox Monitor: the agent (Rust, ntex, SQLite) that samples a machine, raises alerts, and serves the API and the Svelte panel. Part of the ServerBox monorepo (root `../CLAUDE.md`). **Per-endpoint behaviour: `docs/dev/monitor-api.md`**; access: `docs/dev/monitor-permissions.md`; the panel: `frontend/src/desk/CLAUDE.md`.

## Commands

```bash
cargo run                                   # serve on 0.0.0.0:3770; cp .env.example .env first
cargo test                                  # all backend tests (--test <name> for one)
cd frontend && npm run dev                  # panel on :3000, proxies /api (and the ws) to :3770
cd frontend && npm run build                # typesafe-i18n + svelte-check + vite build
cd frontend && npx vitest run               # from frontend/: from the repo root it picks up third_party/ironrdp and fails
cargo sqlx migrate run / cargo sqlx prepare # migrations; offline query cache in .sqlx/
```

## Layout

- `../crates/sbm_parser/`: commands, scripts and parsers shared with the app over FFI. Pure, no IO. `capabilities::capabilities(system)` says per `ServerStatus` field whether a platform collects it; check it before calling an empty field a bug.
- `../crates/sbm_native/`: the native sampler, always on the one `native-sampler` thread (Windows' sysinfo components are thread-bound WMI objects), feeding `sbm_parser::linux::parse_*` unchanged; GPUs every cycle, sensors/batteries/SMART on the extended cycle via the script; merged in `monitoring.rs::collect_metrics`.
- `src/`: `cli/`, `core/` (config, `fs_roots.rs`, `config_file.rs`, `blobs`), `api/` (`server.rs` the route table, `authz.rs`, `respond.rs`: `{"error": code}`, a cause logged and never sent; `require!` in `api/mod.rs`), `pty.rs`, `monitoring/`, `stacks/` (web apps, catalog `../store/apps/`), `agent_mode/`, `apps/` (desk app packages), `monitor_backup/`, `db/`, `utils/lock.rs` (`LockExt`: std locks taken through a poisoning).
- Filesystem work in a handler goes through `spawn_blocking` (`config_file::read_async`/`write_async`).
- `frontend/src/`: Svelte 5 runes, Tailwind 4, no router. Tests: vitest + testing-library; svelte-check is the type gate.
- `apps/<name>`: first-party desk app packages (guest crate + `wit/` + `ui/` + `manifest.json`), built and signed by `scripts/build-desk-app.sh <name> --store` into `../store/desk/` (embedded with `include_bytes!`).

### Cross-platform semantics left as is (changing them would change stored history)

- `cpu`: Linux cumulative ticks; BSD an instantaneous percentage in the tick fields; Windows a percentage accumulated into a synthetic counter. Any consumer branches on `SystemType` (`monitoring::adapt_cpu`).
- `sys`: a distro parser on Linux; BSD/Windows reuse `parse_hostname`. `os_id`/`os_id_like` are Linux-only.
- `uptime`: Linux/BSD normalised; Windows passes PowerShell's string through. `diskio` is cumulative 512-byte counters on both paths.

## Panel

- **State and UI only.** The panel never composes a shell command or parses output: it calls an agent endpoint, which builds and parses through `sbm_parser`. Sending text to `/exec` and parsing it in TypeScript is ruled out.
- First load is one locale's dictionary; `/assets/{name}` serves the hashed build `immutable` as the `.br`/`.gz` copies `npm run build` writes.
- An answer that arrives after the sidebar switched servers is dropped (`stale(serverId)`); anything that writes binds to the server it was opened on.
- **A panel an agent serves holds only that server** (`ServersStore.servedByAgent`, decided by `confirmSameOrigin()`'s probe; `import.meta.env.DEV` exempts the vite proxy).
- Cloudflare Pages: root `monitor/frontend`, `npm run build`, output `dist`; the build imports `monitor/sdk/serverbox-desk/src`, so it needs the whole repository. Node 24 (`frontend/.node-version`, Dockerfile, `monitor-release.yml` match). Each agent must allow the origin (`cors_allowed_origins`) and be reachable over HTTPS.

## Access

- **One account, signed in with its password alone; it may do what the system account the agent runs as may do.** No roles or grants: where it is installed decides the reach. Acting needs TLS or a loopback peer unless `allow_insecure`.
- `api/authz.rs` is the one place a request becomes a `Caller`. Every route that acts on or configures the machine or the agent takes `authz::acting_caller` (or `machine::gate`); `jwt_caller` alone is for the desk's own state and lists. `tests/permissions_api.rs::a_plaintext_link_only_reads` holds the list.
- A password change ends everything signed with the old one through `authz::end_account` (sessions, tickets, Agent mode tasks, relays, watch tokens). Logins are throttled per known device and audited.
- Retired config keys restrict nothing and are named in a startup warning (TODO remove).

## Rules every endpoint follows

- **A breaking API change raises `sbm_parser::protocol::PROTOCOL`** and keeps answering a client at `PROTOCOL - 1` in its shape (TODO-marked shims in `api::compat_v1`); additions go in `features`. The panel and the native widgets write the number themselves: `crates/sbm_parser/tests/protocol_clients.rs` keeps them equal.
- Machine endpoints: the command is built in Rust and run through `api::exec::run`, so `[remote_access.exec]` (timeout, output cap, body limit) bounds it; those limits are the operator's, never raised per request. Work that must outlive them starts detached and is polled.
- `machine::gate` is the one place the transport rule is asked and a refusal audited; refusals are `403 {"error":"forbidden"}`. Audit rows never hold a password, value or output.
- Root: `machine::as_root` (`sudo -S` with only the password on stdin, the script in `$SBM_ROOT_SCRIPT`); a script carrying a secret uses `machine::as_root_private` (0600 file). A rejected password is `sudo_rejected`.
- `machine::FEATURES` is every endpoint and `/capabilities` `features`; a client offers a page only when listed.
- **Tests never perform the real action on the machine running them** (power, cron save, firewall, users, benchmarks). Destructive e2e run on a throwaway PVE VM (`scripts/e2e-vm.sh`, `scripts/storage-e2e.sh`, `scripts/desk-vm-e2e.sh`).
- Credentials are write-only everywhere (push channels, providers, MCP headers, BMC, PVE): a GET answers `null`, a PUT `null` keeps the stored value.
- **A credential column is sealed** (`db::sealed`: AES-256-GCM under `credentials.key` beside the database): a new one goes in `sealed::FIELDS` (`every_credential_column_is_sealed`), is written through `Sealer::seal` and read through `Sealer::open`; one kept on a write is carried over as stored. A value the key no longer opens is asked for again (read as none, or `passwordRequired`), never sent. `config.toml`'s push credentials are the operator's to write: in clear, or `${NAME}` from the environment (`push::resolve`).
- **Files are never stored in the database** (`core::blobs`, named by SHA-256); a new table with a blob column goes into `blobs::NAMED`.
- `fs_roots::Protected`: the agent's own state (DB, blobs, `jwt.secret`, `credentials.key`, `config.toml`, `.env` files, the TLS key, Agent mode's directory) is never served by `/fs`.
- An unmatched `/api/v1/*` path is a JSON 404. An answer given before the request's body was read reads the rest first (`api::unread_body`), or ntex drops the connection.

## WebSocket traps (locked by tests)

- **Upgrades go through `api/ws/upgrade.rs`, not `ntex::web::ws::start`**: ntex caps frames at 64 KiB with no setting (TODO back when configurable).
- **Upgrade auth is a single-use ticket** (`api/ws/ticket.rs`): purpose-bound, ~30 s, burned even on a wrong secret.
- **`is_secure_transport` treats loopback as secure** and never reads `X-Forwarded-Proto`.
- **Terminal sessions outlive the socket**: the handle is a 256-bit bearer capability, memory-only; replay is incremental (`ready.since`). Terminal tests answer fish's DA and ConPTY's `ESC[6n` queries.
- **The terminal deliberately bypasses sshd**, so `install.sh` runs the agent as an ordinary account: that account is the reach.

## Configuration

- `.env` (DB URL, JWT secret, host/port, TLS) and `config.toml`. Sections are grouped by what they act on; the flat pre-Aug-2026 layout is not read (deliberate).
- Capacities derive from physical memory unless set. `core/config_file.rs` writes atomically with backups; callers hold `AppState.config_write` across read-modify-write. API reads go to the file on disk, not `AppState.config`.
- Env: `SBM_HOST`, `SBM_PORT`, `SBM_TLS_CERT`, `SBM_TLS_KEY`, `SBM_CORS_ORIGINS`, `DATABASE_URL`, `JWT_SECRET`, `RUST_LOG`.

## Release

- Test machines: `--profile monitor-test` (no fat LTO, incremental). Shipped: `--profile release-monitor` (`lto = "fat"`, `codegen-units = 1`).
- **`monitor/Dockerfile` builds outside the workspace** and passes profile settings as `CARGO_PROFILE_RELEASE_*`: anything added to a workspace profile must be repeated there. `nix/package.nix` builds inside it.
- Agent mode depends on `packages/fl_pi_llm` by path: CI, the Dockerfile and the release check out that submodule.
- **One crypto implementation, `ring`**: `cargo tree -i aws-lc-sys` must be empty; `monitoring::push::http_client` installs ring before reqwest.
- `install.sh install` (systemd user service; OpenRC with sudo; `--system` for root; `SBM_INSTALL_PKG=<path>` for an unreleased build). sbOS images: `monitor/os/` (never Ubuntu-based, no distribution name in an image's name).
