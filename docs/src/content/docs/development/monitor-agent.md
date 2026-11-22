---
title: Monitor API and Access Model
description: Capability reporting, metrics history, and remote access behavior
---

The App uses the API behavior described here when it connects to the Monitor.
For installation and configuration, see
[Monitor](/docs/advanced/monitor-agent/).

## Protocol version

The App and the Monitor use a single protocol version number
(`sbm_parser::protocol`). It changes only for breaking API changes, such as
removing or renaming a field, changing a field's meaning, or removing a route.
New features do not change the protocol version; they are listed in `features`.

- `GET /api/v1/health` needs no sign-in and reports `protocol` and
  `min_client_protocol`. It does not report the release version, which is in
  `/capabilities`. A Monitor without these fields speaks protocol 1.
- Every request carries `X-SBM-Protocol: <n>`. A request without it is
  protocol 1. A Monitor answers a client below `min_client_protocol` with
  `426` and `{"error": "client_too_old", "protocol", "min_client_protocol"}`.
  `/health`, preflights and WebSocket upgrades are not checked; the
  `/ws-ticket` request before an upgrade is.
- Before signing in, the App reads `/health`. It prompts you to update the
  Monitor when its protocol is too old, or to update the App when the Monitor
  requires a newer protocol.
- The Monitor answers a client one protocol older in that client's format.
  The App reads no Monitor below protocol 2, and prompts you to update it.

## Capability discovery

The App calls `GET /api/v1/capabilities` to learn which features a Monitor
supports and whether the signed-in caller may use them. The response includes:

- `access`: `ok`, and when it is false, `why`. `insecure_transport` means
  the request needs TLS, a loopback caller, or
  `[remote_access] allow_insecure`. For a watch token `access` is
  `{"ok": false}`.
- `features`: the machine-management endpoints the Monitor serves, such as
  `power`. A client offers a page when its name is listed and `access.ok`.
  `container_exec`, `iperf`, and `tmux` are terminal targets rather than
  pages; each is offered only where it is listed. `alerts`, `audit`, and
  `live` are the Monitor tab's sections (`GET /alerts`, `GET /audit`,
  `/live*`), and `desk` its notifications. `update` is `GET /update`: the
  Monitor's version, the newest release it read (`?check=1` reads again),
  `outdated`, how it was installed (`install`: `script`, `container`, `nix`,
  `other`) and, for `script`, the `command` that updates it, whether starting
  it needs the sudo password, and the last update's `run` (state and output).
  `POST /update/run` starts it apart from the Monitor, which survives the
  Monitor's restart.

Do not infer feature availability from the Monitor version or configuration
defaults. Use the capabilities response from the running Monitor.

## Metrics history contract

The capabilities response reports:

- `retention_days`: the configured retention limit from
  `[monitoring.data_retention] metrics_days`.
- `oldest_sample`: the timestamp of the oldest metrics sample currently
  stored.

The App offers preset chart ranges that fit within the later boundary implied
by retention and the oldest sample. It displays both values in the range
picker. Older Monitor versions that do not report retention use the fixed chart ranges.

The App can request an exact interval with:

```text
GET /api/v1/metrics/history?from=<epoch-seconds>&to=<epoch-seconds>
```

If `from` precedes the oldest retained sample, the Monitor returns the available
rows. It does not shift the requested start time or return an error. The chart
represents the missing interval as a gap. Without `from`, `?minutes=` sets the
window's length (default 60, at least 5, at most 7 days), ending at `to` or
now. The App includes `minutes` in each request, so Monitor versions that predate
`from` and `to` can still handle it.

### Per-device detail

Each point carries the aggregate and, since migration 044, the devices behind
it: `mounts` (used and total bytes), `ifaces` (a rate, see below), `gpus`
(usage and memory in MiB) and `temps` (every temperature sensor). A field is
**absent** when that bucket holds no detail — every window older than
migration 044, and any Monitor that predates it — never an empty list, which
a client would read as "a machine with no mounts". A client that draws these
must treat a missing field as a gap, not as zeros.

