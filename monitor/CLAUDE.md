# CLAUDE.md

ServerBox Monitor: the agent (Rust, ntex, SQLite) that samples a machine, raises alerts, and serves the API and the Svelte panel. Part of the ServerBox monorepo (root `../CLAUDE.md`).

## Commands

```bash
cargo run                                   # serve on 0.0.0.0:3770; cp .env.example .env first
cargo test                                  # all backend tests (--test <name> for one)
cd frontend && npm run dev                  # panel on :3000, proxies /api (and the ws) to :3770
cd frontend && npm run build                # typesafe-i18n + svelte-check + vite build
cd frontend && npx vitest run               # run vitest from frontend/: from the repo root it picks up third_party/ironrdp and fails
cargo sqlx migrate run / cargo sqlx prepare # migrations; offline query cache in .sqlx/
```

## Layout

- `../crates/sbm_parser/`: commands, scripts and parsers shared with the app over FFI. Pure, no IO. `capabilities::capabilities(system)` says per `ServerStatus` field whether a platform collects it; check it before calling an empty field a bug.
- `../crates/sbm_native/`: monitor-only native sampler (`sample(state, system)`): cpu/mem/swap/disks/diskio/net/uptime/host/sys via `sysinfo` or procfs, feeding `sbm_parser::linux::parse_*` unchanged. NVIDIA (`nvidia-smi`) and Linux AMD/Intel (shared DRM command) run every cycle; sensors, batteries, SMART and legacy Windows AMD on the extended cycle via the script. `monitoring.rs::collect_metrics` merges them.
- `src/`: `cli/` (`serve`, `config`, `cleanup`), `core/` (config, `remote_access.rs`, `fs_roots.rs`, `config_file.rs`), `api/` (handlers, `authz.rs`, `ratelimit.rs`, `ws/`), `ssh/` (`client.rs` russh, `known_hosts.rs` TOFU pin of the local sshd, `local_pty.rs` the SSH-less PTY), `monitoring/` (sampling, `rules.rs`, `push.rs`, `custom_cmds`), `db/` (migrations, retention cleanup).
- `frontend/src/`: Svelte 5 runes, Tailwind 4 (class-driven dark), no router (`layout.svelte.ts`). `pages/`, `components/`, `lib/` (API client, rune stores, `terminal.svelte.ts`), `types/`, `i18n/` (15 locales). Tests: vitest + testing-library; svelte-check is the type gate.

### Cross-platform semantics left as is (changing them would change stored history)

- `cpu`: Linux cumulative ticks; BSD an instantaneous percentage in the tick fields; Windows a percentage accumulated into a synthetic counter. `monitoring::adapt_cpu` branches on `SystemType`; any new consumer must too. The native sampler has consistent semantics; the script path keeps the split.
- `sys`: a real distro parser on Linux (`PRETTY_NAME`); BSD/Windows reuse `parse_hostname` on `uname -or`/`OsName`. `os_id`/`os_id_like` are Linux-only (`/etc/os-release`).
- `uptime`: Linux/BSD normalised by `parse_uptime`; Windows passes PowerShell's string through.
- `diskio` is cumulative 512-byte counters on both paths.

## Panel

- **The panel is a desk** (a macOS-style web desktop, every feature an app in a window): `frontend/src/desk/CLAUDE.md`.
- **State and UI only.** The panel never composes a shell command or parses output: it calls an agent endpoint, which builds and parses through `sbm_parser` (the app reaches the same functions over FFI). Sending text to `/exec` and parsing it in TypeScript is ruled out.
- The terminal store (`lib/terminal.svelte.ts`) owns protocol and reconnect and knows nothing about xterm.js; xterm is a dynamic import (`lib/xterm.ts`). Dialog terminals (`TargetTerminal`) use `persist: false` and `close()` on destroy, never the page's stored handle. An explicit open forgets the stored handle; only Resume rejoins it.
- An answer that arrives after the sidebar switched servers is dropped (`stale(serverId)` pattern); anything that writes binds to the server it was opened on.
- Multi-server: a server list (URL + session) in localStorage. Served by an agent (same origin) or hosted statically talking to several agents.
  - **A panel an agent serves holds only that server** (`ServersStore.servedByAgent`): decided at startup by `confirmSameOrigin()`'s probe (assumed until it answers; `unreachable` counts as the agent's own). `add()` is refused and both add affordances are absent there.
  - The vite dev server proxies to an agent, so the probe would answer "own"; `import.meta.env.DEV` exempts it (no shipped build has it).

