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
- **`sys`**: Linux uses a real distro-description parser (`common::parse_sys_version`, extracts `PRETTY_NAME`); Bsd/Windows repurpose the generic hostname-trimming helper (`common::parse_hostname`) against `uname -or`/`OsName` output — happens to work because those are single clean lines, but isn't a "system version" parser on those platforms. The `os_id`/`os_id_like` fields beside it come out of the same command and are Linux-only for the same reason: they are `/etc/os-release`'s `ID=`/`ID_LIKE=`, which Bsd/Windows have no equivalent of. `capabilities::Capabilities` has no entry for them — they share `sys`'s by construction.
- **`uptime`**: Linux/Bsd normalize the `uptime` command's varied output via `common::parse_uptime`; Windows pre-formats the duration string in PowerShell itself and the field just passes it through — presentation shape isn't guaranteed identical across platforms.

The shell-script collection path has been replaced with native per-platform sampling for the fields it can cover (`crates/sbm_native` — see below); this resolved the `cpu` mismatch for monitor itself because `sysinfo`'s CPU percentage has consistent semantics across platforms. The shared script path still carries the documented CPU distinction, while `diskio` now uses genuinely cumulative 512-byte counters on both the native and script paths. `sys`/`uptime` still differ in string shape between native and script sources (unchanged — see their doc comments).

### Native Sampler (`../crates/sbm_native/`, monorepo root)

Monitor-only crate (the app never depends on it — it always collects over SSH and has no way to run native syscalls on a remote host). `sample(state, system) -> sbm_parser::ServerStatus` covers cpu/cpu_brand/mem/swap/disks/diskio/net/uptime/host/sys directly via syscalls (`sysinfo`, on Bsd/Windows) or direct procfs/sysfs reads feeding `sbm_parser::linux::parse_*` unmodified (on Linux, zero extra dependencies). Per-platform backends are `#[cfg(target_os)]` submodules within this one crate, not separate crates — multi-platform support is this crate's internal concern. GPU collection stays outside this crate: NVIDIA gets a dedicated `nvidia-smi` subprocess every cycle, while Linux AMD/Intel use the shared targeted DRM command every cycle (`monitoring.rs::sample_linux_gpus`). Sensors, batteries, SMART and legacy Windows AMD refresh on the slower extended cycle via the shared script. See `monitoring.rs::collect_metrics` for how the sources merge into one `ServerStatus`.

### Backend (Rust - `src/`)