Detail is stored as **stretches, not samples**. `metrics_disk_usage`,
`metrics_iface`, `metrics_gpu` and `metrics_temp` each hold one row per
stretch of time over which a device's reading held: `start`, `end` and the
value. A reading that does not move (a disk at 10 % all day) is one row per
hour (`MAX_SEGMENT`), not one row per sample; a reading that moves past its
table's threshold opens a new row. Stretches younger than 30 seconds are
extended and blended over elapsed time rather than cut, and no stretch runs
longer than an hour even unchanged — so sustained load cannot flood the tables
and a slowly drifting value still leaves points to draw.

Thresholds: disk usage 1 percentage point (1% of the mount's total, over
bytes), interface rate 50% change in either direction, GPU usage 5 points and
GPU memory 5% of its total, temperature 1 °C. An interface is recorded only
while it moves at least 10 KB/s in either direction — an idle link is no
detail, and most links are idle most of the time.

A stretch is open only while it was extended at the previous sample: a
device that disappears (a mount unmounted, an interface gone) closes its
stretch, and a returning device opens a new one — even when the reading it
returns with is the one it left with. An interface's stretch ends at the
last sample that saw traffic; the idle cycles in between belong to no
stretch.

In an answer, a stretch appears in **every bucket it overlaps**, with the
value it held: a six-hour stretch is six points in a one-hour-bucket answer,
not a spike at its start and a gap after. When multiple stretches of the same
device overlap a single bucket, they are merged into one duration-weighted
entry per device so every point lists each device at most once. Interface
figures are rates (`rx_bytes_per_sec`, `tx_bytes_per_sec`), so a client does
not derive them again from counters it may only hold part of.

## Access model

The Monitor has one account, signed in with its password alone, and it may do
whatever the system account the Monitor runs as may do. There are no roles,
grants, or file roots. The Monitor, the web panel, and the App share the
contract below.

Reading status, metrics, history, velocity, capabilities, and the card order
needs a login or a watch token. A watch token can do nothing else; every other
endpoint answers it `401`.

### Signing in and the password

| Endpoint | Body |
|---|---|
| `POST /api/v1/login` | `password`, `device` (optional), `name` (optional); a `username` field is ignored. Answers `token` and, for a device the Monitor does not know, a new `device` token |
| `PUT /api/v1/me/password` | `current_password`, `new_password` (at least 8 characters); answers `204` |

A client keeps the `device` token per Monitor (the App in the Keychain or
Keystore, the panel in `localStorage`) and sends it with every later sign-in.
`name` is what the device is listed as under `GET /live`, else its User-Agent:
at most 80 characters, control characters dropped. Every sign-in, accepted or
refused, is an audit row (`login`, the address, and `device known`,
`new device`, `wrong password` or `throttled`); it never holds the password or
a token.

Sign-ins are throttled per source address and per caller: a known device (its
token is kept as a SHA-256 for 180 days since last use, the newest 64) on its
own counter, every other client on one shared counter, and a signed-in caller
entering the password again on a counter only such callers share. Failures
from unknown clients therefore cannot lock out a device that signed in before.
Three failures pass per address and per device, twenty on the shared counter;
then the delay doubles from 1 s up to 5 min. A password change forgets every
device.

`server_box_monitor password` sets the password on the database from the
command line (`--password-env VAR` reads it from the environment), creating
the account if there is none.

Some changes ask for the current password again in the body
(`current_password`): changing the password, deploying a web app, changing its
settings or removing it, revealing its first login, restoring or deleting a
container backup, and approving or removing a desk app. It goes through the
login throttle described above. A wrong or missing one answers `403 reauth`; a run of wrong ones
answers `429 throttled` with `Retry-After`.

Errors are `{"error": "<code>", "message": "..."}`:

