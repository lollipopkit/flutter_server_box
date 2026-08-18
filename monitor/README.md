English | [简体中文](README_zh.md)

## ServerBox Monitor
This app runs on server end and monitors the server status.  
It is a part of [ServerBox](https://github.com/lollipopkit/flutter_server_box) project.  
**It's under active development, you may need to reconfig it after upgrading.**


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

## 📖 Usage

```sh
# systemd: a `systemctl --user` service, running as your own account
./install.sh install

# OpenRC (Alpine): needs root to write /etc/init.d, but still runs the agent
# as the account you sudo'd from
sudo ./install.sh install

# Either init system, as root
sudo ./install.sh install --system

# Without a published release to fetch — offline, or an unreleased build
SBM_INSTALL_PKG=/path/to/server-box-monitor ./install.sh install
```

`install.sh install` downloads the newest `monitor-v*` release of this
repository. Releases are cut by the `monitor-release.yml` workflow, which is
`workflow_dispatch`-only; when no such release exists, use `SBM_INSTALL_PKG`
with a locally built package, or [Docker](Dockerfile).

Configuration lives in `config.toml` beside the binary. Every key, with the
comments explaining it, is in [`config.example.toml`](config.example.toml);
`cargo run -- config` prints the resolved values. The agent listens on
`0.0.0.0:3770` and serves its own panel there when `frontend/dist` is present.

### What the ServerBox app needs

A server added to the app as a **monitor** server is reached through this
agent's HTTP API and nowhere else — it carries no SSH credentials. The agent
reports what it will accept on `GET /api/v1/capabilities`, and the app offers
exactly that:

| App feature | Requires |
|---|---|
| Status, charts, stored history | nothing beyond the login |
| Processes, systemd, containers, snippets, power | `full_access` (`POST /api/v1/exec`) |
| Terminal | `full_access` (`/api/v1/terminal/ws`) |
| File browser | `[remote_access.fs] enabled` + `roots` |

SFTP and port forwarding are not offered on a monitor server: the agent has no
endpoint that relays a connection to an address the app names. Add the server
over SSH if you need them.

## 🔐 Remote access (optional, off by default)

Two WebSocket endpoints can reach this machine's SSH service. Both are
disabled until you turn them on in `config.toml`, and neither can be enabled
from the panel — see `[remote_access]` in `config.example.toml`.

**`[remote_access.tunnel] enabled`** relays an SSH byte stream to `ssh_addr`.
The agent only moves bytes — the SSH session is negotiated end to end between
client and sshd, and this process could not read it even if it tried. There is
no target parameter: the agent connects to `ssh_addr` and nothing else, which
is what stops it being usable to reach other hosts on its network.

TODO: **nothing consumes this endpoint today.** The ServerBox app used to reach
sshd through it; it now reaches a monitor server through `/api/v1/exec`,
`/api/v1/terminal/ws` and `/api/v1/fs/*` instead, and has no tunnel client
left. Turning the switch on currently has no effect. Remove the endpoint, or
restore a consumer.

**`[remote_access.terminal] enabled`** adds an in-browser terminal to the panel. The agent acts
as an SSH client to `ssh_addr`, so a session has exactly the privileges of the
SSH account the browser signs in as — the panel password alone grants no shell,
and sshd's own logging, `AllowUsers` and two-factor prompts all still apply.
Sessions survive a dropped connection for a few minutes, so a phone changing
networks rejoins the same shell instead of losing it.

**`full_access`** removes the SSH login step: anyone signed into the panel can
open a shell, run a command and reach any address this machine can reach, all
as the account the agent runs as. Unset follows the platform — on for Linux,
off for macOS and Windows. **Your panel password then buys the machine**, which
is why `install.sh` runs the agent as an ordinary account by default — a
`systemctl --user` service under systemd, or an `/etc/init.d` script with
`command_user` under OpenRC. If you run the agent as root, turn this off. The
SSH login stays available alongside it.
Also settable with `SBM_FULL_ACCESS=0/1`, and the panel's first-run prompt can
turn it off — never on.

It is one switch rather than one per feature because there is only one decision
in it: anyone who can open a shell can run anything in that shell and connect
anywhere from it, so granting the terminal and withholding the rest withholds
nothing.

Notes:

- The terminal refuses to run on a plaintext listener, because its first
  message carries an SSH password. TLS satisfies this; so does a reverse proxy
  on the same host, since loopback traffic can't be read off the network.
  `[remote_access.terminal] allow_insecure = true` overrides it. The tunnel is unaffected — what it
  carries is already encrypted.
- The agent pins the host key of the sshd it connects to on first use and
  refuses a changed one, rather than re-pinning silently. Clearing the pin is
  deliberate: delete the row from `ssh_known_hosts`.
- `access_log` records who opened what, from where, and whether it worked. It
  never records a credential.
- Failed logins are throttled per source address and per username.

## 🔖 License
`GPL v3. lollipopkit 2023`