### Cloudflare Pages

- Root directory `monitor/frontend`, build `npm run build`, output `dist`. `@serverbox/webui` is a `file:` dependency whose own devDependencies are never installed, so `prebuild` runs `npm ci --prefix ../../packages/webui`; keep build steps in `package.json`, not in a dashboard. Repo-root variant: `cd monitor/frontend && npm ci && npm run build`, output `monitor/frontend/dist`.
- `frontend/.node-version` pins Node 24 (Pages reads it from the root directory); the Dockerfile (`node:24-alpine`) and `monitor-release.yml` match. vite 8 needs `^20.19.0 || >=22.12.0`.
- Each agent must allow the origin (`cors_allowed_origins` / `SBM_CORS_ORIGINS`) and be reachable over HTTPS (built-in TLS or a proxy/tunnel). Without `frontend/dist` the API runs alone.

## Permissions (`docs/dev/monitor-permissions.md` is the contract)

- Every account has one role (`users.role`); a role is a set of grants: `shell`, `ssh_terminal`, `files` (read/write), `connect` (`allow` list), `listen` (`public`, `ports`), `virt`. `admin` roles also manage accounts, roles and configuration. `config.toml` keeps only the machine side: `ssh_addr`, `fs.roots`, limits, and one `allow_insecure` (TLS or a loopback peer otherwise; legacy `terminal.allow_insecure` / `fs.allow_insecure` still count for their old grants).
- `api/authz.rs` is the one place a request becomes a `Caller` (JWT → account → role); `Caller::check(grant, state, secure)` is the one question. A JWT for a deleted account is 401. Grants are re-checked at the moment of use, never trusted from the UI.
- Password change: `users.password_changed_ms` moves, older panel tokens are refused, watch tokens deleted, `authz::end_account` closes sessions, tickets, relays and listeners.
- `api/admin.rs` (`/me`, `/me/password`, `/users*`, `/roles*`): admin-only except `/me`; every change re-asks the admin's password through the login throttle; the last admin cannot be deleted or demoted (`accounts::Guarded`, in the statement itself); built-in roles keep their name and `admin` flag. Losing a grant ends what ran under it (`authz::revoke_lost`, `AppState.grants_changed` → `permission_revoked`).
- Roles are in the DB (migration 010; 011 adds `virt` to roles with `shell`). `PUT /roles/{name}` keeps grants the body omits; clients send `virt` only to agents that list it (older `Grants` refuse unknown fields).
- `db::bootstrap::ensure_roles` decides the built-ins once: a fresh install from `--init-permissions full|read` / `SBM_INIT_PERMISSIONS`; an upgrade from what the legacy keys (`full_access`, `listen_public`, `terminal.enabled`, `fs.enabled`) effectively granted (`Grants::from_legacy`, TODO remove). **Trap:** any legacy key in a fresh config (e.g. `[remote_access.fs] enabled = true`) makes it an upgrade and ignores `SBM_INIT_PERMISSIONS`; give a test agent `roots` only.
- `tests/permissions_api.rs` holds the route × role matrix; tests seed accounts via `tests/common`. `tests/watch_token_scope.rs` lists routes with requests harmless under the panel login (`/power` excluded).

## Endpoints

### `POST /api/v1/exec`

One command → `{exit_code, stdout, stderr, truncated, timed_out}`; in: `{cmd, stdin?, env?}` (`stdin` carries a sudo password, `env` avoids quoting). Not a terminal frame: a PTY is shared with the user's typing (`terminal.rs` rejects an `exec` frame, tested). **Timeout, output cap and request-body limit are `[remote_access.exec]`**: the operator's trade, never raised per request or per action; the body limit is passed to `configure_api` because ntex applies it before handlers. Work that must outlive it starts detached and is polled. `tests/exec_api.rs`.