| Code | Status | Meaning |
|---|---|---|
| `bad_request` | 400 | The body has the wrong shape |
| `unauthorized` | 401 | No valid login, a token issued before the last password change, or a watch token outside its scope |
| `forbidden` | 403 | The transport rule refuses it |
| `reauth` | 403 | `current_password` is missing or wrong |
| `throttled` | 429 | Too many failed attempts |
| `not_found` | 404 | An unknown `/api/v1/*` path |

### API tokens and MCP

An MCP client (Claude Code, Claude Desktop, any Streamable HTTP client)
controls this machine through `POST /api/v1/mcp` with an **API token** (`sbt_`
+ 64 hex), shown once at creation and stored as its BLAKE3 hash.

| Endpoint | Body |
|---|---|
| `GET /api/v1/api-tokens` | Every token: `id`, `name`, `scopes`, `commands`, `created_at`, `expires_at`, `expired`, `last_used_at`, `last_used_ip` |
| `POST /api/v1/api-tokens` | `name`, `password` (re-authenticated), optional `scopes` (default: all), optional `commands` (default: `allow_all`), optional `days` (default 90, max 3650). Answers the row and `token_value` — once |
| `PUT /api/v1/api-tokens/{id}` | Updates `name`, `scopes`, and `commands`. Audited |
| `DELETE /api/v1/api-tokens/{id}` | `204`, or `404` when gone. Audited |
| `GET /api/v1/api-tokens/policy` | Global MCP ceiling (`scopes`, `commands`, `config_scopes`) |
| `PUT /api/v1/api-tokens/policy` | Updates global `scopes` and `commands`, live without restart. Audited |

Permissions default open — all 11 scopes enabled and `allow_all` commands — and
can be narrowed at three intersected layers: `config.toml` (`[mcp]`), the
UI-managed global policy (`mcp_policy`), and each token's own permissions.
There is no scope for managing tokens or the account itself. A token requires
TLS or a loopback caller as acting does; a password change deletes every token,
and the list records each token's last use (at most once a minute).

The protocol, the token format, the scopes, the tool catalog and the tools any
machine reached through a shell answers (processes, services, containers,
tmux, `run_command` and the actions) are `crates/sbm_mcp`, shared with the
app's own MCP server.

`POST /api/v1/mcp` speaks Streamable HTTP in its stateless JSON shape: one
JSON-RPC message per POST, answered with one `application/json` body, a
notification by `202`, and `405` (`Allow: POST`) for `GET` or `DELETE`. The
client must send `Accept: application/json` and `Content-Type: application/json`;
a body over 4 MiB is `413` before it is read; an `Origin` not in
`cors_allowed_origins` (or same-origin) is `403`. The protocol header is not
required; the MCP protocol version is negotiated in `initialize`.

`tools/list` answers only what the effective scopes allow. Every `tools/call`
is an audit row (`mcp`), naming the tool and the token; arguments are not
recorded, except that `run_command` records the first line of the command
before running it, as `POST /exec` does, and `fs_*` tools record `fs` audit
rows.

| Scope | Tools |
|---|---|
| `read` | `machine_status`, `machine_metrics`, `machine_capabilities`, `processes`, `services`, `containers`, `cron`, `tmux`, `firewall`, `storage`, `virt`, `stacks`, `system_users` |
| `fs_read` | `fs_roots`, `fs_list`, `fs_stat`, `fs_read` |
| `fs_write` | `fs_write`, `fs_mkdir`, `fs_rename`, `fs_chmod`, `fs_remove` |
| `exec` | `run_command` |
| `process` | `kill_process` |
| `service` | `service_action` |
| `container` | `container_action` |
| `cron` | `cron_edit` |
| `virt` | `virt_power` |
| `stacks` | `stack_action` |
| `power` | `power` |

#### Command rules and `config.toml` ceiling