- **`main.rs`**: Application entry point, coordinates monitoring loop and web server
- **`cli/`**: clap-based CLI (`serve`, `config`, `cleanup` subcommands)
- **`core/`**: Configuration loading (`config.rs`) with .env support and TOML/legacy JSON config files
- **`api/`**: ntex-based web server (`server.rs`), JWT auth (`auth.rs`), login throttling (`ratelimit.rs`), and the WebSocket endpoints under `api/ws/` (see below)
- **`ssh/`**: shells for the browser terminal — `client.rs` (russh: connect/authenticate/PTY), `known_hosts.rs` (trust-on-first-use pinning of the local sshd), and `local_pty.rs` (the SSH-less path, a local PTY interface-compatible with the SSH one so both drive the same session machinery)
- **`monitoring/`**: Metrics collection (`monitoring.rs`: `sbm_native::sample()` covers cpu/mem/swap/disk/diskio/net/uptime/host/sys every cycle via direct syscalls/procfs reads — see `../crates/sbm_native`; `nvidia-smi` and the shared Linux AMD/Intel DRM command run as targeted subprocesses every cycle; the generated script's extended cycle remains for sensors/SMART/battery and legacy Windows AMD), rule evaluation (`rules.rs`), push notifications with rate limiting (`push.rs`), velocity/timeseries analysis
- **`db/`**: SQLite initialization/migrations (`database.rs`) and data retention cleanup (`cleanup.rs`)
- **`utils/`**: Centralized error types (`error.rs`)

### Frontend (Svelte - `frontend/src/`)

- **Svelte 5 (runes)** with TypeScript and Tailwind 4 (class-driven dark mode)
- **`pages/`**: Login.svelte, Dashboard.svelte (App.svelte gates them by auth state; no router)
- **`components/`**: Spinner, StatCard, ThemeToggle
- **`pages/Terminal.svelte`** + **`lib/terminal.svelte.ts`**: the in-browser terminal. The store owns the protocol and reconnect policy and knows nothing about xterm.js, which keeps the part worth testing free of a DOM; xterm is loaded by dynamic `import()` so it stays out of the main bundle
- **`lib/`**: fetch-based API client, module-level rune stores (auth/theme), Poller
- **A tabbed feature is `pages/<Feature>.svelte`, and its tabs come from one list**: `lib/features.ts`'s `FEATURES` names each feature's own `remote_access` field, `enabledFeatures` keeps the ones this agent answers `=== true` for, and `components/FeatureTabs.svelte` draws them. So a page added below the last one joins the bar without touching the pages written before it. What a request was refused for arrives as a stable code and is phrased in the viewer's language by `lib/<feature>Refusal.ts` — a sentence the agent wrote is English in fifteen locales.
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
  quoting. Output is capped per stream and the command is killed on a timeout,
  both reported rather than silently applied. **Both bounds, plus the request
  body limit, are `[remote_access.exec]`** — they were constants sized for
  process/unit/container listings, which is not a size anything taking minutes
  fits inside. They are the agent's decision and a request cannot raise them;
  the payload limit arrives as an argument to `configure_api` because ntex
  applies it while extracting the body, before any handler sees state.
  A caller that must outlive any configured timeout should start the work
  detached and poll it in short requests instead of asking for a longer one.
  `tests/exec_api.rs`.
- **`POST /api/v1/power`** — shut down, reboot or suspend the machine the agent
  runs on. Gated on `full_access`, like the shell and `/exec`: anyone who can
  open a shell can run `shutdown` in it, so a switch of its own would withhold
  nothing. The command text is the shared status script's
  (`sbm_parser::script::ShellFunc::{Shutdown,Reboot,Suspend}`), run locally by
  `monitoring::run_local_shell_func` — so what the panel asks for is what the
  app runs over SSH, and a change to either reaches both. A `sudo -S` password
  travels in the body, never in a command line, and a refusal comes back as a
  field (`sudo_rejected`) rather than as a failed request, since the caller's
  next move is to ask for a different one. `tests/power_api.rs` covers the
  refusals and the audit row; the execution path is not exercised there, because
  the only thing it can do is power off the test machine.
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
- **`GET/PUT /api/v1/cron`** — the scheduled tasks of the account the agent
  runs as: `crontab` itself, not `/etc/cron.d`, not `-u` for another account,
  not systemd timers. Reading needs only the panel login and answers `editable`
  so the page can go read-only instead of failing on save; **writing is gated on
  `full_access`**, the same grant as the shell — the schedule is arranging for
  code to run on a timer as the agent's user. The model is
  `sbm_parser::cron` rather than a command sent through `/exec`: which line a job
  is, what a disabled job looks like on disk and what may not be written at all
  is a model, and the app reads the same crontab over SSH and would otherwise
  reimplement it. A PUT is an operation on **one line**, addressed by its index
  in the listing the client was given — a client that round-tripped the whole
  document would be the thing that decides how a disabled line is spelled, and
  the file is re-read at the moment of the write, so only the index can be
  stale. An index that is out of range, or that has come to hold a comment, is
  refused as `unknownLine`; a schedule or command that would damage the file is
  refused before the machine is touched at all. Nothing was ever installed to
  read: a machine with no `crontab(1)`, or Windows, answers 200 with
  `available: false` and a `reason_kind`, and a crontab that does not exist yet
  is an empty document rather than an error. The expansion a client draws
  (minutes/hours/day fields, the next run) is done here, against the machine's
  own clock from the listing script's `date +'%s %z'`. `tests/cron_api.rs`
  covers the refusals and the audit row and deliberately performs no successful
  save — the suite runs against the crontab of whoever runs it.
- **`GET/POST /api/v1/process`** — the machine's process table, and the signal
  that stops one process. The table is
  `sbm_parser::script::ShellFunc::Process` run locally — the same text the app
  uploads and calls with `-p` over SSH — and the stop is
  `sbm_parser::proc::kill_command`, so neither the panel nor the app composes a
  command or parses `ps`. Reading needs only the panel login; **signalling is
  `full_access`**, the same grant as the shell, and the response says
  `editable` so the page can go read-only instead of failing on a click. The
  table is parsed once per request and **the reading is kept on the agent**,
  because a read/write speed is a difference against the previous reading: a
  request inside a two-second window is answered with the stored reading
  reordered rather than with a second `ps` a few milliseconds later, and a
  reading older than thirty seconds is dropped rather than divided by. The
  response reports the columns the machine filled, the orders that leaves
  available and which one it answered in, so the page draws no rule of its own;
  a PID is checked against the start identity the listing gave it before any
  signal is sent, and a stop that this account may not make is retried through
  `sudo` with a password from the body, never from a command line.
  `tests/process_api.rs` asserts the table against the process that asked, the
  refusals, and one signal to a PID no process holds; the one successful stop it
  makes is of a process it started itself, and only where the platform has a
  stop at all (BSD has none).
- **`GET/POST /api/v1/containers`** — the containers on the machine, with
  `part=containers|images|usage|logs`. The model is
  `sbm_parser::container` — which fields to ask for, how Podman's dialect is
  told from Docker's, how a container's state is read out of either one's
  wording and what a prune may remove — ported from the app's Dart fixture
  suite, so the panel never composes a command line. A `POST` is a
  `ContainerAction` as a tagged object, and an action this build does not
  implement is refused while deserializing rather than reaching a shell.
  Reading needs only the panel login and changing one is `full_access`; the
  response says `editable` so the page goes read-only instead of failing on a
  click. The runtime is detected (`docker` first, then `podman`, honouring the
  client that prints `Emulate Docker CLI using podman` and otherwise answers
  every Docker command), and **there is no way to name the runtime or the
  socket** — a remote `DOCKER_HOST` is a real case the app supports and this
  endpoint does not yet (TODO: an agent-side setting). Logs are a bounded
  `logs` part rather than the panel composing `/exec`.
  `tests/containers_api.rs`.
- **`GET/POST /api/v1/services`** — the systemd/procd/OpenRC units of the
  machine, with `part=list|logs|definition|status`. Three manager backends in
  `sbm_parser::service`, whose Dart counterpart's fixture suite is
  `tests/service_compat.rs` (fed the real output under `test/fixtures/systemd/`).
  **A unit's key is the agent's** (`"{scope}:{full_name}"`), not the panel's:
  with a second way of spelling one, a listing and a request about a unit can
  disagree and the unit reads as missing. Reading needs only the panel login and
  acting on one is `full_access`. **Logs are read as the agent's own account and
  never through `sudo`** — what the journal shows root is a different question
  from the one the page asks. Timestamps are asked for with `TZ=UTC` and the
  offset read out of the value, so the panel draws one instant in the reader's
  zone without shifting the machine's. `monitor/src/api/privileged.rs` (`as_self`
  / `as_root`) was extracted here and `process` moved onto it.
  `tests/service_api.rs` mounts the real `configure_api`; where the machine's
  detector answers launchd the listing cases are skipped rather than asserted
  into a refusal.
