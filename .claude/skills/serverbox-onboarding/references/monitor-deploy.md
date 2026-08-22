# Deploying and configuring the monitor agent

ServerBox Monitor is a small Rust service installed on a server. The app talks
to it over HTTP, which makes it a second way to reach that machine, and it is
the only way to get anything that has to work while the app is closed.

Authoritative sources, in this order: `monitor/config.example.toml` (every key,
with the comment explaining it), `monitor/README.md`,
`docs/src/content/docs/advanced/monitor-agent.md`, `monitor/CLAUDE.md` for the
implementation.

## When it is the right answer

| | SSH | Monitor agent |
|---|---|---|
| Install anything on the server | no | yes |
| Status and charts | yes | yes |
| History from before the app connected | no | yes |
| Terminal, commands, file browsing | yes | only what the operator enables |
| SFTP transfers, port forwarding | yes | **no** |
| Push alerts, home widgets, watch app | no | yes |

Use SSH unless there is a reason not to. Reach for the agent when the SSH port
is not reachable from where the phone is, when charts should already be filled
in on open, or when alerts need to arrive with the app closed. Both at once is
fine — a server added over SSH and an agent on the same machine feeding the
widgets are independent records.

## Install

```sh
# systemd: a `systemctl --user` service, running as your own account
./install.sh install

# OpenRC (Alpine): needs root to write /etc/init.d, but still runs the agent
# as the account you sudo'd from
sudo ./install.sh install

# Either init system, root-owned service
sudo ./install.sh install --system

# Offline, or before a release exists for this build
SBM_INSTALL_PKG=/path/to/server-box-monitor ./install.sh install
```

`install.sh install` fetches the newest `monitor-v*` release of the monorepo.
Those releases are cut by a `workflow_dispatch`-only workflow, so there may be
no current one; `SBM_INSTALL_PKG` with a locally built package and Docker are
the alternatives. `uninstall` and `upgrade` are the other subcommands.

**It installs a user service on purpose.** With `full_access` on — the default
on Linux — a panel login opens a shell as whoever the agent runs as. As root
that is the whole machine.

Docker is `monitor/Dockerfile` and `monitor/docker-compose.yaml`: port 3770,
`./data` and `./config` mounted, and a read-only bind of `/etc/hostname` so the
agent reports the host's name rather than the container's random one.

Building it by hand:

```sh
cd monitor
cargo build --release
cd frontend && npm run build     # the panel; the agent serves it if frontend/dist exists
./target/release/server_box_monitor serve
```

## Configuration

`config.toml` sits next to the binary. `cargo run -- config` (or the binary's
`config` subcommand) prints the resolved values, which is the fastest way to
tell whether a key is being read at all. The agent listens on `0.0.0.0:3770`.

Environment variables override the file: `SBM_HOST`, `SBM_PORT`,
`SBM_TLS_CERT`, `SBM_TLS_KEY`, `SBM_FULL_ACCESS`, `SBM_CORS_ORIGINS`,
`SBM_HOSTNAME`, `DATABASE_URL`, `JWT_SECRET`, `RUST_LOG`. `JWT_SECRET` can be
omitted — one is generated on first start and persisted next to the database at
mode 0600.

Sections are grouped by what they act on, not by a name prefix:
`[server]`, `[server.tls]`, `[monitoring]`, `[monitoring.extended]`,
`[monitoring.extended.idle_pause]`, `[monitoring.data_retention]`,
`[[monitoring.rules]]`, `[[push]]`, `[remote_access]`,
`[remote_access.terminal]`, `[remote_access.fs]`. Where a key lives is a claim
about its scope: `allow_insecure` sits under `terminal` because the terminal is
the only endpoint it gates.

**A config file written before August 2026 has its flat keys ignored
entirely** (`fs_enabled`, `terminal_enabled`, `idle_pause_enabled`, ...). serde
skips unknown keys, so the file parses and every switch in it silently reverts
to off. That is deliberate — the safe direction is "disabled" — but it means an
upgraded agent can go quiet without erroring. Rewrite the file against
`config.example.toml`.

## What each switch grants

The agent reports what it accepts on `GET /api/v1/capabilities` and the app
offers exactly that, so a missing button in the app is a configuration answer
rather than a bug. None of these can be widened from the panel.

**Status, charts and stored history** need nothing beyond the panel login.

**`full_access`** lets a panel login reach the machine directly: a shell, a
command, a connection out, all as the account the agent runs as, with no sshd
involved and therefore none of sshd's authentication, logging or second factor.
It backs the app's process list, systemd units, containers, snippets, power
controls and terminal. Unset follows the platform — on for Linux, off for macOS
and Windows. The panel's first-run prompt can turn it off and has no way to
turn it on; `DELETE /api/v1/remote-access/full-access` is likewise one-way.