Both the global policy (`/api/v1/api-tokens/policy`) and individual tokens
carry `commands: { mode: "allow_all" | "allowlist", allow: [...], deny: [...] }`
using the same pattern matcher as Agent mode (`fl_pi_llm::permissions::rules`).
By default (`allow_all`), any command runs unless a `deny` rule matches any
part of it; in `allowlist` mode, `allow` must cover every part of the command.
An optional `[mcp]` section in `config.toml` sets a hard operator ceiling on
top:

```toml
[mcp]
disabled_scopes = []
allow_power = true

[mcp.commands]
mode = "allow_all"
allow = []
deny = ["rm -rf /"]
```

A `sudo` password has no way in through MCP: an action that needs root answers
`sudo_rejected`, for the operator to do from the panel or with passwordless
`sudo`.

### Password change

A password change signs out everything else. Panel tokens issued before it
answer `401` everywhere (a token from the same second still counts, so
signing in again right after works), watch tokens and the LK Cloud session are
deleted, and in a running Monitor
terminal sessions, outstanding tickets, running Agent mode tasks, web app
windows, relays, and listeners receive
`{"type":"error","code":"password_changed"}` and are closed. A reset from the
command line cannot reach a running Monitor's open connections; they end when
the Monitor restarts.

### Transport

Everything beyond reading needs TLS or a loopback caller, which includes a
reverse proxy on the same host, unless `[remote_access] allow_insecure = true`.
For backward compatibility, `[remote_access.terminal] allow_insecure` and
`[remote_access.fs] allow_insecure` are also accepted as aliases. A plaintext connection from
the App also needs **Allow insecure HTTP** for that server. Without either,
capabilities report `access` with `why: insecure_transport`, and the
endpoints answer `forbidden`.

### Monitor tab endpoints

| Endpoint | Answers | Rule |
|---|---|---|
| `GET /api/v1/alerts` | `checked_at`, `alerts`: `rule`, `monitor_type`, `matcher`, `threshold`, `value`, `since` for each rule firing at the last check (kept in memory: a restart forgets `since`) | Any login |
| `GET /api/v1/update[?check=1]` | `version`, `latest`, `checked_at`, `error`, `outdated`, `install`, `command`, `needs_password`, `run`. The release is read every 12 hours; `check=1` reads it again, at most once a minute. `run` is `state` (`running`, `done`, `failed`, `interrupted`), `started_at`, `exit`, `lines` | Any login |
| `POST /api/v1/update/run` | `202`. Takes `password` (sudo's) where `needs_password`; a wrong one is `403 sudo_password`. `409 not_script` when `install.sh` did not install the Monitor, `409 running` while an update runs. Audited | Transport |
| `GET /api/v1/audit?limit&before&kind&result` | `entries` (`id`, `timestamp`, `kind`, `action`, `result`, `subject`, `remote_ip`, `ssh_user`, `detail`), newest first, and `next` for `before`. An unknown `kind` or `result` is `400 invalid_input` | Transport |
| `GET /api/v1/live` | `sessions`, `connections`, `watch_tokens`, `devices` | Transport |
| `DELETE /api/v1/live/{sessions,connections,devices}/{id}` | `204`, or `404` when it is gone. An ended session or connection is told `ended`; a forgotten device is not signed out, but its next sign-in counts as an unknown client's and gets a new token. Audited | Transport |

### File API

`/api/v1/fs/*` reaches whatever the Monitor's system account can, except the
Monitor's own state: its database and journal files, `jwt.secret`, `credentials.key`,
`initial-admin-credentials.txt`, `config.toml` and its backups, `.env`, the
TLS certificate and key, the custom-commands directory, the blob store,
stacks' `.env` files, and container backups. These paths are matched after
resolving symlinks, refused with `403`, left out of listings, and their
directories cannot be renamed, removed, or chmod-ed.

### Terminal endpoint

The terminal of the App and of the web panel is a local shell running as the
Monitor process user, on a PTY. The Monitor does not sign in to sshd: an `open`
carrying SSH credentials is refused.