- **`GET/POST /api/v1/users`** — the machine's accounts: the catalog and one
  account's own records, with `part=list|detail` (`detail` needs `name` and is
  answered 400 without it), and the writes `create|edit|delete`. The model is
  `sbm_parser::users` — the `/etc/passwd` and `/etc/group` catalog, the
  account's `/etc/shadow`, `authorized_keys` and sudoers, and the `useradd` /
  `usermod` / `userdel` command texts — ported from the app's Dart fixture suite,
  so the app over SSH and the agent in a local shell read one machine the same
  way. **Linux only**: another platform answers 200 with `available: false` and
  `reason_kind: unsupported_platform`, because macOS has `dscl` behind a
  directory service and Windows has neither the files nor the commands, so a
  port is a different implementation rather than a different parser. Reading
  needs only the panel login and writing is `full_access`.
  - **A refusal the caller could have avoided is made before the machine is
    touched**, and answered 400 with a stable code rather than a sentence (404
    for `noSuchUser`, which is a state of the machine and not a mistake in the
    request) — an unreadable machine is 200 with a reason, because the panel
    draws a page either way and stops on a code. The codes are
    `sbm_parser::users::UserError`'s plus this endpoint's own, and the panel
    phrases them in the viewer's language (`lib/userRefusal.ts`).
  - The catalog carries what the panel cannot derive: `agent_account` (the one
    account this endpoint must not remove — it is a process on this machine and
    `userdel -r` would take the home the service reads its config from) and
    `uid_min` from `/etc/login.defs`. Both are `None` when the catalog could not
    be read, so no name is offered for removal on a page the machine did not
    answer for. `remove_home` is asked separately rather than assumed.
  - The account's own password travels inside the generated script down the same
    pipe as the `sudo` password, never on a command line. The `sudo` password is
    `api::privileged`'s field and a refusal to it answers `sudo_rejected` as a
    field rather than a failed request, since the caller's next move is to ask
    for a different one.
  - `tests/user_api.rs`; `crates/sbm_parser/tests/user_compat.rs` is the port's
    own assertion against the cases the Dart suite held.
