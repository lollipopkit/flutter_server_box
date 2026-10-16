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

Why not root: whoever signs in to the agent may do what the account it runs as
may do. `--system` installs it as root, which makes its password a root shell;
use it only when the user asks for that.

There are no roles or per-feature permissions. The old `[remote_access]` keys
(`full_access`, `enabled`, `listen_public`, `[remote_access.fs] roots`) are no
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

The agent has one account, signed in with its password alone — no username,
and not the SSH account. On first start the agent sets a random password,
written to `initial-admin-credentials.txt` beside the database (mode 0600).
Change it and delete the file:

```sh
cd ~/.local/share/server-box-monitor     # or /opt/server-box-monitor
./server_box_monitor password
```

Run it there and as the service's account, or it creates a second, empty
database the service never reads. The command prompts (8 characters at
least), or reads it from `--password-env VAR`; it takes no password argument on
purpose. There is no recovery in the panel — this command is the reset. The app
and the panel can change the password too. A change signs out everything else:
older logins stop working, paired widgets and watches are unpaired, and open
terminals and forwards close (after a command-line reset, only once the agent
restarts). Repeated wrong passwords are throttled up to five
minutes, which can look like an agent that does not answer.

## Adding it in the app

**+** → enable **Monitor HTTP** → URL (`https://1.2.3.4:3770`), **Monitor
Password**, and **Monitor Ignore certificate** only for a
self-signed certificate → save. SSH can be on for the same server as well.

A server with only Monitor HTTP has no SSH credentials: it can do what the
agent's system account can do, and no SFTP at all. A server whose agent leads — the agent
alone, or both with the agent preferred — runs every port forward through the
agent and never falls back to SSH.

The **Monitor** tab (behind **More** until added to the bar) gathers the
agents: **Overview** (version against the newest release, rules firing now,
shortcuts), **Web apps**, **Notifications**, and per server the **Audit log**
(sign-ins with their address, commands, file writes, deployments; HTTPS or
loopback only) and **Sessions & devices** (end a terminal session or a relayed
connection, revoke a watch or widget token, forget a signed-in device).
Forgetting a device does not sign it out: one that keeps the password signs in
again, so changing the password is what keeps a lost device out. A section an
older agent lacks says to update the agent.

## Access

Signing in allows what the system account the agent runs as may do: terminal,
commands, processes, systemd, containers, snippets, power, scheduled tasks,
firewall, files, remote desktop and port forwards. The account the agent is
installed as is the only limit; to narrow it, install the agent as an account
that can reach only that. The file API never serves the agent's own state (its
database, `jwt.secret`, `config.toml`, `.env`, TLS key).

An agent upgraded from one with several accounts keeps the oldest admin's
password; roles and grants are gone.

**Plain HTTP is refused** for everything beyond the charts when the request
comes from another machine; loopback and a reverse proxy on the same host are
fine. Use TLS (`[server.tls]`) or a reverse proxy. On a network already
encrypted underneath (Tailscale and the like), plain HTTP takes both
`[remote_access] allow_insecure = true` **and** **Allow insecure HTTP** for
that server in the app.

Before opening the agent to another machine, tell the user what it allows and
wait for their answer: its password is equivalent to a shell as the agent's
account, with none of SSH's authentication in between.

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
| Only charts, no terminal or controls | The app reaches it over plain HTTP from another machine; use TLS or a same-host proxy |
| No SFTP | Never through the agent; add SSH to the same server |
| No remote desktop or port forwarding, with a terminal | The agent predates the TCP relay; update it |
| Remote forward greyed out, local and dynamic fine | The agent predates the listener; update it |
| A command, file or port is refused by the system | The agent's system account lacks the right; that account is the limit |
| Certificate error | Configure TLS or a proxy, or **Monitor Ignore certificate** for a self-signed one |
| Login refused, or the agent seems slow | Wrong password, throttled (per source address; a device that signed in before is never locked out by failures elsewhere); reset with `server_box_monitor password` |
| Settings turned themselves off after an upgrade | A config from before August 2026 uses old flat keys (`terminal_enabled`...) that are no longer read; rewrite it against [`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml) |
| A web panel on another origin cannot reach it | `cors_allowed_origins` in `config.toml`, or `SBM_CORS_ORIGINS` |
| Nothing answers | Is the process running and the port reachable? Then the `access_log` table in its database: who asked for what, from where, and the result (never a credential) |
