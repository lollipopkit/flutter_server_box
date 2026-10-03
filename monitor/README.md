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

# An admin account that starts with no grants, to be given them later from
# the app or the panel (the default is --permissions full)
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sh -s -- install --permissions read

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

Configuration lives in `config.toml` beside the binary. Every key, with the
comments explaining it, is in [`config.example.toml`](config.example.toml);
`cargo run -- config` prints the resolved values. The agent listens on
`0.0.0.0:3770` and serves its own panel there when `frontend/dist` is present.

### Signing in

The panel user lives in the SQLite database, not in `config.toml` — `jwt_secret`
there signs tokens and is not a password. On the first start with an empty user
table the agent creates `admin`, in the `admin` role, with a random password and writes it beside the
database as `initial-admin-credentials.txt` (0600). Change the password and
delete that file:

```sh
cd /opt/server-box-monitor   # or ~/.local/share/server-box-monitor
./server_box_monitor user set-password admin
```

It prompts twice without echo, and `--password-env VAR` reads the password from
the environment instead; there is no argument form, since a command line reaches
`ps` and the shell history. The same command creates a user that does not exist
yet, as a `viewer` unless `--role <name>` says otherwise; `--role` also moves an
existing account. Admins can add accounts from the app or the panel too. Run it from the agent's own directory — `config.toml` and the database path
are relative to the working directory, so elsewhere it silently sets a password
in a new, empty database.

### What the ServerBox app needs

A server added to the app as a **monitor** server is reached through this
agent's HTTP API and nowhere else — it carries no SSH credentials. The agent
reports what it will accept on `GET /api/v1/capabilities`, and the app offers
exactly that:

| App feature | Grant |
|---|---|
| Status, charts, stored history | none — any account |
| Processes, systemd, containers, snippets, power, the app's terminal | `shell` (`POST /api/v1/exec`, `/api/v1/terminal/ws`) |
| File browser | `files` (`/api/v1/fs/*`), `read` or `write`, inside `[remote_access.fs] roots` |
| Remote desktop, local and dynamic port forwards | `connect` (`/api/v1/stream/ws`), optionally limited by an `allow` list |
| Remote port forwards | `listen` (`/api/v1/listen/ws`); loopback only unless its `public` option is on |
| The panel's in-browser terminal | `ssh_terminal` |
| The panel's remote desktops (VNC, RDP) | `connect` (`/api/v1/stream/ws`, `/api/v1/rdp/ws`), the same `allow` list |
| The panel's BMCs (Redfish): state and power | `virt` (`/api/v1/bmc`); adding a BMC and its credentials: admin |
| Backup sync to this agent, the panel's backup page | admin (`/api/v1/backup`) |

`/api/v1/stream/ws` relays one TCP connection to an address the app names,
dialled from this machine as the agent's account. `/api/v1/listen/ws` is the
other direction: the agent listens on a port here and hands each connection to
the app, which takes it over a `stream` socket.

SFTP is not offered on a monitor server: the agent's file API moves file
contents rather than an SSH byte stream. An agent older than these endpoints
reports neither, and the app greys out what needs them.

## Accounts and permissions

Every account can read status, charts and history. Everything else is a
**grant**, and an account holds the grants of its **role**. Roles live in the
agent's database, not in `config.toml`, and an admin edits accounts and roles
from the app or the panel, entering their own password again for every change.
A change applies at once: a terminal, relay or listener that relied on a grant
the account lost is closed. The full API contract is
[`docs/dev/monitor-permissions.md`](../docs/dev/monitor-permissions.md).

- **`admin`** (built in) manages accounts, roles and the agent's settings, and
  holds whatever grants it is given. The last admin account cannot be deleted
  or moved to another role. Editing custom commands also needs `shell`, since
  the agent runs them.
- **`viewer`** (built in) holds no grants.
- Admins can add roles, for example one that may only `connect` to
  `127.0.0.1:3389`.

A fresh install's `admin` starts with every grant (`files` write, `connect`
anywhere, `listen` on loopback, `shell`, `ssh_terminal`), or none with
`install.sh --permissions read` — `SBM_INIT_PERMISSIONS=read`, or `serve
--init-permissions read` when running the binary yourself. That choice is read
only when the first account is created.

**`shell` is a shell as the account the agent runs as**, and in practice covers
the other grants: whoever can run commands can read files and open connections
themselves. That is why `install.sh` runs the agent as an ordinary account by
default — a `systemctl --user` service under systemd, or an `/etc/init.d` script
with `command_user` under OpenRC. Grant `files`, `connect` or `listen` on their
own when that is all an account needs.

**`ssh_terminal`** is the panel's in-browser terminal. The agent acts as an SSH
client to `ssh_addr`, so a session has exactly the privileges of the SSH account
the browser signs in as — the panel password alone grants no shell, and sshd's
own logging, `AllowUsers` and two-factor prompts all still apply. Sessions
survive a dropped connection for a few minutes, so a phone changing networks
rejoins the same shell instead of losing it.

**`connect.allow`** takes IP addresses or CIDR ranges with an optional port or
port range (`10.0.0.0/8`, `127.0.0.1:3389`, `[::1]:5900-5910`); empty is
anywhere. A host name is resolved by the agent and every address it resolves to
must be allowed, so `localhost` — usually both `127.0.0.1` and `::1` — needs
both, or the client should send the address. **`listen`** binds loopback only
unless `public` is on (sshd's `GatewayPorts`), and only inside its port range
when one is set.

Upgrading from an agent without roles converts the old switches once: every
existing account becomes an admin, and the `admin` role gets what they actually
granted — `[remote_access.terminal] enabled` becomes `ssh_terminal`;
`full_access` (with its platform default and `SBM_FULL_ACCESS`), counted only
while the terminal was enabled, becomes `shell`, `connect` and `listen`;
`listen_public` becomes `listen.public`; `[remote_access.fs] enabled` with roots
becomes `files` write. The agent then stops reading those keys and logs once
that they can go. The panel's first-run prompt to turn shell access off removes
`shell`, `connect` and `listen` from every role.

Notes:

- Everything beyond reading the numbers needs TLS or a loopback caller — a
  reverse proxy on the same host counts, since loopback traffic can't be read
  off the network. On a trusted private network with transport encryption
  outside HTTP (for example Tailscale), an operator may set
  `[remote_access] allow_insecure = true`. The older keys still count for what
  they used to cover: `terminal.allow_insecure` for shell, terminal, connect and
  listen, `fs.allow_insecure` for files. The App must separately enable **Allow
  insecure HTTP** for that individual Monitor connection; both opt-ins are
  required. Credentials, terminal traffic and file contents are otherwise sent
  in plaintext, so do not use this for an ordinary LAN or a network you do not
  control.
- `files` serves nothing without `[remote_access.fs] roots`. `roots = ["/"]`
  with write access is worth a shell, and the agent warns about it at startup.
- The agent pins the host key of the sshd it connects to on first use and
  refuses a changed one, rather than re-pinning silently. Clearing the pin is
  deliberate: delete the row from `ssh_known_hosts`.
- `access_log` records who opened what, from where, and whether it worked, and
  every change to an account or a role. It never records a credential.
- Failed logins, and wrong passwords when re-authenticating, are throttled per
  source address and per username.

## License
`GPL v3. lollipopkit 2023`