- **`GET/PUT /api/v1/desktop`** — the remote desktops saved on this agent: a
  name, a protocol, an address the *agent* can reach, and the two options a
  session is opened with. `[desktop]` in `config.toml`, edited through
  `config_file`'s read-modify-write under `AppState.config_write`, like
  `/settings` and `/push`.
  - **The address is why this is stored here and not in the browser.** A
    desktop is usually reachable from the machine the agent runs on and from
    nowhere the panel is, so the agent is the client's way in — which is also
    why the panel's own page has no way to name an address of its own.
  - **No credential is in one.** The password a desktop asks for is typed in
    the browser that runs the session and travels to the desktop through the
    relay, so there is nothing here to withhold — which is the one place this
    differs from `/push`, whose credentials are write-only. The listing is
    therefore readable by any panel login, and `remote_access.desktop` reports
    that this endpoint is *served*; opening a session is `remote_access.stream`
    (the `/api/v1/stream/ws` relay) or `remote_access.rdp`, one per protocol,
    each checked again at the socket.
  - A `PUT` replaces the whole set, because the order is part of what is stored
    and there is no smaller expression for a move. The protocols and their
    default ports come *from the agent* in the response, so a protocol a later
    build adds reaches the panel without a change of its own.
  - **A refusal the caller could have avoided is made before the file is
    written**, and answered 400 with a stable code rather than a sentence:
    `invalidName`/`duplicateName`/`invalidHost`/`invalidPort`/`invalidUsername`/
    `invalidDomain`, phrased by the panel in the viewer's language
    (`frontend/src/lib/desktopRefusal.ts`). A host that is merely down is not a
    refusal — it is worth keeping, and its reachability is answered when a
    session dials it.
  - The audit row names the routes and **never the addresses** (`"office (vnc),
    lab (vnc)"`), because the access log is not a place to keep a map of
    somebody's network. `tests/desktop_api.rs` asserts that, the round trip, the
    nine refusals, and that a route list is editable with `full_access` off
    while the relay stays shut.
  - Two ways to open a session, one per protocol, and the route's own `protocol`
    decides which the panel uses: VNC goes through `/api/v1/stream/ws` (a byte
    relay, which is all VNC needs), RDP through `/api/v1/rdp/ws`. The panel's
    two clients are separate components, because the two agent endpoints are not
    the same shape: `VncViewer` is handed a socket the app has already opened
    and seen accepted, while `RdpViewer` is handed an address — an RDP client
    opens its own socket, since its ticket travels inside the first PDU it
    writes, and a socket the app held open would carry no proof of anything.
    `DesktopChannel` is that pair.
    - `lib/desktop.svelte.ts` mints the ticket for whichever endpoint the route
      needs. The two purposes are separately revocable and each endpoint refuses
      the other's, so the purpose follows the protocol rather than the page.
      **For RDP the ticket is a call (`RdpEndpoint.ticket()`) rather than a
      value, and the viewer makes it when it is ready to dial** — a ticket is
      single-use and good for about thirty seconds (`api/ws/ticket.rs`), and
      between opening the route and the first PDU the client writes there is a
      multi-megabyte wasm bundle to fetch, which on a slow link is longer than
      that. Minted at the route, a session would be refused for a ticket nothing
      ever used. So `connect()` for an RDP route answers without a network call,
      and everything the session can be refused for — the ticket included —
      reaches the page through the viewer's `onend`, in the agent's own words.
      `markConnected()` exists for RDP alone: the endpoint being handed over is
      not the session coming up, and only the client knows when it is.
    - The RDP client is two packages, and the backend module has to be on the
      element **before** it is attached — the compiled component reads that
      property once, as it initializes. `types/ironrdp.d.ts` declares the
      element, which neither package does. Both are loaded by dynamic
      `import()`, so the ~6 MB wasm bundle is fetched by whoever opens an RDP
      route and by nobody else.
    - `IronErrorKind` is declared as an exported enum in the client's `.d.ts`
      and absent from its bundle, so an import type-checks and throws at
      runtime. `lib/rdpFailure.ts` restates the numbering, and
      `tests/rdpFailure.test.ts` reads it back off the installed files — an
      upstream renumbering fails the suite instead of phrasing every failure as
      the one before it. The client's own error chain is appended under the
      localized sentence, since it names what the kind cannot: which security
      the desktop refused.
    - Capability is asked **per route**, not once for the page:
      `remote_access.stream` and `remote_access.rdp` are separate, an agent may
      serve one and not the other, and a route whose protocol has no transport
      is refused beside its own button rather than by a page-wide note. An RDP
      route also needs a user name, which is a property of the route and not of
      the agent.
