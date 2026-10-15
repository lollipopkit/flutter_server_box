English | [简体中文](README_zh.md)

# ServerBox Monitor

ServerBox Monitor is the server-side agent for
[ServerBox](https://github.com/lollipopkit/flutter_server_box). It records
server metrics, serves the Monitor HTTP API, and can host the web panel.
The configuration format may change between releases, so review
`config.example.toml` after upgrading.


## 🖥️ Screenshots
<table>
  <tr>
    <td>
	    <h5 align="center">iOS push</h5>
    </td>
    <td>
	    <h5 align="center">Webhook push (QQ)</h5>
    </td>
    <td>
	    <h5 align="center">iOS widget</h5>
    </td>
  </tr>
  <tr>
    <td>
	    <img width="107px" src="doc/imgs/ios-push.png">
    </td>
    <td>
	    <img width="307px" src="doc/imgs/webhook.png">
    </td>
    <td>
	    <img width="197px" src="doc/imgs/ios-widget.png">
    </td>
  </tr>
</table>

## Install and run

```sh
# systemd: a `systemctl --user` service, running as your own account
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sh -s -- install

# OpenRC (Alpine): needs root to write /etc/init.d, but still runs the agent
# as the account you sudo'd from
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sudo sh -s -- install

# Either init system, as root
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sudo sh -s -- install --system

# Without a published release to fetch — offline, or an unreleased build
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | SBM_INSTALL_PKG=/path/to/server-box-monitor sh -s -- install
```

Everything after `sh -s --` is passed to the script, so `uninstall` and
`upgrade` go the same way. It is also in this repository, so `./install.sh
install` from this directory does the same job — with this checkout's copy of
the script, which is not necessarily the one on `main` that the commands above
fetch.

`install.sh install` downloads the newest `monitor-v*` release of this
repository. Releases are cut by the `monitor-release.yml` workflow, which is
`workflow_dispatch`-only; when no such release exists, use `SBM_INSTALL_PKG`
with a locally built package, or [Docker](Dockerfile).

`upgrade` without `--user` or `--system` finds the installed form itself and
reruns through `sudo` for a system unit or OpenRC; with none installed it
changes nothing. It replaces the files while the agent runs and restarts it
last, so it can run in a terminal the agent opened (which then closes). The
agent reads its releases itself (`GET /api/v1/update`, every 12 hours, with a
desk notification per newer version); the panel's Settings → Server and the
App's Monitor tab offer the same command
(`sbm_parser::monitor_agent::upgrade_command`) in a terminal.

Configuration lives in `config.toml` beside the binary. Every key, with the
comments explaining it, is in [`config.example.toml`](config.example.toml);
`cargo run -- config` prints the resolved values. The agent listens on
`0.0.0.0:3770` and serves its own panel there when `frontend/dist` is present.

### Signing in

The agent has one account, signed in with its password alone. It lives in the
SQLite database, not in `config.toml` — `jwt_secret` there signs tokens and is
not a password. On the first start the agent sets a random password and writes
it beside the database as `initial-admin-credentials.txt` (0600). Change it and
delete that file:

```sh
cd /opt/server-box-monitor   # or ~/.local/share/server-box-monitor
./server_box_monitor password
```

It prompts twice without echo, and `--password-env VAR` reads the password from
the environment instead; there is no argument form, since a command line reaches
`ps` and the shell history. The app and the panel can change it too. Run it from
the agent's own directory — `config.toml` and the database path are relative to
the working directory, so elsewhere it silently sets a password in a new, empty
database.

### What the ServerBox app needs

A server added to the app as a **monitor** server is reached through this
agent's HTTP API and nowhere else — it carries no SSH credentials. The agent
reports what it serves on `GET /api/v1/capabilities`, and the app offers
exactly that:

| App feature | Endpoint |
|---|---|
| Status, charts, stored history | `/api/v1/metrics*` (a watch token may read these too) |
| Processes, systemd, containers, snippets, power, the app's terminal | `POST /api/v1/exec`, `/api/v1/terminal/ws` |
| File browser | `/api/v1/fs/*` |
| Remote desktop, local and dynamic port forwards | `/api/v1/stream/ws` |
| Remote port forwards | `/api/v1/listen/ws` |
| The panel's remote desktops (VNC, RDP) | `/api/v1/stream/ws`, `/api/v1/rdp/ws` |
| Backup sync to this agent, the panel's backup page | `/api/v1/backup` |

`/api/v1/stream/ws` relays one TCP connection to an address the app names,
dialled from this machine as the agent's account. `/api/v1/listen/ws` is the
other direction: the agent listens on a port here and hands each connection to
the app, which takes it over a `stream` socket.

SFTP is not offered on a monitor server: the agent's file API moves file
contents rather than an SSH byte stream.

## Access

**Whoever signs in may do what the system account the agent runs as may do**:
a shell, its files, connections from this machine, listening on its ports. There
are no roles or per-feature permissions: the account the agent is installed as
is the limit. That is why `install.sh` runs the agent as an ordinary account by
default — a `systemctl --user` service under systemd, or an `/etc/init.d` script
with `command_user` under OpenRC — and `--system` (root) makes signing in a root
shell. The full API contract is
[`docs/dev/monitor-permissions.md`](../docs/dev/monitor-permissions.md).

A terminal (the app's or the panel's) is that same shell on a PTY. Sessions
survive a dropped connection for a few minutes, so a phone changing networks
rejoins the same shell instead of losing it.

Changing the password signs out every other session: tokens issued before it
stop working, paired watches and widgets are unpaired, and open terminals,
relays and listeners are closed.

Upgrading from an agent with several accounts keeps the oldest admin's password
and moves the other accounts' Agent mode tasks, memory and desk themes to it.

Notes:

- Everything beyond reading the numbers needs TLS or a loopback caller — a
  reverse proxy on the same host counts, since loopback traffic can't be read
  off the network. On a trusted private network with transport encryption
  outside HTTP (for example Tailscale), an operator may set
  `[remote_access] allow_insecure = true` (the older `terminal.allow_insecure`
  and `fs.allow_insecure` count as it). The App must separately enable **Allow
  insecure HTTP** for that individual Monitor connection; both opt-ins are
  required. Credentials, terminal traffic and file contents are otherwise sent
  in plaintext, so do not use this for an ordinary LAN or a network you do not
  control.
- The file API never serves the agent's own state: its database, `jwt.secret`,
  `config.toml`, `.env`, TLS key and the like.
- `access_log` records what was opened, from where, and whether it worked. It
  never records a credential.
- Failed logins are throttled per source address and, for a client that has
  not signed in before, on a counter all such clients share. A sign-in hands
  the device a token; a device that sends it is throttled on its own, so
  failures elsewhere cannot lock it out. Changing the password forgets every
  device.

## License
`GPL v3. lollipopkit 2023`
