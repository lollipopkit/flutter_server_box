# Monitor agent access — the contract

The agent (`monitor/src`), web panel (`monitor/frontend`), and app (`lib/`) share this contract. Report deviations instead of making unilateral changes.

## One account

The agent has one account, signed in with its password alone. It may do whatever the system account the agent runs as may do: terminals, commands, files, relays, listeners, hypervisors, the machine pages. Which system account that is decides the reach: `install.sh` runs the agent as the invoking account (`--system` as root). There are no roles, grants, file roots or read-only installs.

- `users` holds one row (`id`, `password_hash`, `created_at`, `last_login`, `password_changed_ms`). Data keyed by account (desk, Agent mode) uses its `id`.
- A panel JWT's `sub` is always `owner` (`auth::SUBJECT`); it is valid while its `iat` is not before `password_changed_ms`.
- Watch tokens (`POST /watch-token`, for widgets and watches) only read: status, metrics, history, velocity, capabilities, card order. Everything else answers them 401.

### Transport

Everything beyond reading needs TLS or a loopback peer, unless `[remote_access] allow_insecure = true`. The older `[remote_access.terminal] allow_insecure` and `[remote_access.fs] allow_insecure` count as it (TODO remove).

### Login throttle

Per source address, and per who is asking (`api::ratelimit::Who`): a known device (its token is in `login_device`, migration 033, SHA-256 only, 180 days since last use, newest 64) on its own counter; any other client on one counter they all share; a signed-in caller re-entering the password (`reauth`) on one only such callers share. Failures from strangers therefore cannot lock out a device that signed in before. Three failures pass per address and per device, twenty on the shared counter; then the delay doubles from 1 s to 5 min. A password change empties `login_device`.

### Re-authentication

Some changes ask the current password again in the body (`current_password`), through the login throttle: `PUT /me/password`, deploying a web app, changing its settings, removing it, revealing its first login, restoring or deleting a container backup, approving or removing a desk app. A wrong or missing one is `403 {"error":"reauth"}`; a throttled one `429` with `Retry-After`.

## Endpoints

- `POST /api/v1/login` `{"password", "device"?, "name"?}` → `{"token", "device"?}`. A `username` field is ignored. `device` in the answer is a new device token, given when the request carried none the agent knows; the client keeps it per agent (the app in the Keychain/Keystore, the panel in `localStorage`) and sends it with every later sign-in. `name` is what the device is listed as (`GET /live`), else its User-Agent; at most 80 characters, control characters dropped. Every sign-in, accepted or refused, is an audit row (`login`, the address, `device known`/`new device`/`wrong password`/`throttled`), never the password or token.
- `PUT /api/v1/me/password` `{"current_password", "new_password"}` → `204`. New password ≥ 8 chars.
- `server_box_monitor password [--password-env VAR]` (CLI) sets it on the database, creating the account if there is none.

- `GET /api/v1/alerts` → `{"checked_at"?, "alerts": [{"rule", "monitor_type", "matcher", "threshold", "value", "since"}]}`: the rules firing at the last check, in memory (a restart forgets `since`). Any panel token.
- `GET /api/v1/update[?check=1]` → `{"version", "latest"?, "checked_at", "error"?, "outdated", "install", "command"?, "needs_password", "run"?}`: the newest `monitor-v*` release as the agent last read it (every 12 h; `check=1` reads again, at most once a minute), `command` (`install.sh upgrade`) only for an agent `install.sh` put there, and `run` `{"state": "running"|"done"|"failed"|"interrupted", "started_at", "exit"?, "lines"}`: the last update started, read from `update.log`. Any panel token; it changes nothing.
- `POST /api/v1/update/run` `{"password"?}` → `202`: starts `install.sh upgrade` outside the agent so that its restart does not end it. `password` is sudo's, where `needs_password` (OpenRC, agent not root); refused `403 {"error":"sudo_password"}`. `409 {"error":"not_script"}` for an agent `install.sh` did not install, `409 {"error":"running"}` while one runs. Acting rule; audited `machine` `update start`.
- `GET /api/v1/audit?limit&before&kind&result` → `{"entries": [{"id", "timestamp", "kind", "action", "result", "subject", "remote_ip", "ssh_user", "detail"}], "next"?}`, newest first; `before` is the previous page's `next`. An unknown `kind` or `result` is `400 invalid_input`. Acting rule (it names commands and addresses).
- `GET /api/v1/live` → `{"sessions", "connections", "watch_tokens", "devices"}`; `DELETE /live/sessions/{id}`, `/live/connections/{id}` end one (its client is told `ended`), `/live/devices/{id}` forgets a device (its next sign-in is a stranger's and gets a new token; it is not signed out). `204`, or `404` when it is gone. Acting rule; every ending audited (`admin`).
- An unknown `/api/v1/*` path is `404 {"error":"not_found"}`, never the panel's page.

There are no `/me`, `/users*`, `/roles*` or `/remote-access/full-access` routes.

## Capabilities

`GET /api/v1/capabilities` adds, for the caller:

```json
"access": { "ok": false, "why": "insecure_transport" }
```

`why` (only when `ok` is false): `insecure_transport`. For a watch token `access` is `{"ok": false}`.

`features` lists the machine-management endpoints the agent serves (`["power", ...]`, `api::machine::FEATURES`), for any caller; absent on an agent that serves none. A client offers a page when its name is there and `access.ok`. Not every entry is a page: `container_exec`, `iperf` and `tmux` are the terminal's `target`s, each offered only where it is listed — an older agent ignores the field and would open a host shell.

## Password change

`users.password_changed_ms` moves strictly forward. Panel tokens with `iat` before it (to the second — a token from the same second still counts, so signing in again right after works) are 401 everywhere; watch tokens are deleted; and in a running agent terminal sessions, outstanding tickets, running Agent mode tasks with their sudo passwords and uploads, web app windows, relays and listeners end with `{"type":"error","code":"password_changed"}` then close. A CLI reset cannot reach a running agent's live connections; they end when the agent restarts.

## The agent's own state

The file API reaches the whole filesystem the system account can, except the agent's own state: the database and its `-wal`/`-shm`/`-journal` files, `jwt.secret`, `credentials.key` and `initial-admin-credentials.txt` beside it, `config.toml` and every `config.toml.*` beside it, `.env` (and `.env.*`) in the working directory and the file `dotenvy` loaded, the TLS certificate and key, the custom-commands directory, the blob store, stacks' `.env` files and container backups. Matched on canonical paths, refused with 403, left out of listings, and their directories cannot be renamed, removed or chmod-ed (`fs_roots::Protected`). `jwt.secret` would mint tokens and the rest holds credentials, so a file write is not a way to them.

## Migration

Migration `032_one_account` keeps the oldest admin (the lowest id with role `admin`; the lowest id if none): its password signs in from then on. The other accounts' Agent mode tasks, memory files, desk themes, desk app data (whole apps it has none for) and read notifications move to it; their desk layout, wallpaper, windows and paired watches are deleted. `roles`, `users.username`, `users.role` and the `*_by` columns go.