- **`GET/PUT /api/v1/snippets`** and **`POST /api/v1/snippets/plan`** — the
  snippet library saved on this agent: a script the operator wrote once to run
  again, with `${…}` macros filled in when it runs. It lives here rather than in
  the panel's `localStorage` because it is a record of what to run *on this
  machine* — a library in the browser is lost with the browser profile and
  invisible from a second one. The app keeps its own set over SSH; what the two
  agree on is `sbm_parser::snippet`, which is also what expands a script, so
  `${ctrl+c}` means one thing in both clients.
  - **The library is not the implementation.** `/plan` returns the keystrokes a
    terminal should be *typed* and types none of them: it takes the script's
    text rather than a stored id, so an editor can preview a snippet it has not
    saved, and `context` is what the caller can answer. An omitted key is a
    value the caller does not have, which is not the same as an empty one — a
    script asking for it is refused `unanswerable` with the key beside the code
    rather than run with a hole in it. The panel answers none of them and has
    nothing to answer with: `${host}` and its five siblings come from a *server*,
    and the terminal this feeds is a shell on the machine the agent runs on.
  - **Both the read and the write need only the panel login**, for `desktop`'s
    reason: a snippet is not a grant. It executes nothing, and it becomes usable
    only through a terminal, which is a session with credentials of its own. So
    the response claims no `editable` it would have to keep true. TODO: a
    "run this on a schedule" would change that answer, the way it would for a
    desktop route — a schedule runs with nobody watching.
  - A `PUT` replaces the whole set, because the order is part of what is stored
    and there is no smaller expression for a move. **A refusal the caller could
    have avoided is made before anything is stored**, answered 400 with a stable
    code and the index of the row it is about (`invalidId`, `duplicateId`,
    `invalidName`, `duplicateName`, `invalidTag`, `duplicateTag`), phrased by the
    panel in the viewer's language (`lib/snippetRefusal.ts`). The audit row
    names the snippets and **never a script** (`"Restart nginx, Disk usage"`),
    since a script is what the user wrote and may hold anything.
  - `tests/snippet_api.rs`; the expansion's own units are in
    `sbm_parser::snippet`. The panel runs the steps it answers with
    (`lib/snippetSteps.ts`, driving `TerminalSession.input`) and hands them to
    the terminal through `lib/snippetRun.svelte.ts`, because the terminal is
    per-visit state the library page cannot reach.
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
- **`GET/POST/DELETE /api/v1/benchmark`** — the yabs benchmark runs this agent
  has started: the history, one run's result and log, and the start, stop and
  forget. **The agent owns the run, not the browser**: a yabs run is ten to
  twenty minutes, so the row is written *before* the launcher starts and a
  resident poller (2 s) carries it to a terminal state whether or not anyone is
  looking. A `running` row left forever would make
  `CREATE UNIQUE INDEX ... WHERE status = 'running'` — which is how one run at a
  time is enforced, rather than by a check two concurrent starts would both pass
  — refuse every future start with nothing to explain it.
  - The command layer is `sbm_parser::bench`, the same strings the app sends
    over SSH: `start_entry` writes a launcher that records **its own `$$`** (the
    process group every child inherits, and the only thing that stops fio, iperf3
    and Geekbench) and `poll_command` reads a directory. So the agent runs no
    part of a benchmark itself and knows nothing about yabs beyond where the
    files are.
  - **`BenchPollState.answered` is load-bearing.** An agent that hit its own
    timeout answers with an empty body, and reading that as "the run directory is
    gone" fails a run that is going fine. Not answered means ask again;
    `dirExists` only means anything once `answered`.
    - The listing reads the history **first** and folds the poll in after, so on
      the one reply where a run has just ended the row still says `running`
      while `live.exit_code` is set. Both writers record the end and one of them
      wins, so a second request reports it; the panel asks again in 300 ms
      rather than carry a state for the window.
  - `result_json` travels as a **string**, never parsed here: yabs assembles its
    JSON with `+=` on a shell string, so a field it could not collect arrives as
    an empty slot and a distro name containing a quote produces a document no
    parser accepts. The client is the one that knows which fields it can live
    without. The log is bounded in three places — 512 KiB stored keeping **both
    ends** (the head says why a phase was skipped, the tail what was measured),
    64 KiB in a poll response, an 8 MiB read cap whose overflow answers
    `answered: false`.
  - The script is `assets/yabs.b64`, embedded with `include_str!` and decoded by
    `bench::decode_asset` — one asset and two loaders, the app's being
    `rootBundle`. Base64 because a bundled asset that reads as executable code
    fails App Store validation (v1574), and `bench::SHA256_HEX` is the contract
    that the two copies are the same program. `tests/benchmark_asset.rs` holds
    it, mirroring the app's own "the vendored asset" group.
  - **Reading needs only the panel login** and starting, stopping and removing
    are `full_access`, the same grant as the shell and `/exec` — a benchmark
    writes gigabytes to a disk and saturates a link, and anyone who can open a
    shell can run one anyway. The pre-flight estimate is a
    `POST {"action":"estimate"}` answered *before* that gate, so the panel never
    re-implements `bench::estimate`'s formula.
  - Linux only, and the listing says so with `supported: false` rather than by
    withholding the route: `remote_access.benchmark` is served like `cron`, so a
    caller who may not start a run still reads the history and is told why, and
    the page goes read-only off `editable`. `DELETE` refuses a run that is going
    (400 `run_in_progress`) and cleans up after a terminal one, best-effort and
    after the row is written — a directory this endpoint could not remove is not
    a reason to lose the result in it.
  - A run that ended badly records a **code** in `error` (`launcher_failed`,
    `nonzero_exit`, `no_exit_code`), phrased by the panel like a refusal. The
    two are one convention: a client in a language the agent does not write.
  - `tests/benchmark_asset.rs`; the poll-state and log-trimming units are in
    `src/api/benchmark.rs`.
