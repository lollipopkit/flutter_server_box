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

Why not root: with `full_access` on, the panel password is worth a shell as
whoever the agent runs as.

Right after installing, leave everything under `[remote_access]` off and write
`full_access = false` there explicitly. Unset, it follows the platform — on
for Linux — and an explicit `false` cannot be reopened by an environment
variable.

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
panel — this command is the reset. Repeated wrong passwords are throttled up
to five minutes, which can look like an agent that does not answer.

## Adding it in the app

**+** → enable **Monitor HTTP** → URL (`https://1.2.3.4:3770`), **Monitor
User**, **Monitor Password**, and **Monitor Ignore certificate** only for a
self-signed certificate → save. SSH can be on for the same server as well.

A server with only Monitor HTTP has no SSH credentials: it can do exactly what
the agent allows, and no SFTP or port forwarding at all.

## What each switch allows

These are only in `config.toml` — no panel or app control can turn one on (the
panel can turn `full_access` off). Restart the agent after editing; its log
then prints a `Remote access:` line summarising what is on (nothing at all
when everything is off).

| Switch | Allows | Note |
|---|---|---|
| (none) | Status, charts, stored history | Any panel login |
| `full_access` | Terminal, commands, processes, systemd, containers, snippets, power, remote desktop — as the agent's OS account | **Only while `[remote_access.terminal] enabled = true`**, which is off by default: a fresh install offers charts and nothing else |
| `[remote_access.terminal] enabled` | The terminal endpoint, for the app and the web panel | The panel's terminal logs in over SSH with that account's rights |
| `[remote_access.fs] enabled` + `roots` | The file browser, inside the listed directories | `roots` has no default. `roots = ["/"]` is close to a shell: anyone who can write `~/.ssh/authorized_keys` has one |

**Plain HTTP is refused** by the terminal and the file browser for requests
from another machine; loopback and a reverse proxy on the same host are fine.
Use TLS (`[server.tls]`) or a reverse proxy. On a network already encrypted
underneath (Tailscale and the like), plain HTTP takes both
`allow_insecure = true` in that section **and** **Allow insecure HTTP** for
that server in the app.

Before enabling any of these, tell the user what it allows and wait for their
answer. `full_access` makes the panel password equivalent to a shell, with
none of SSH's authentication in between.

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
| Only charts, no terminal or controls | `[remote_access.terminal] enabled` is off (the default), so `full_access` grants nothing; or the app reaches it over plain HTTP from another machine |
| No file browser | `[remote_access.fs]` off, or `roots` empty |
| No SFTP or port forwarding | Never through the agent; add SSH to the same server |
| Certificate error | Configure TLS or a proxy, or **Monitor Ignore certificate** for a self-signed one |
| Login refused, or the agent seems slow | Wrong password, throttled; reset with `user set-password` |
| Settings turned themselves off after an upgrade | A config from before August 2026 uses old flat keys (`terminal_enabled`...) that are no longer read; rewrite it against [`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml) |
| A web panel on another origin cannot reach it | `cors_allowed_origins` in `config.toml`, or `SBM_CORS_ORIGINS` |
| Nothing answers | Is the process running and the port reachable? Then the `access_log` table in its database: who asked for what, from where, and the result (never a credential) |
