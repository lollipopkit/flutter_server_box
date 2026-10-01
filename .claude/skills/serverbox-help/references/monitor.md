# The ServerBox Monitor agent

A small service installed on a server. The app reaches it over HTTP, as a
second way into that machine besides SSH, and it is what keeps alerts, widgets
and the watch app working while the app is closed. The full page, with
ready-made prompts for each task below:
<https://serverbox.lollipopkit.com/docs/advanced/monitor-agent/>.

## Installing it

Over SSH, as the user's **ordinary account** — never as root:

```sh
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sh -s -- install
```

- systemd hosts get a `systemctl --user` service running as that account.
- Alpine (OpenRC) needs `| sudo sh -s -- install` to write `/etc/init.d`; the
  agent still runs as the account that ran sudo.
- `uninstall` and `upgrade` go in place of `install`.
- A user service stops at logout unless linger is on:
  `loginctl show-user <user> -p Linger`, and `loginctl enable-linger <user>`
  to turn it on (ask first).
- It listens on `0.0.0.0:3770`. Its working directory is
  `~/.local/share/server-box-monitor` (`/opt/server-box-monitor` for a root
  service); `config.toml` and the SQLite database are there, and neither
  should be readable by group or others.

Why not root: an account whose role holds `shell` runs commands as whoever the
agent runs as.

`--permissions read` (`sh -s -- install --permissions read`) makes the first
`admin` account start with no grants; the default, `full`, gives it every grant.
It only matters on a fresh install. Prefer `read` unless the user asked for
more, then turn on what they need from the app or the panel. The old
`[remote_access]` switches (`full_access`, `enabled`, `listen_public`) are no
longer read; do not add them.

### In Docker