- **`GET/POST/DELETE /api/v1/ai/*`** — the Agent: a conversation with a model
  that can run things on this machine. `api/ai/openai.rs` is the client,
  `tools.rs` the three tools, `turn.rs` the loop, `mod.rs` the endpoints.
  - **The loop runs here, not in the browser.** A tool call is a command run as
    the agent's account and the model's key is the agent's, so a browser driving
    the loop would hold the key in page memory for the length of a conversation
    and compose every command itself. Here the panel sends a sentence: it never
    composes a command, never sees the tool schema, and cannot ask for a call the
    classifier did not classify.
  - **Reading needs only the panel login; sending, approving, declining,
    renaming, removing and saving the settings need `full_access`** — the same
    grant as the shell, `/exec` and `/power`, since an approved call runs a
    command and a `shell` call is a shell. **`stop` is answered before that
    gate**: it starts nothing and ends something, and the case it must survive is
    an operator revoking the grant while a turn is running.
  - **The API key is write-only and one field wide** — the `/push` convention
    exactly: `GET /ai/settings` answers `api_key: null` with `api_key_set` beside
    it, a PUT sending that `null` back keeps what is on disk, and `""` clears it.
    Written through `config_file` under `AppState.config_write`, like the other
    `config.toml` editors.
  - **Awaiting review is derived, never stored.** A `function_call` item with no
    `function_output` answering its `call_id` **is** the state. `turn::waiting`
    asks that of the database (what the follow stream can afford) and
    `turn::unanswered` asks it of a list in memory (what the actions hold); two
    expressions of one rule is the shape that drifts, so
    `waiting_agrees_with_unanswered` in `tests/ai_api.rs` asserts they answer the
    same question over the same items. Nothing records that a turn is parked, so
    a restart cannot leave a conversation claiming to be mid-turn — what a turn
    is *doing* is a task, not a row, and lives in `AiTurns` (migration 011), the
    opposite of migration 010's rule for benchmark runs, which are `setsid`
    processes that outlive the agent.
  - **A turn parks when a call may not run unreviewed**: it stores the calls and
    ends. The model is handed a turn again only once *every* call of the batch
    has an answer — a request carrying a call with no result is one the model API
    refuses, which is the app's rule and the reason this one exists — and
    declining answers the whole batch, since it is one proposal made in several
    parts. **The auto-run rule is a deliberate reversal of the app's**:
    `auto_run_safe_commands && risk == ReadOnly`, at most `MAX_AUTO_RUNS` (3) per
    turn, with the model's own `safe_to_run` recorded and not consulted
    (`destructive: true` floors the verdict instead). The classifier is
    `sbm_parser::ai_risk`, and anything it does not recognise is Unknown, so it
    is asked about. Every command a turn runs by itself is in the access log
    under `kind = 'ai'` with `unreviewed=yes`; a row under that kind never
    carries the model key or a conversation's text.
  - **The wire.** `GET /ai/conversations` reads the list or, with
    `?conversation=`, one conversation with its items; `POST` is one tagged
    action (`chat`, `approve`, `decline`, `stop`, `rename`); `DELETE` removes
    one, cascading its items. `GET /ai/follow` is NDJSON, one frame per line:
    `item` for what was stored after the caller's `?after=`, `delta` for text
    that is not an item yet — its `step` is the ordinal that item will get, which
    is what lets a client drop its provisional text exactly when the item
    supersedes it — `state` when `running`/`phase`/`error`/`waiting` changes and
    once at the start, and `ping` every 15 s so a proxy does not close an idle
    stream. A follower therefore sees a turn happen without polling.
  - **A refusal the caller could have avoided is 400 with a stable code**
    (`invalid_base_url`, `empty_message`, `message_too_long`, `invalid_title`,
    `not_configured`, `busy`, `nothing_to_decline`), phrased by the panel in the
    viewer's language; a state of the machine is 404
    (`no_such_conversation`, `no_such_call`). A failure *inside* a turn is a
    `notice` item carrying a code from one vocabulary — `turn.rs`'s
    `interrupted`/`declined`, `storage`, `not_configured`, or an
    `openai::UpstreamError` name (`unreachable`, `auth`, `not_found`,
    `rejected`, `rate_limited`, `unavailable`, `shape`) — because the client
    that reads it is in a language this process does not write. A model's own
    in-band `error` frame becomes one of those rather than reaching the client.
  - **`ai_message` is not a sync root** (the `conn_stat` reason: what the agent
    did is a record, not an edit to replicate); the model and the token counts
    live on the conversation. The raw prompt, the key and the model's own words
    are never in the access log. `tests/ai_api.rs` runs a whole turn against a
    scripted model endpoint on loopback — the request, the stream, the items
    stored, the call parked, the approval running a real command, the turn
    resumed, and the audit rows — and reaches no real endpoint and no real key.
- **`/api/v1/terminal/ws`** — the panel's terminal. The agent is an SSH *client*
  rather than a shell spawner, so a session carries the privileges of the SSH
  account the browser authenticated as; the panel password alone grants no
  shell. Frame type is the channel selector: Binary = PTY bytes, Text = control
  JSON (`api/ws/terminal.rs` documents the messages).
