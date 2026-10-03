# Monitor agent permissions — the contract (issue #1610)

Fixed. The agent (`monitor/src`), the web panel (`monitor/frontend`) and the app (`lib/`) are built against exactly this, in parallel. A deviation is reported back, not improvised.

## Grants

Six grants. `read` (status, charts, history) is held by every account and is not listed.

| Grant | Covers | Options |
|---|---|---|
| `shell` | `POST /exec`, the app terminal (local PTY on `/terminal/ws` without SSH credentials), running custom commands, the panel's machine pages (`POST /power`; `GET`/`POST /process` — reading the table too, since a command line is where an argument-borne secret shows; `GET`/`POST /services`; `GET`/`PUT /cron`; `GET`/`POST /containers`; `GET`/`POST`/`DELETE /benchmark`; `GET`/`POST /system-users`; `GET`/`PUT /snippets` and `POST /snippets/plan` — reading the library too, since a script can carry a password — #1623) | — |
| `files` | `/fs/*` | `mode`: `"read"` \| `"write"` (read = list, stat, read, roots; write adds write, mkdir, rename, chmod, remove) |
| `connect` | `/stream/ws` `open` (local/dynamic forwards, RDP/VNC); the panel's RDP sessions, `/rdp/ws` (same `allow` list; the ticket rides in the RDCleanPath request); the panel's desktop routes, `GET`/`PUT /desktops` (#1623) | `allow`: list of `"<ip or cidr>"` or `"<ip or cidr>:<port or lo-hi>"`; empty = anywhere. A host name in a request is resolved by the agent and *every* resolved address must match. IPv6 as `[addr]:port`. |
| `listen` | `/listen/ws` (remote forwards) and `/stream/ws` `accept` | `public`: bool (non-loopback binds); `ports`: `[lo, hi]` or null (any) |
| `ssh_terminal` | The panel's terminal that logs into sshd (`/terminal/ws` with SSH credentials) | — |
| `virt` | The hypervisors and BMCs the agent reaches for the panel (Proxmox VE, libvirt, Redfish): seeing them and controlling them: `GET /bmc`, `GET /bmc/{id}`, `POST /bmc/{id}/power`, `POST /virt`, `POST /virt/power`, `/virt/detail`, `/virt/history`, `/virt/console` and its `/virt/console/ws`, `GET /virt/pve`, `POST /virt/pve/tfa` (#1623). Where they are and the credentials to sign in are agent configuration, admin only: `PUT /bmc`, `POST /bmc/probe`, `PUT`/`DELETE /virt/pve`, `POST /virt/pve/cert`. | — |

Admin only, outside the grants: the backups the agent hosts for the app's sync and the panel, `GET /backup` and `GET`/`PUT`/`DELETE /backup/blob` (#1623). A backup holds every server and key the app knows, encrypted or not, and replacing it replaces what every synced device merges next.

Machine-level config stays in `config.toml`: `ssh_addr`, terminal/exec/fs limits, `fs.roots`. A grant is *usable* only when the machine side allows it (e.g. `files` with empty `roots` is `not_configured`).

### Transport
Everything beyond `read` needs TLS or a loopback peer, unless `[remote_access] allow_insecure = true`. The two legacy keys still count, each for what it used to cover and no more (TODO remove): `[remote_access.terminal] allow_insecure` for `shell`, `ssh_terminal`, `connect`, `listen`; `[remote_access.fs] allow_insecure` for `files`. Neither covers `virt`, which is newer than both. (An earlier draft folded them into one, which let an old config that trusted a plaintext link with its files put a shell on it after the upgrade.)

## Roles and accounts

```json
{
  "name": "desktop",
  "admin": false,
  "builtin": false,
  "grants": {
    "shell": false,
    "ssh_terminal": false,
    "files": null,
    "connect": { "allow": ["127.0.0.1:3389"] },
    "listen": null,
    "virt": false
  }
}
```

- `files` / `connect` / `listen`: `null` = not granted; an object = granted with those options. `shell` / `ssh_terminal` / `virt`: bool.
- **`PUT /roles/{name}` keeps a grant the body does not mention.** A client older than a grant (`virt`) sends every grant it knows and leaves the new one out; reading that as "not granted" would take it away on any save from that client. Written out as `false`/`null`, it is taken away. `POST /roles` reads an absent grant as not granted.
- `files` object: `{"mode": "read"|"write"}`; `listen` object: `{"public": bool, "ports": [lo, hi] | null}`.
- `admin: true` = may manage accounts, roles and the agent's configuration. Only the built-in `admin` role has it; it cannot be set on another role.
- Built-in roles: `admin` (admin, grants editable) and `viewer` (no grants, grants editable). Built-ins cannot be renamed or deleted. Role names: `[a-z0-9_-]{1,32}`.
- Every account has exactly one role. The last account with role `admin` cannot be deleted or moved to another role (`409 last_admin`).
- Stored in the database: table `roles (name PK, admin, grants JSON, builtin, created_at, updated_at)`, column `users.role TEXT NOT NULL DEFAULT 'viewer' REFERENCES roles(name)`.

## Who may do what

| Action | Who |
|---|---|
| `read` routes (status, metrics, history, velocity, capabilities, card-order GET, health) | any account, watch token |
| Grant routes (above) | accounts whose role holds the grant |
| `GET /settings`, `PUT /settings`, `GET/PUT /push`, `POST /push/test`, `PUT /card-order`, `PUT /custom-cmds` (GET stays any account: the list is shown to run them), `DELETE /remote-access/full-access` | admin |
| `/users*`, `/roles*` | admin |
| `GET /me`, `PUT /me/password` | any account (not a watch token) |
| `POST /watch-token` | any account; the token is `read` only |

## New endpoints (JSON; errors are `{"error": "<code>", "message": "..."}`)

Codes: `bad_request` 400, `unauthorized` 401, `forbidden` 403 (not admin / no grant), `reauth` 403 (current password missing or wrong), `not_found` 404, `conflict` 409 (exists / in use), `last_admin` 409.

- `GET /api/v1/me` → `{"username": "...", "role": <Role>}`
- `PUT /api/v1/me/password` `{"current_password": "...", "new_password": "..."}` → `204`. New password ≥ 8 chars.
- `GET /api/v1/users` (admin) → `[{"username", "role", "created_at", "last_login"}]` (`role` is the name; times RFC 3339 or null)
- `POST /api/v1/users` (admin) `{"username", "password", "role", "current_password"}` → `201` the user
- `PUT /api/v1/users/{username}` (admin) `{"role"?: "...", "password"?: "...", "current_password"}` → `200` the user
- `DELETE /api/v1/users/{username}` (admin, body `{"current_password"}`) → `204`
- `GET /api/v1/roles` (admin) → `[<Role>]`
- `POST /api/v1/roles` (admin) `{"role": <Role without builtin>, "current_password"}` → `201`
- `PUT /api/v1/roles/{name}` (admin) `{"role": <Role>, "current_password"}` → `200` (name and `admin` immutable)
- `DELETE /api/v1/roles/{name}` (admin, body `{"current_password"}`) → `204`; `409 conflict` if any account uses it; built-ins `403`.

`current_password` is the *calling admin's* password (re-authentication for anything that changes access).

Every mutation is audited (`Kind::Admin`; detail names the account/role and what changed — never a password).

## Capabilities

`GET /api/v1/capabilities` adds, for the caller:

```json
"me": { "username": "alice", "role": "desktop", "admin": false },
"grants": {
  "shell":        { "ok": false, "why": "not_granted" },
  "ssh_terminal": { "ok": false, "why": "not_granted" },
  "files":        { "ok": true,  "mode": "read" },
  "connect":      { "ok": true,  "allow": ["127.0.0.1:3389"] },
  "listen":       { "ok": false, "why": "insecure_transport", "public": false, "ports": null },
  "virt":         { "ok": false, "why": "not_granted" }
}
```

`why` (only when `ok` is false): `not_granted`, `insecure_transport`, `not_configured`. For a watch token `me` is absent and every grant is `not_granted`.

`features` lists the machine-management endpoints the agent serves (`["power", ...]`, `api::machine::FEATURES`), for any caller; absent on an agent that serves none. A client offers a page when its name is there and the grant it needs is `ok`.

The old `remote_access` object stays, derived for the caller (TODO remove): `terminal` = `ssh_terminal.ok || shell.ok`, `full_access` = `shell.ok`, `files` = `files.ok`, `stream` = `connect.ok`, `listen` = `listen.ok`.

## Live sessions

When a role or an account changes, sessions of the affected accounts that relied on a grant they no longer hold end, with the same close the current revocation sends (`{"type":"error","code":"permission_revoked"}` then close; `full_access_disabled` stays as the code for the legacy endpoint). One broadcast `grants_changed` carrying the affected usernames; each long-lived session re-checks its own subject.

## Bootstrap and migration

- Migration `010_*`: `roles` table, `users.role`, `watch_tokens.scope TEXT NOT NULL DEFAULT 'read'`.
- Migration `011_*`: `virt` on every saved role that holds `shell` and has not said either way. A shell runs as the agent's account, which can read the credentials those pages use, so withholding `virt` from it only hides the pages. A built-in role not decided yet gets it from `Grants::from_legacy` the same way, and a fresh install's `full` includes it.
- At start, if `roles` is empty, create `admin` and `viewer`:
  - **Fresh install** (no users yet): `admin` gets everything (`files` write, `connect` any, `listen` loopback with any port, `shell`, `ssh_terminal`) unless initial permissions are `read`, in which case `admin` holds no grants. Initial permissions come from `--init-permissions full|read` or `SBM_INIT_PERMISSIONS=full|read` (default `full`).
  - **Upgrade** (users exist): `admin`'s grants are what the old switches *effectively* gave: `ssh_terminal` = `terminal.enabled`; `shell` = `connect` = `full_access` resolved as today (platform default, `SBM_FULL_ACCESS`) **and** `terminal.enabled`; `listen` = same as `shell`, `public` = `listen_public`; `files` = `fs.enabled && roots non-empty` ⇒ `write`. Every existing user gets role `admin`.
  - Afterwards `full_access`, `SBM_FULL_ACCESS`, `terminal.enabled`, `fs.enabled`, `listen_public` are not read again; the agent logs once that they moved to roles. Kept parseable (TODO remove).
- `DELETE /api/v1/remote-access/full-access` (admin): clears `shell`, `connect`, `listen` on every role (the panel's first-use notice uses it).

## Installer

`install.sh --permissions full|read` (default `full`) → the service gets `SBM_INIT_PERMISSIONS`; it only matters when the agent creates its first account. Documented in the install section.

## Deviations in the agent implementation

Where the agent differs from the contract above, and why. Everything else is as written.

- **`PUT /custom-cmds` needs an admin whose role also holds a usable `shell`**, not admin alone. A custom command is run by the status script on every extended cycle, so writing one is running code as the agent's account; an admin on a `--permissions read` install must not get a shell by that side door. `GET /custom-cmds` answers `editable` by the same rule.
- **Re-authentication goes through the login throttle**, so it can answer `429` with `{"error":"throttled","message":...}` and a `Retry-After` header. A database or hashing failure there is `500` `{"error":"internal",...}`. Neither code is in the list above.
- **A body of the wrong shape** on the account/role endpoints (`/me/password`, `/users*`, `/roles*`) is `400 bad_request` in this API's shape — including a misspelt grant, which `Grants` refuses rather than dropping. Bodies that are not JSON at all still get the framework's own 400.
- **A DELETE without a body** (`/users/{u}`, `/roles/{r}`) answers `403 reauth`, as a missing `current_password` does.
- **Usernames created through `POST /users`** are 1–64 of `A–Z a–z 0–9 . _ @ -`. Accounts that already exist keep any name.
- **WebSocket refusals**: a frame that needs a grant the account lacks (terminal `open`/`attach`, stream `open`/`accept`, `listen`) answers `{"type":"error","code":"forbidden",...}`. The terminal's SSH-less `open` used to answer `full_access_disabled` there; that code is now only what the legacy endpoint's revocation sends. A `listen` with a port outside `listen.ports` is `not_permitted`, like a public bind without `public`.
- **`connect.allow` and host names**: every address a name resolves to must be allowed, and those resolved addresses are what is dialled. `localhost` usually resolves to both `127.0.0.1` and `::1`, so an allow list naming only one of them refuses `localhost` — a client should send the address it means.
- **`user set-password` (CLI)** gains `--role`. An account it *creates* is a `viewer` unless `--role` says otherwise (it used to get everything every login had) — except on a database with no admin at all, where it becomes the admin and says so. It also takes `--init-permissions`, since on a database nothing has served yet it is what creates the first account.
- **The file API never reaches the agent's own state**, whatever `roots` says and whatever the role, admin included: the database and its `-wal`/`-shm`/`-journal` files, `jwt.secret` and `initial-admin-credentials.txt` beside it, `config.toml` and every `config.toml.*` beside it (backups, the temp file of a save), `.env` (and `.env.*`) in the working directory and the file `dotenvy` actually loaded, the TLS certificate and key, and everything under the custom-commands directory. Each is a way past the roles (`jwt.secret` signs an admin token; a custom command runs as the agent). Matched on canonical paths, so a symlink to one is refused where it resolves; refused with the same 403 as a path outside the roots; left out of listings; and the directories they are in cannot be renamed, removed or chmod-ed. Per file rather than per directory, because the database's directory can be someone's home.
- **A password change ends what the old password paid for** — own (`/me/password`), an admin's reset (`PUT /users/{u}`), or the CLI: `users.password_changed_ms` (Unix ms, set on creation too) moves strictly forward; panel tokens with `iat` before it (to the second — a token from the same second still counts, so signing in again right after works) are 401 everywhere, which also stops a deleted account's tokens working for a new account of the same name; the account's watch tokens are deleted; and in a running agent its terminal sessions, outstanding tickets, relays and listeners are ended (`permission_revoked`). A CLI reset cannot reach a running agent's live connections; they end when the agent restarts, or at the next role or account change, whose sweep also closes every terminal session opened under an older password (each session stores the `since` it was opened under).
- **A fresh install with an old-model `config.toml`** — one that sets any of `full_access`, `listen_public`, `terminal.enabled`, `fs.enabled` (any value), or `SBM_FULL_ACCESS=false` — gives the admin role the intersection of `--init-permissions` and what those switches allowed, rather than ignoring them. A declarative config that said no shell, mounted over a new database, does not come up with one.
- **The last-admin rule is part of the write**: the delete and the role change are single conditional statements, so two concurrent requests cannot each remove one of the last two admins.
- **Read routes now also accept a watch token**: `GET /capabilities`, `GET /card-order`, `GET /velocity`, `GET /velocity/history` (as the table above lists them). They used to need a panel JWT.
- **The legacy `DELETE /remote-access/full-access`** no longer writes `config.toml`; it edits the roles.