[`monitor/docker-compose.yaml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/docker-compose.yaml)
publishes port 3770, keeps `./data` and `./config`, and mounts the host's
`/etc/hostname` read-only so the agent reports the machine's name rather than
the container's.

Environment variables override `config.toml`: `SBM_HOST`, `SBM_PORT`,
`SBM_TLS_CERT`, `SBM_TLS_KEY`, `SBM_CORS_ORIGINS`, `DATABASE_URL`,
`JWT_SECRET` (generated and kept beside the database when unset).

### The panel login

The app signs in with a panel user, not the SSH account. On first start the
agent creates `admin` with a random password, written to
`initial-admin-credentials.txt` beside the database (mode 0600). Change it and
delete the file:

```sh
cd ~/.local/share/server-box-monitor     # or /opt/server-box-monitor
./server_box_monitor user set-password admin
```

Run it there and as the service's account, or it creates a second, empty
database the service never reads. The command prompts (8 characters at
least); it takes no password argument on purpose. There is no recovery in the
panel — this command is the reset. A user it creates is a `viewer` unless
`--role admin` (or another role) is added; an admin can also add accounts from
the app or the panel. Repeated wrong passwords are throttled up to five
minutes, which can look like an agent that does not answer.

## Adding it in the app

**+** → enable **Monitor HTTP** → URL (`https://1.2.3.4:3770`), **Monitor
User**, **Monitor Password**, and **Monitor Ignore certificate** only for a
self-signed certificate → save. SSH can be on for the same server as well.

A server with only Monitor HTTP has no SSH credentials: it can do exactly what
the agent allows, and no SFTP at all. A server whose agent leads — the agent
alone, or both with the agent preferred — runs every port forward through the
agent and never falls back to SSH.

## Accounts, roles and grants

Each account on the agent has a role, and a role holds grants. Roles live in
the agent's database, not in `config.toml`; an **admin** account edits accounts
and roles from the app (server page → settings button → **Access** →
**Accounts** / **Roles**) or the web panel (end of **Server Settings**),
entering its own password again for each change. Changes apply at once and
close sessions that lost their grant. Any account can see its role and change
its own password there.

| Grant | Allows | Options |
|---|---|---|
| (none) | Status, charts, stored history | Any account |
| `shell` | Terminal, commands, processes, systemd, containers, snippets, power, scheduled tasks, firewall — as the agent's OS account | Covers the rest in practice |
| `ssh_terminal` | The web panel's terminal, which logs in over SSH with that SSH account's rights | — |
| `files` | The file browser, inside `[remote_access.fs] roots` | `read` or `write`. `roots` has no default and is set in `config.toml`. `roots = ["/"]` with write is close to a shell |
| `connect` | Remote desktop, local and dynamic port forwards | `allow`: IPs or CIDRs with optional ports; empty is anywhere |
| `listen` | Remote port forwards | `public` for non-loopback addresses; a port range |

Built-in roles: `admin` (also manages accounts, roles and the agent's settings
— only an admin can change settings, alert rules and channels) and `viewer`
(no grants). The last admin cannot be removed or demoted.

An agent upgraded from before roles turns its old switches into the `admin`
role once, and every existing account becomes an admin.

**Plain HTTP is refused** for everything beyond the charts when the request
comes from another machine; loopback and a reverse proxy on the same host are
fine. Use TLS (`[server.tls]`) or a reverse proxy. On a network already
encrypted underneath (Tailscale and the like), plain HTTP takes both
`[remote_access] allow_insecure = true` **and** **Allow insecure HTTP** for
that server in the app.

Before granting any of these, tell the user what it allows and wait for their
answer. A role with `shell` makes its accounts' passwords equivalent to a shell,
with none of SSH's authentication in between.

## Alerts, widgets, the watch

- **Push alerts**: a rule says when, a channel says where — `[[monitoring.rules]]`
  and `[[push]]` in `config.toml`, or the same lists in the app (the settings
  button in the server page's top bar) and in the web panel, where a channel
  has **Send a test**. Rule changes take effect after a restart.
- **Rules**: `name`, `monitor_type` (cpu, memory, swap, disk, network,
  temperature), `matcher` and `threshold`.
  - `threshold` is a comparator, value and unit: `>=80%`, `<10%`, `>10m/s`,
    `>=70c`. **With no comparator it means `<`**, so `80%` is "below 80
    percent".
  - The unit must fit the metric (`%` for cpu/memory/swap/disk, `c` for
    temperature, a size or size `/s` for network; sizes base 1024, lowercase).
  - `matcher` picks a part of the metric — `cpu0`, `used`/`free`/`avail`,
    `rx`/`tx` — and is **not** an interface name or a mount point:
    `matcher = "eth0"` silently measures all traffic.
  - A malformed rule is logged and never fires. Network rules need two samples
    before the first evaluation; a machine without a temperature sensor never
    fires a temperature rule.
- **Home-screen widgets**: add the server with Monitor HTTP in the app, then
  pick it in the widget; no URL is typed into the widget.
  <https://serverbox.lollipopkit.com/docs/advanced/widgets/>
- **Watch app**: shows only servers that have the agent configured.

## When something is wrong

| Symptom | Cause |
|---|---|
| Only charts, no terminal or controls | The account's role has no `shell` (an admin grants it; a `--permissions read` install starts with none); or the app reaches it over plain HTTP from another machine |
| No file browser | The role has no `files`, or `[remote_access.fs] roots` is empty |
| Files can be browsed but not changed | The role's `files` is read-only |
| No SFTP | Never through the agent; add SSH to the same server |
| No remote desktop or port forwarding, with a terminal | The agent predates the TCP relay; update it |
| Remote forward greyed out, local and dynamic fine | The agent predates the listener; update it |
| Remote forward refuses an address that is not loopback | Turn on `public` in the role's `listen` |
| Remote desktop or a forward to one address is refused | The role's `connect.allow` does not include it; `localhost` needs both `127.0.0.1` and `::1`, so enter the address |
| Settings, alert rules or channels cannot be changed | Only an admin account can; sign in with one or ask an admin to change your role |
| Certificate error | Configure TLS or a proxy, or **Monitor Ignore certificate** for a self-signed one |
| Login refused, or the agent seems slow | Wrong password, throttled; reset with `user set-password` |
| Settings turned themselves off after an upgrade | A config from before August 2026 uses old flat keys (`terminal_enabled`...) that are no longer read; rewrite it against [`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml) |
| A web panel on another origin cannot reach it | `cors_allowed_origins` in `config.toml`, or `SBM_CORS_ORIGINS` |
| Nothing answers | Is the process running and the port reachable? Then the `access_log` table in its database: who asked for what, from where, and the result (never a credential) |