- **`/api/v1/stream/ws`** — a raw TCP connection to an address the app names,
  gated on `full_access` exactly like the shell and `/exec`: it dials as the
  agent's account, so anyone who could open a shell could `ssh -L` from it and
  a switch of its own would withhold nothing. This is what the app's remote
  desktop uses on a monitor-only server, and what port forwarding would use
  next; the agent understands neither RDP nor VNC, which is what makes it one
  endpoint for both. Text frames are the request and control JSON
  (`{"type":"open","host":..,"port":..}` first, then `ready`/`error`/`exit`),
  Binary frames are the bytes. **One socket is one connection and there is no
  session store and no replay** — RDP and VNC reconnect above this, and a
  resumed byte stream would be a corrupted one rather than a shorter one. The
  address travels in the frame, not the URL, so it stays out of access logs.
  `tests/stream_ws.rs`.
- **`/api/v1/rdp/ws`** — an RDP session, with the agent as the RDCleanPath
  proxy (`api/ws/rdcleanpath.rs`). Separate from the relay because RDP cannot
  use it: the client that runs a session in a browser (`ironrdp-web`) opens its
  socket with an RDCleanPath request and refuses anything but an RDCleanPath
  response in reply. The protocol exists because a page cannot do the TLS
  handshake RDP wants — it needs the server's certificate to bind the session's
  credentials to it, and an RDP server's is self-signed as a rule. Gate is
  `full_access`, and `remote_access.rdp` reports that the endpoint *will answer
  this caller* — the same grant, reported the same way as `remote_access.stream`
  and for the same reason, since a client gates a button on it. It is separate
  from `stream` because the two endpoints can come apart (VNC needs only the
  relay); it is not separate from `full_access` the way `desktop` is, because
  `desktop` is about a route list existing and this is about a session being
  possible.
  - **The agent terminates TLS and the operator's stream is plaintext in this
    process.** That is the protocol, not a shortcut: the client marks itself
    upgraded without doing TLS, so what crosses the socket is the RDP stream
    after decryption. Anything that can read the agent's memory can read the
    session, including an NLA credential.
  - **The RDP server's certificate is captured, not verified.** The agent has
    no anchor to check it against, and the party that ends up judging it is the
    client, by binding the credentials to the public key out of the chain it is
    handed. The module says so plainly: the leg between the agent and the RDP
    server is *not authenticated*. The app's own remote desktop over SSH does
    verify and is the choice for a link that is not trusted.
  - **The ticket travels in the request PDU's `proxy_auth`, not in a
    subprotocol.** The wasm client opens its socket with no subprotocols, so the
    `sbm-ticket.` convention the other two endpoints use is not available to it.
    The upgrade therefore cannot check it, which is why the endpoint checks
    `full_access` there, refuses when the request PDU arrives, and puts a
    **deadline on that arrival** (`REQUEST_TIMEOUT`) — otherwise a socket could
    be opened and held open for free.
  - **Three things about the framing are load-bearing.** The socket is a *byte
    stream*, not one message per PDU, so the request is accumulated until
    `RDCleanPathPdu::detect` says it is complete; bytes arriving after the PDU
    are the head of the RDP stream and are forwarded rather than dropped (RDP
    does not tolerate reordering); and **the response must be the first frame
    the client reads**, so the relay task sends it before starting its read loop
    rather than the caller sending it and racing the task.
  - **Every refusal is a DER error PDU, never a text frame** — the client is
    reading through `detect`, which fails on anything that is not a PDU, so a
    sentence would be shown as a decode failure instead of the reason. A
    negotiation the client cannot use goes back as `new_negotiation_error` with
    the server's own bytes, because "CredSSP (NLA) is required" is in them.
  - **A `preconnection_blob` is refused rather than ignored.** It is a PCB for
    the RDP server and what a client puts in the string is a convention its
    author picked, so the wrong reading routes the session to a different RDP
    source with nothing to show for it. Nothing this app sends carries one, so
    refusing costs nothing and cannot be silently wrong. **TODO**: nothing
    forwards a PCB, so a client that needs one cannot use this endpoint.
  - The X.224 negotiation blob is parsed by hand (eleven bytes of TPKT, `LI`,
    TPDU code and references, then type / length / a little-endian value)
    rather than by pulling in `ironrdp-pdu` for four fixed fields.
    `PROTOCOL_RDP` — no security at all — is refused, since the client has
    already marked itself upgraded. `tests/rdp_ws.rs` runs the whole exchange
    against a fake RDP server this test owns: a `TcpListener` that answers the
    negotiated Connection Confirm and terminates TLS with a certificate
    `rcgen` generated.

Things that are easy to get wrong here, and are locked by tests:

- **Auth for the upgrade is a single-use ticket** (`api/ws/ticket.rs`), not the
  JWT: browsers can't set headers on a WebSocket handshake, and a token in the
  query string lands in ntex's access log. Purpose-bound, ~30s, burned even on
  a wrong secret. A ticket carries *which* endpoint, so one minted for the
  terminal is refused at the relay and one minted for the relay is refused at
  the RDP proxy — a client cannot trade one grant for another by changing the
  URL it upgrades against. `rdcleanpath` is the one endpoint whose ticket
  arrives inside the first frame instead of a subprotocol, for the reason its
  own section gives.
