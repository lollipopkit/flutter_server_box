---
title: Monitor Agent API and Access Model
description: Capability reporting, metrics history, and remote access behavior
---

The App uses the API behavior described here when it connects to Monitor agent.
For installation and configuration, see
[Monitor Agent](/docs/advanced/monitor-agent/).

## Protocol version

The App and the agent compare one number, the protocol
(`sbm_parser::protocol`). It changes only when the API breaks: a field
removed or renamed, a meaning changed, a route removed. New features do not
change it; they are listed in `features`.

- `GET /api/v1/health` needs no sign-in and reports `protocol` and
  `min_client_protocol`. It does not report the release version, which is in
  `/capabilities`. An agent without these fields speaks protocol 1.
- Every request carries `X-SBM-Protocol: <n>`. A request without it is
  protocol 1. An agent answers a client below `min_client_protocol` with
  `426` and `{"error": "client_too_old", "protocol", "min_client_protocol"}`.
  `/health`, preflights and WebSocket upgrades are not checked; the
  `/ws-ticket` request before an upgrade is.
- Before signing in, the App reads `/health`. It reports "update the agent"
  when the agent is older than the App reads, and "update the App" when the
  agent no longer answers it.
- Each side supports the previous protocol at least: the agent answers an
  older client in that client's format, and the App still reads an older
  agent.

## Capability discovery

The App calls `GET /api/v1/capabilities` to learn which features an agent
supports and whether the signed-in caller may use them. The response includes:

- `access`: `ok`, and when it is false, `why`. `insecure_transport` means
  the request needs TLS, a loopback caller, or
  `[remote_access] allow_insecure`. For a watch token `access` is
  `{"ok": false}`.
- `features`: the machine-management endpoints the agent serves, such as
  `power`. A client offers a page when its name is listed and `access.ok`.
  `container_exec`, `iperf`, and `tmux` are terminal targets rather than
  pages; each is offered only where it is listed. `alerts`, `audit`, and
  `live` are the Monitor tab's sections (`GET /alerts`, `GET /audit`,
  `/live*`), and `desk` its notifications. `update` is `GET /update`: the
  agent's version, the newest release it read (`?check=1` reads again),
  `outdated`, how it was installed (`install`: `script`, `container`, `nix`,
  `other`) and, for `script`, the `command` that updates it, whether starting
  it needs the sudo password, and the last update's `run` (state and output).
  `POST /update/run` starts it apart from the agent, which survives the
  agent's restart.

Do not infer feature availability from the agent version or configuration
defaults. Use the capabilities response from the running agent.

## Metrics history contract

The capabilities response reports:

- `retention_days`: the configured retention limit from
  `[monitoring.data_retention] metrics_days`.
- `oldest_sample`: the timestamp of the oldest metrics sample currently
  stored.

The App offers preset chart ranges that fit within the later boundary implied
by retention and the oldest sample. It displays both values in the range
picker. Older agents that do not report retention use the fixed chart ranges.

The App can request an exact interval with:

```text
GET /api/v1/metrics/history?from=<epoch-seconds>&to=<epoch-seconds>
```

If `from` precedes the oldest retained sample, the agent returns the available
rows. It does not shift the requested start time or return an error. The chart
represents the missing interval as a gap. Without `from`, `?minutes=` sets the
window's length (default 60, at least 5, at most 7 days), ending at `to` or
now. The App includes `minutes` in each request, so agents that predate
`from` and `to` can still handle it.

## Access model

The agent has one account, signed in with its password alone, and it may do
whatever the system account the agent runs as may do. There are no roles,
grants, or file roots. The full contract, including every request and response
shape, is
[docs/dev/monitor-permissions.md](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/dev/monitor-permissions.md) in the repository.

Reading status, metrics, history, velocity, capabilities, and the card order
needs a login or a watch token. A watch token can do nothing else; every other
endpoint answers it `401`.

### Signing in and the password

| Endpoint | Body |
|---|---|
| `POST /api/v1/login` | `password`; a `username` field is ignored |
| `PUT /api/v1/me/password` | `current_password`, `new_password` (at least 8 characters) |

`server_box_monitor password` sets the password on the database from the
command line (`--password-env VAR` reads it from the environment), creating
the account if there is none.

Some changes ask for the current password again in the body
(`current_password`): changing the password, deploying a web app, changing its
settings or removing it, revealing its first login, restoring or deleting a
container backup, and approving or removing a desk app. It goes through the
login throttle, per source address and on a counter only signed-in callers
share. A wrong or missing one answers `403 reauth`; a run of wrong ones
answers `429 throttled` with `Retry-After`.

Errors are `{"error": "<code>", "message": "..."}`:

| Code | Status | Meaning |
|---|---|---|
| `bad_request` | 400 | The body has the wrong shape |
| `unauthorized` | 401 | No valid login, a token issued before the last password change, or a watch token outside its scope |
| `forbidden` | 403 | The transport rule refuses it |
| `reauth` | 403 | `current_password` is missing or wrong |
| `throttled` | 429 | Too many failed attempts |

### Password change

A password change signs out everything else. Panel tokens issued before it
answer `401` everywhere, watch tokens are deleted, and in a running agent
terminal sessions, outstanding tickets, running Agent mode tasks, web app
windows, relays, and listeners receive
`{"type":"error","code":"password_changed"}` and are closed. A reset from the
command line cannot reach a running agent's open connections; they end when
the agent restarts.

### Transport

Everything beyond reading needs TLS or a loopback caller, which includes a
reverse proxy on the same host, unless `[remote_access] allow_insecure = true`.
TODO: Remove the legacy `allow_insecure` keys when existing configurations no
longer need them. Until then, `[remote_access.terminal] allow_insecure` and
`[remote_access.fs] allow_insecure` count as it. A plaintext connection from
the App also needs **Allow insecure HTTP** for that server. Without either,
capabilities report `access` with `why: insecure_transport`, and the
endpoints answer `forbidden`.

### File API

`/api/v1/fs/*` reaches whatever the agent's system account can, except the
agent's own state: its database and journal files, `jwt.secret`,
`initial-admin-credentials.txt`, `config.toml` and its backups, `.env`, the
TLS certificate and key, the custom-commands directory, the blob store,
stacks' `.env` files, and container backups. These paths are matched after
resolving symlinks, refused with `403`, left out of listings, and their
directories cannot be renamed, removed, or chmod-ed.

### Terminal endpoint

The terminal of the App and of the web panel is a local shell running as the
agent process user, on a PTY. The agent does not sign in to sshd: an `open`
carrying SSH credentials is refused.