### Machine endpoints (`api/machine.rs`, issue #1623)

Shared rules:
- The command is built in Rust (`sbm_parser`, the app's text where one exists) and run through `api::exec::run`, so `[remote_access.exec]` bounds it.
- `machine::gate` is the one place a grant is asked (`shell` unless stated) and a refusal recorded. Audit rows are `Kind::Machine`, subject the account, detail the feature and verb, never a password, value or output.
- Script text runs via `machine::as_self` (`sh`, text on stdin) or `machine::as_root` (`sudo -S -p '' sh -c "$SBM_ROOT_SCRIPT"` with only the password on stdin, or `sudo -n`): the script never shares the password's stream. A rejected password is `sudo_rejected` (`sbm_parser::script::sudo_password_rejected`), not a status. A script carrying a secret uses `machine::as_root_private` (0600 file, only its path on the command line).
- Outputs reach parsers as `CommandOutput` via `machine::command_output` (timeout and cap are failures with a reason).
- `machine::FEATURES` is `features` in `/capabilities`; a panel offers a page or a terminal target only when listed (older agents 404 or ignore unknown fields).
- Tests never perform the real action on the machine running them (`power`, `cron` save, firewall changes, user changes, benchmark runs).

Per endpoint:
- `/power`: the status script's `SbShutdown`/`SbReboot`/`SbSuspend` via `monitoring::local_script_command`. `tests/power_api.rs` checks refusals and records only.
- `/process` (`sbm_parser::proc`, `PsView`): the script's `SbProcess` with ≥ 8 MiB output, kept in `AppState.process_sample` (reused within 2 s, baseline 30 s); a stop checks the PID's start identity, retries as root on `denied`.
- `/services` (`sbm_parser::service`): systemd, procd, OpenRC; an action names a unit by its listing key, resolved against a listing read for that request, which also decides whether root is needed.
- `/cron` (`sbm_parser::cron`): the agent account's crontab; an edit is one operation on one line by listing index, applied to the file re-read at write time via `crontab -`; a stale index is `unknownLine`. Audit has the schedule, never the command.
- `/containers` (`sbm_parser::container`): Docker then Podman (a `docker` that is Podman is read as Podman); each part (containers, images, usage, logs) is one batch split by a fresh separator; an action answers with the refreshed listing (images for image actions). `ContainerAction` covers lifecycle, `remove_image`, `pull_image`, `prune_images`, `prune_system`, `run` (`run`'s args split by `parse_run_args`). Values are validated and used trimmed; a bad one is `400 {"error":"invalid_input","issue":<code>}` before the runtime is probed. `unused_tagged` is computed by the agent. No runtime access is `permission_denied`. A shell inside a container is the terminal `target` (`container_exec`). TODO: `DOCKER_HOST`, sudo path.
- `/tmux` (`api/tmux.rs`, `sbm_parser::tmux`): sessions (`created`/`last_attached`/`activity` are epoch seconds or null; tmux ≥ 3.6 dropped the `*_string` variables), `available: false` when not installed (found by the agent's `FIND_COMMAND`, never named by the client), "no server running" is an empty list, a failed listing carries `error`. Attaching is the terminal `target` (`tmux`). Limitation: a tmux server first started from the panel lives in the agent's cgroup, so with systemd's default `KillMode=control-group` an agent restart ends it.
- `/benchmark` (`sbm_parser::bench`): the agent owns the run: the `benchmark_run` row (migration 012) is written before the detached launcher starts and `start_poller` (from `cli::serve`) finishes it with or without a page. One run at a time is a partial unique index. Script `assets/yabs.b64` embedded (`tests/benchmark_asset.rs`). Linux only.
- `/system-users` (`sbm_parser::users`): the machine's accounts (`/users` is the agent's). Linux only; a write is resolved against a fresh listing; root and the agent's own account are refused; a password write uses `as_root_private`.
- `/firewall` (`sbm_parser::firewall`): ufw or firewalld, Linux only. `POST /firewall` reads (sudo password in the body) and reports what reaches each way in (the panel's connection unless `proxied`, and SSH). A change is one `UfwChange`/`FirewalldChange`: `/firewall/plan` returns the `Plan` and runs nothing; `/firewall/act` re-reads, re-plans and runs that (keep-open rules first when asked). A plan carries `plan_id` (a digest); a plan that asks runs only under the confirmed id, otherwise `confirm_required` with the new plan. The app uses the same `ufw_plan`/`firewalld_plan`.
- `/snippets` (`sbm_parser::snippet`, migration 013): PUT replaces the library (refused per row `{error, index}`); `POST /snippets/plan` expands a script into steps and runs nothing; the panel sends an empty context, so `${host}`-style keys are `{error:"unanswerable", key}`. `shell`; audit names snippets only.
- `/desktops` (migration 014, `connect`): routes validated by `sbm_parser::desktop`; no password stored (asked per session, given to noVNC only). VNC over `/stream/ws` (`RelayChannel` in `lib/desktop.svelte.ts`). RDP over `/rdp/ws` (`api/ws/rdcleanpath.rs`): the agent is the RDCleanPath proxy (ticket in `proxy_auth`, purpose `rdp`; `connect` + `allow` checked on resolved addresses; server certificate captured, not verified). **The RDP session, NLA credential included, is plaintext in the agent**; the panel says so. `tests/rdp_ws.rs`.
- `/bmc` (`sbm_redfish`, migration 016): targets so an agent reaches neighbours' BMCs. See and power: `virt`; edit targets and `POST /bmc/probe`: admin. Password write-only (`has_password`; `null` keeps, by id). **No pinned certificate, no dial** (`require_pin`); one login per request; upstream failure is `502 {error:"bmc", failure}`, never 401. `GET /bmc/{id}` returns `intents` (`ResetRequest::build`). `tests/bmc_api.rs` (fake Redfish).
- `/virt` (`sbm_virt`, `api/virt*.rs`): guests on PVE or libvirt in `sbm_virt::model` terms. `virt` to see and act, admin to configure and pin. Loads are POSTs (a libvirt sudo password goes in the body, never stored). PVE: one stored config (migration 017; `password`, `token_secret` write-only) and **one `sbm_virt::pve::Client` in `AppState.virt`** (tickets live 2 h; `POST /virt/pve/tfa` answers a waiting login); an unvouched certificate is `cert_unconfirmed` until `POST /virt/pve/cert` pins it. A host failure is 200 with `error`. Consoles are resolved before the socket opens: `POST /virt/console` mints a `Purpose::Virt` ticket (30 s, refused by `/ws-ticket`) and `/virt/console/ws` relays in `/stream/ws` framing; PVE tickets never reach the browser; a libvirt serial console answers the `virsh console` command for the panel terminal. Snapshots, storage/networks (`virt_resources.rs`; PVE asks the node which interfaces are live via `LIVE_NET_SCRIPT` so the operator's link is never edited), guests (`virt_guests.rs`), hardware and cloud-init (`virt_hardware.rs`, `revision` per read, stale = `conflict`), backups (`virt_backups.rs`, PVE only): each refused as its `Detail::*Refused`. `tests/virt_api.rs` (fake PVE over TLS).
- `/backup` (migration 015, admin both ways): opaque blobs for the app's `MonitorBackupStorage` and the panel; the app encrypts first. `MAX_BYTES`, `MAX_BLOBS`; names `[A-Za-z0-9._-]`, no leading dot.

### `GET/PUT /api/v1/custom-cmds`

Files in `~/.config/server_box/custom_cmds` (`sbm_parser::script`), the same set the app writes over SSH and the status script runs. PUT replaces the whole ordered set (order is the file prefixes). **Writing needs admin and `shell`** (a file there runs on every extended cycle); reading is any account, with `editable`. Store: `monitoring::custom_cmds` (write-aside-and-rename, names never logged). Outputs ride in `/metrics` (`custom_cmds`, trailing newline kept); the dashboard card shows each command's first line, dropping one trailing line ending for display only.

### `/api/v1/fs/*` (`files` grant, `mode` read or write; `fs::writes` decides)

- **`[remote_access.fs] roots` is the boundary; no default.** Every path is canonicalised (symlinks followed, `..` refused) and then checked component-wise (`core/fs_roots.rs`), so a link out of a root is a refusal. Every refusal is the same 403, and a path outside is reported as absent. `roots = ["/"]` equals a shell and is warned about.
- `GET /fs/roots` returns the roots (403 without the grant or with none, `not_configured`).
- **The agent's own state is outside every root** (`fs_roots::Protected`, filled in `api::server::agent_state`): DB and journals, `jwt.secret`, first-start credentials, `config.toml` and backups, `.env` files, the TLS key, the custom-commands dir. Per file; hidden from listings; their directories cannot be renamed, removed or chmod-ed. `tests/fs_protected.rs`.
- Writes stream to `<path>.sbm-part-<pid>-<n>` (hidden from listings) and rename, keeping the target's mode; a mode that cannot be carried over fails the write, and the staged copy is removed on every other way out, a dropped request included (`Staged`). `PUT /fs/write?if_version=<version>` (the editor) answers `409 {"error":"modified"}` when the file's `version` (signed nanosecond mtime + size, from `EntryView.version`; a listed link has none, since a write compares the file it resolves to, which `/fs/stat` describes) differs or the file is gone; uploads send none. The check runs after the upload under one lock (`REPLACE`) held through the rename and by `remove`/`rename`, so the agent's own writers cannot interleave; another process can still write in that window (POSIX has no rename-if-unchanged). `modified` stays seconds for the app.
- Known limitation: resolve-then-use is two steps (a symlink swapped between them is followed); closing it needs per-component `openat`+`O_NOFOLLOW`, not portable. `tests/fs_roots.rs`, `tests/fs_write.rs`.

### `/api/v1/desk*` (`api/desk.rs`, any signed-in account)

- The panel's desk: preferences (accent, wallpaper `preset:<id>`|`custom`, fit, `background` (migration 019; absent in a body = on) and `background_denied` (020), dock, icons as child tables), one custom wallpaper (PNG/JPEG/WebP sniffed from the bytes, ≤8 MiB, ETag = SHA-256), the window session per account + device, notifications. All keyed by `users.id`, `ON DELETE CASCADE` (migration 018).
- **Session writes are compare-and-swap on `revision`**: the transaction's first statement is the `UPDATE … WHERE revision = expected` (or `INSERT OR IGNORE` from 0), so SQLite's write lock is taken there; a loser gets 409 `{error: conflict, current}`. Never read-then-write. `app_state` is opaque JSON ≤16 KiB.
- `/desk/events`: `text/event-stream` over `fetch` + bearer (not `EventSource`), `data:` JSON lines, `: ping` every 25 s, `{type: resync}` on lag. A hint to refetch, never the only copy. Session/preferences events go only to their own account; it ends when the account's password changes or it is deleted.
- Notifications: `DeskHub::rules_checked` gets the firing rules each cycle and stores one per rule that *starts* firing; the newest 500 are kept; read state per account.
- Feature flag `desk` in `machine::FEATURES`; a panel without it keeps the desk in the browser.
- `/desk/apps/{app}/storage` (`api/desk_storage.rs`, migration 021, feature `desk_storage`): each desk app's JSON by key, per account; 256 KiB per app summed and written in one transaction. The panel names the app, so it separates nothing between apps of one account.
- `/apps*` (`api/apps.rs`, migration 022, feature `desk_apps`): third-party desk app packages (`docs/dev/desk-sys.md`). An admin uploads a `.sbapp` (gzipped tar: `manifest.json`, `ui/**`, notices), checked whole (regular files only, plain relative paths, 2000 files, 20 MiB compressed and inflated, counted while reading) and stored in the DB, waiting; approving asks the password and exactly the manifest's permissions; a new version asking for more waits again. The UI is served under an HMAC launch ticket (`/apps/{id}/ui/{ticket}/…`, 12 h, key derived from the JWT secret) with `CSP: sandbox allow-scripts …; connect-src 'none'`, so it runs in an opaque origin even when opened directly. A `wasm` package adds `backend.wasm`: `POST /apps/{id}/call` runs it in wasmi (`api/app_runtime.rs`; fuel + 10 s, 64 MiB, a fresh instance per call on its own 16 MiB-stack thread) as the calling account; its host functions check the app's approved permission and the caller's grant at the moment of use (`tests/apps_api.rs` has WAT guests).
- `desk_background` / `desk_storage` tell a panel it may send `background*` and use app storage (an older agent refuses unknown preference fields).

### `/api/v1/terminal/ws`

- The agent is an SSH **client** to the local sshd: a session has the SSH account's privileges; the panel password grants none. Binary frames are PTY bytes, text frames control JSON (`api/ws/terminal.rs`).
- `auth: {"kind":"local"}` is the SSH-less path (a shell as the agent's user, needs `shell`). An optional `target` narrows it, built in Rust and run via `LocalShell::spawn_command` (`/bin/sh -c`, `cmd.exe /C` on Windows): `container` (`shell_command`), `iperf` (`sbm_parser::iperf`), `tmux` / `tmux_new` (tmux's plain client; xterm.js cannot decode control mode). Refused: a target with an SSH credential, unknown fields (`deny_unknown_fields`), invalid values (`invalid_input` + `issue`), no runtime / no tmux (`no_container_runtime`, `no_tmux`). No frame carries a command. Panels send a target only where `features` lists `container_exec`, `iperf` or `tmux`.
- ConPTY sends `ESC[6n` and holds output until answered; Windows PTY tests use `answer_cursor_position_query`.

### `/api/v1/stream/ws` and `/api/v1/listen/ws`

- `stream`: a raw TCP connection under `connect` (networking without a shell). `connect.allow` is checked against every **resolved address**, and those addresses are dialled. Text frames: `{"type":"open","host","port"}` or `{"type":"accept","id"}`, then `ready`/`error`/`exit`; binary frames are bytes. One socket is one connection, no session store, no replay. The address stays out of the URL (access logs). `tests/stream_ws.rs`.
- `listen` (`listen` grant): the agent binds (`listen` → `ready`), announces `incoming` with an id; the app claims it with a stream `accept`. Pending connections (`AppState.pending`) are claimable only by the listening account, expire after `PENDING_TTL`. Loopback only unless `public`; only `ports` when named. `tests/listen_ws.rs`.

### WebSocket traps (locked by tests)

- **Upgrades go through `api/ws/upgrade.rs`, not `ntex::web::ws::start`**: ntex caps incoming frames at 64 KiB with no setting; the copy takes 4 MiB (`MAX_FRAME`) with its own `WsSink`. TODO: back to ntex when configurable.
- **Upgrade auth is a single-use ticket** (`api/ws/ticket.rs`): purpose-bound, ~30 s, burned even on a wrong secret (no headers on a browser handshake; no token in URLs).
- **`is_secure_transport` treats loopback as secure** (same-host proxy / `cloudflared`); it never reads `X-Forwarded-Proto`.
- **Terminal sessions outlive the socket** (`api/ws/session.rs`): the handle is a 256-bit bearer capability bound to the panel account, constant-time compared, memory-only; an `attach` takes over; detached sessions end after `detached_timeout_secs` (300). Capacity (`max_sessions`) is derived from memory.
- **Replay is incremental**: the client reports bytes rendered; `ready.since` is the absolute position the following stream starts at, and `ready` precedes output.
- **`shell` deliberately bypasses sshd** (no SSH auth, logging or 2FA), so `install.sh` runs the agent as an ordinary account (`systemctl --user`, or OpenRC `command_user`). `DELETE /api/v1/remote-access/full-access` (admin) takes `shell`, `connect`, `listen` from every role (`full_access_disabled`). `connect`/`listen` without `shell` is the meaningful restriction.
- `tests/fake_sshd/` is an in-process SSH server for `tests/terminal_ws.rs`; `a_real_sshd_produces_a_working_shell` runs only with `SBM_E2E_TERMINAL_*`.

## Configuration

- `.env` (DB URL, JWT secret, host/port, TLS) and `config.toml` (`config.json` is migrated once by `Config::legacy`; `normalize()` drops the Go keys).
- Sections are grouped by **what they act on** (`[remote_access.terminal]`, `[remote_access.fs]`, `[remote_access.exec]`, `[monitoring.extended.idle_pause]`); a key's level is a claim about its scope, and the resolved structs (`RemoteAccess` with `Terminal`/`Fs`/`Exec`) mirror it. Shared keys stay at the section level (`ssh_addr`, `allow_insecure`).
- The flat pre-Aug-2026 layout is not read (serde ignores it, so old switches revert to off — a deliberate hard cut).
- Capacities (sessions, output caps, body limits) derive from physical memory unless set; resolved values are logged at startup.
- `core/config_file.rs` writes `config.toml` atomically with bounded backups; callers hold `AppState.config_write` across read-modify-write.

### Editing it over the API (admin, `require_admin!`)

Reads go to the file on disk, not `AppState.config` (a startup snapshot). **A PUT replaces all it names**; GETs and `POST /push/test` write nothing.
- `GET/PUT /settings`: intervals, idle pause, rules, retention, CORS (no `jwt_secret`, `database_url`, `remote_access`). GET adds `live_fields` and `data_retention_defaults` (absent retention means no cleanup at all).
- `GET/PUT /push`, `POST /push/test` (`api/push.rs`): channels and `push_rate`. **Credentials are write-only**: GET answers `null` at credential keys (`sc_key`, Bark `key`, iOS `token`, every header value); a PUT `null` keeps the stored value, matched by `from_index`; `null` elsewhere is refused. A webhook `url` is not a credential. An unknown `push_type` is withheld and unsavable. Channels and rules apply on restart (`applies_on_restart`; TODO live, like `LiveSettings`). `tests/push_api.rs` checks the response bytes.

## Database

Migrations in `migrations/`: metrics history, `users` (with `role`), `roles` (010), `watch_tokens` (`scope` = `read`), config storage, `access_log` (audit: `kind, action, result, detail`; never a credential; retained via `DataCleanupService::POLICY_TABLES`), `ssh_known_hosts` (the pinned local sshd key), and the feature tables named above.

## Release

- Shipped with `--profile release-monitor` (`release` + `lto = "fat"` + `codegen-units = 1`, profile-wide, so not on the shared `release`).
  - **`monitor/Dockerfile` builds outside the workspace** (it rewrites the `sbm_parser` path), so it sees no workspace profile and passes the settings as `CARGO_PROFILE_RELEASE_*`; anything added to a workspace profile must be repeated there.
  - `nix/package.nix` builds inside the workspace (`release` + `strip`, not `release-monitor`).
  - `opt-level` stays 3 (`"s"` is 15.2 → 11.2 MB; not worth it for a process terminating TLS).
- **One crypto implementation, `ring`**: `cargo tree -i aws-lc-sys` must be empty. reqwest uses `rustls-no-provider`; `monitoring::push::http_client` installs ring first (otherwise reqwest panics), held by the webhook tests in `monitoring::push`. Sizes (macOS arm64, stripped): 22.0 → 20.1 (no aws-lc) → 15.2 MB (profile).
- Docker: `docker build -t server-box-monitor . && docker run -p 3770:3770 -v $(pwd)/data:/app/data server-box-monitor`.
- `install.sh install` (systemd user service; `sudo` for OpenRC, still running as the invoking account; `--system` for root; `--permissions read`; `SBM_INSTALL_PKG=<path>` for an unreleased build).
- Env: `SBM_HOST`, `SBM_PORT`, `SBM_TLS_CERT`, `SBM_TLS_KEY`, `SBM_CORS_ORIGINS`, `SBM_INIT_PERMISSIONS`, `DATABASE_URL`, `JWT_SECRET`, `RUST_LOG`.