- **`awaiting_revocation` (`api/ws/mod.rs`) is shared by both long-lived
  endpoints**, not owned by either: it is the same promise in both — the grant
  is consulted when something is *started*, and a connection already carrying
  bytes would otherwise outlive the switch that revoked it.
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

#### Editing it over the API

Both the panel and the app edit `config.toml` through three endpoints, all
behind `require_jwt!` and all reading the file fresh off disk rather than
`AppState.config` (a startup snapshot, so a GET right after a save would show
stale values). **A `PUT` replaces the whole of what it names**, so a client
that omits a field clears it — `PUT /settings` and `PUT /push` each take
their entire payload at once. The reads do not: `GET /settings`, `GET /push`
and `POST /push/test` write nothing.

- **`GET/PUT /api/v1/settings`** — the whitelist: intervals, idle pause, rules,
  data retention, CORS origins. `jwt_secret`, `database_url` and the
  `remote_access` grants are deliberately not in it. GET adds `live_fields`
  (which of them the running process picks up; everything else waits for a
  restart) and `data_retention_defaults` — absent retention means *no cleanup
  runs at all* rather than "the defaults apply", so an editor offering to
  switch it on needs values to put in, and copying `DataRetentionConfig::default`
  into each editor is how the two would drift.
- **`GET/PUT /api/v1/push`** and **`POST /api/v1/push/test`** (`api/push.rs`) —
  the notification channels and `[monitoring] push_rate`. Split out of
  `/settings` for the reason `/card-order` is, plus one of its own: **a
  credential here is write-only.** A GET answers `null` at every credential key
  (`sc_key`, a Bark `key`, an iOS `token`, every `headers` value), a PUT sending
  that `null` back keeps what is on disk, and a `null` anywhere else is refused
  — so the merge cannot be used to read a stored value out through a field that
  gets transmitted. What "on disk" refers to is `from_index`, the position the
  entry was loaded from: matching by name loses the credential of a renamed
  channel, matching by submitted position loses it on a reorder. A webhook's
  `url` is deliberately *not* treated as a credential even though a Slack one
  is — it is the channel's identity in an editor, and hiding it would mean
  retyping the endpoint to change one header.
  - The other half of the same rule: an unknown `push_type` has its whole
    config withheld (the agent cannot know which of its keys are credentials)
    and cannot be saved at all, since nothing would ever deliver through it.
  - Saved channels reach `rules.rs` on the next start, like the rules
    themselves — `applies_on_restart` says so rather than leaving both editors
    to assume it. TODO: make both live, the way `LiveSettings` already is for
    the intervals.
  - `tests/push_api.rs` asserts the credential is not in the response *bytes*
    and survives a rename plus a reorder; the unit tests in `api::push` cover
    the merge rules on their own.

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

### Build profile and binary size

The shipped agent is built with `--profile release-monitor` (workspace
`Cargo.toml`), which is `release` plus `lto = "fat"` and `codegen-units = 1`.
Both are profile-wide — `[profile.release.package.*]` accepts neither — so
they cannot be asked for on the shared profile without putting a fat-LTO link
in front of every app build too.

- **`monitor/Dockerfile` sees none of that.** It rewrites the `sbm_parser`
  path so `monitor/Cargo.toml` becomes the root, which puts the build outside
  the workspace and outside every `[profile]` in it, `strip` included. It
  passes the same three settings as `CARGO_PROFILE_RELEASE_*`. Anything added
  to a workspace profile has to be repeated there or it silently does not
  apply to the image people build themselves.
- **`nix/package.nix` builds inside the workspace** (`buildAndTestSubdir =
  "monitor"`, source is the repository), so it does get `[profile.release]`
  and its `strip`, but not `release-monitor`. Moving it there means
  `cargoBuildType`, whose handling differs between nixpkgs releases and is
  not verified here.
- **`opt-level` stays at 3.** `"s"` takes the binary from 15.2 MB to 11.2 MB,
  measured, and this process samples the machine and terminates every TLS
  connection to it — worth having the number, not worth taking silently.
- **One crypto implementation, `ring`.** `cargo tree -i aws-lc-sys` must find
  nothing: aws-lc-sys is a second complete implementation and a cmake build
  script in front of the musl targets. reqwest is the one that brings it in
  by default (its `rustls` feature *is* `__rustls-aws-lc-rs`), so it uses
  `rustls-no-provider` and `monitoring::push::http_client` installs the ring
  provider before building the client. Without that install, building the
  client panics inside reqwest rather than failing as a push error — held by
  the four webhook tests in `monitoring::push`, which is also the only signal
  that a newly added TLS dependency has brought its own provider back.

Measured on macOS arm64, all with `strip`: 22.0 MB stock → 20.1 MB without
aws-lc → 15.2 MB with the profile.

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
