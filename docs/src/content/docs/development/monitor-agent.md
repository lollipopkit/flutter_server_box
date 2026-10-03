---
title: Monitor Agent API and Access Model
description: Capability reporting, metrics history, and remote access behavior
---

This page documents the API behavior the App relies on when connecting to
Monitor agent. For installation and operator configuration, see
[Monitor Agent](/docs/advanced/monitor-agent/).

## Capability discovery

The App calls `GET /api/v1/capabilities` to learn which features an agent
supports and what the signed-in account may use. The response answers for the
caller:

- `me`: `username`, `role`, and `admin`. A watch token gets no `me`.
- `grants`: one entry for each of `shell`, `ssh_terminal`, `files`,
  `connect`, `listen`, and `virt`, with `ok` and, when it is not usable, `why`:
  `not_granted` (the role does not hold it), `insecure_transport` (it needs
  TLS, a loopback caller, or `[remote_access] allow_insecure`), or
  `not_configured` (`files` with no `roots`). A grant also carries its
  options: `files.mode`, `connect.allow`, `listen.public`, and
  `listen.ports`. For a watch token every grant is `not_granted`.
- `remote_access`: the booleans agents reported before roles, derived from
  `grants` for older Apps (`terminal` is `ssh_terminal` or `shell`,
  `full_access` is `shell`, `stream` is `connect`). The App reads `grants`
  when it is present.

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
represents the missing interval as a gap. The older `?minutes=` parameter
remains supported for agents that predate `from` and `to`.

## Access model

Each account has one role, and a role holds grants. The full contract,
including every request and response shape, is
[docs/dev/monitor-permissions.md](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/dev/monitor-permissions.md) in the repository.

| Grant | Endpoints |
|---|---|
| `shell` | `POST /api/v1/exec`, the App's terminal (a local PTY on `/api/v1/terminal/ws`), running custom commands |
| `ssh_terminal` | The web panel's terminal on `/api/v1/terminal/ws`, which signs in to `ssh_addr` with SSH credentials |
| `files` | `/api/v1/fs/*`; `mode = "read"` allows `roots`, `list`, `stat`, and `read` only |
| `connect` | `open` on `/api/v1/stream/ws`, checked against `allow` |
| `listen` | `/api/v1/listen/ws`, and `accept` on `/api/v1/stream/ws` |
| `virt` | `GET /api/v1/bmc`, `GET /api/v1/bmc/{id}` and `POST /api/v1/bmc/{id}/power`: the hypervisors and BMCs the agent reaches for the panel |

Reading status, metrics, history, velocity, capabilities, and the card order
needs any account or a watch token. A watch token can do nothing else.

### Accounts and roles

Only an account in the `admin` role may call these, apart from the two `/me`
routes, which any account may call:

| Endpoint | Body |
|---|---|
| `GET /api/v1/me` | — answers `username` and the full `role` |
| `PUT /api/v1/me/password` | `current_password`, `new_password` (at least 8 characters) |
| `GET /api/v1/users` | — |
| `POST /api/v1/users` | `username`, `password`, `role`, `current_password` |
| `PUT /api/v1/users/{username}` | optional `role` and `password`, `current_password` |
| `DELETE /api/v1/users/{username}` | `current_password` |
| `GET /api/v1/roles` | — |
| `POST /api/v1/roles` | `role`, `current_password` |
| `PUT /api/v1/roles/{name}` | `role`, `current_password` |
| `DELETE /api/v1/roles/{name}` | `current_password` |

`current_password` is the calling admin's own password. It goes through the
login throttle, so a run of wrong ones answers `429 throttled` with
`Retry-After`. The agent's settings (`/settings`, `/push`, `/push/test`,
`PUT /card-order`) are admin-only as well, and `PUT /custom-cmds` also needs a
usable `shell`, because the agent runs custom commands.

Errors are `{"error": "<code>", "message": "..."}`:

| Code | Status | Meaning |
|---|---|---|
| `bad_request` | 400 | The body has the wrong shape, including an unknown grant |
| `unauthorized` | 401 | No valid login; a deleted account's token gets this everywhere |
| `forbidden` | 403 | Not an admin, or the role lacks the grant |
| `reauth` | 403 | `current_password` is missing or wrong |
| `not_found` | 404 | No such account or role |
| `conflict` | 409 | The name exists, or the role is still in use |
| `last_admin` | 409 | The change would leave no admin account |

### Live sessions

A change to an account or a role applies immediately. A terminal, relay, or
listener whose account no longer holds the grant it needs receives
`{"type":"error","code":"permission_revoked"}` and is closed. A WebSocket
request that needs a grant the account lacks answers `forbidden`; a `listen`
outside the role's `public` or `ports` limits answers `not_permitted`. The
legacy `DELETE /api/v1/remote-access/full-access` removes `shell`, `connect`,
and `listen` from every role and still closes sessions with
`full_access_disabled`.

### Transport

Every grant needs TLS or a loopback caller, which includes a reverse proxy on
the same host, unless `[remote_access] allow_insecure = true`. The older
keys still count for what they used to cover, and no more:
`[remote_access.terminal] allow_insecure` for `shell`, `ssh_terminal`,
`connect` and `listen`, `[remote_access.fs] allow_insecure` for `files`. A plaintext connection from the App also needs
**Allow insecure HTTP** for that server. Without either, the grant is reported
with `why: insecure_transport`.

### Connections and listeners

`connect.allow` entries are an IP address or CIDR range with an optional port
or port range, with IPv6 written as `[addr]:port`. When a connection names a
host, the agent resolves it, requires every resulting address to be allowed,
and dials those addresses. `localhost` often resolves to both `127.0.0.1` and
`::1`, so a client should send the address it means.

`listen` binds loopback addresses only unless `public` is on, and only ports
inside `ports` when that is set.

### File API

The `files` grant reaches only the directories listed in
`[remote_access.fs] roots`. The agent resolves requested paths, follows
symlinks, rejects `..`, and verifies that the resolved path remains under a
configured root. A symlink cannot be used to escape those roots. Setting
`roots = ["/"]` exposes the complete filesystem and triggers a startup
warning.

### Terminal endpoint

The web-panel terminal connects to `ssh_addr` as an SSH client and uses the
SSH account's permissions; it needs `ssh_terminal`. The App terminal uses the
agent process user's local shell and needs `shell`. The endpoint's first
message may contain an SSH password, which is why it follows the transport
rule above.