**`full_access` on its own grants the app nothing, and this is what a fresh
install trips over.** What the agent reports is
`terminal.available(secure) && full_access`, and `[remote_access.terminal]
enabled` defaults to **false** — so an agent that was installed and never
configured reports `full_access: false` however Linux's own default reads, and
the app shows charts with none of the buttons. The transport half of that
expression is evaluated per request, so the same agent can answer `true` to a
`curl` from loopback and `false` to the phone reaching it over plaintext HTTP
on the LAN. Diagnose it against the address the app actually uses.

It is one switch rather than one per feature because there is only one decision
in it: anyone who can open a shell can run anything in that shell, so granting
the terminal while withholding commands withholds nothing.

**Your panel password is then worth a shell on that machine.** Run the agent as
an ordinary account, or turn this off.

**`[remote_access.fs]`** serves the app's file browser, confined to the
directories in `roots`. It has its own switch because `full_access` means "a
shell" and this means "these directories" — folding them together would make
the narrower feature cost the wider permission. `roots` has no default. Every
request is resolved to a canonical path first, symlinks followed and `..`
refused, then checked against the roots, so a link inside a root pointing at
`/etc` is a refusal rather than a way out. A path outside the roots reports as
absent, so the endpoint cannot be used to map the filesystem one status code at
a time. `roots = ["/"]` is equivalent to a shell — anyone who can write
`~/.ssh/authorized_keys` has one — and the agent warns about it at startup.

**`[remote_access.terminal]`** enables the terminal endpoint used by both the
app and the panel. The panel's session makes the agent an SSH *client* to
`ssh_addr`, so it carries the privileges of the SSH account the browser signs
in as; the app's passwordless session uses a local PTY and needs `full_access`.
Sessions outlive the WebSocket for a few minutes, so a phone changing networks
rejoins the same shell.

**Plaintext is a double opt-in.** The terminal and the file API refuse a
plaintext listener, because the terminal's first message carries an SSH
password and the file API carries bearer tokens and file contents. Configure
TLS (`[server.tls]`) or put a reverse proxy on the same host — loopback counts
as secure. On a network that is already encrypted outside HTTP (Tailscale and
similar) the operator may set `allow_insecure = true` on the section, *and* the
app must enable **Allow insecure HTTP** for that individual connection. Both
are required, deliberately.

## Adding it in the app

1. Tap **+** to add a server
2. Switch the selector at the top of the form from **SSH** to **Monitor HTTP**
3. Fill in the URL (e.g. `https://1.2.3.4:3770`), the panel user and password,
   and **Monitor Ignore certificate** only for a self-signed certificate

Such a server carries **no SSH credentials at all**, and there is nothing to
fall back to. That is the point: the app has been given no way into the machine
beyond what the agent allows.

SFTP and port forwarding are not offered, because the agent has no endpoint
that relays a connection to an address the app names. File *browsing* is a
different mechanism — the file API moves contents through the agent. Add the
server over SSH if the transfers or the tunnels are what you need.

## Widgets, push and the watch

These read the agent directly, with the app closed.

- Home screen widgets take a URL ending in `/status`
  (`docs/src/content/docs/advanced/widgets.md`)
- The watch app reads the agent itself, so it can only show servers that have one
- Push alerts are configured on the agent, in `[[monitoring.rules]]` and `[[push]]`

## Troubleshooting

| Symptom | Where to look |
|---|---|
| Buttons missing on the server page | The app is showing what the agent reported. Commands and the terminal need `full_access` **and** `[remote_access.terminal] enabled` **and** secure transport, all three; the second defaults to false, so this is the usual answer on a fresh install. Files need `[remote_access.fs]` plus `roots`. The agent re-reads its config on restart |
| Certificate errors | Configure TLS, front it with a reverse proxy, or enable **Monitor Ignore certificate** for that server |
| Panel hosted on another origin cannot reach the agent | `cors_allowed_origins` in `config.toml`, or `SBM_CORS_ORIGINS` (comma-separated) |
| Switches turned themselves off after an upgrade | A pre-August-2026 flat config; its keys are not read |
| Terminal refuses to start | Plaintext transport without the double opt-in, or `[remote_access.terminal] enabled = false` |
| Host key changed and the terminal refuses | The agent pins the sshd's key on first use. Clearing it is deliberate: delete the row from `ssh_known_hosts` |
| Nothing at all | Check the process and the port, then `access_log` in its database — who opened what, from where, whether it worked. It never records a credential |
