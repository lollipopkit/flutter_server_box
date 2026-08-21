---
title: Monitor Agent
description: Reach a server through an agent instead of SSH
---

ServerBox Monitor is a small service you install on a server. The app talks to
it over HTTP, which makes it a second way to reach that server. It is also the
only way to get push alerts, home screen widgets and the watch app, all of which have
to work while the app is closed.

## When to use it

| | SSH | Monitor agent |
|---|---|---|
| Install anything on the server | no | yes |
| Status and charts | yes | yes |
| History from before the app connected | no | yes |
| Terminal, commands, file browsing | yes | only what the agent's operator enables |
| SFTP transfers, port forwarding | yes | no |
| Push alerts, widgets, watch app | no | yes |

Use SSH unless you have a reason not to. Reach for the agent when the SSH port
is not reachable from where you are, when you want charts that are already
filled in when you open the app, or when you want alerts pushed to your phone.

Nothing stops you from doing both: a server added over SSH and an agent on the
same machine feeding the widgets are independent.

## Install the agent

Download from a published `monitor-v*` release when one exists, or build it. The
release workflow is manually dispatched, so an unreleased or offline install
should use `SBM_INSTALL_PKG` with a local package. The installer picks the init
system for you:

```sh
# systemd: a `systemctl --user` service, running as your own account
./install.sh install

# Offline or without a published monitor-v* release
SBM_INSTALL_PKG=/path/to/server-box-monitor ./install.sh install

# OpenRC (Alpine): needs root to write /etc/init.d, but still runs the agent
# as the account you sudo'd from
sudo ./install.sh install
```

It runs as an ordinary account by default. See
[What each switch grants](#what-each-switch-grants).

Configuration is `config.toml` next to the binary. Every key is documented in
[`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml).
The agent listens on `0.0.0.0:3770` and serves its own web panel there.

Use HTTPS if the agent is reachable from anywhere but your own machine: either
the built-in TLS (`[server.tls]`) or a reverse proxy. The app will accept a
self-signed certificate, but only because you tell it to.

## Add the server in the app

1. Tap **+** to add a server
2. Switch the selector at the top of the form from **SSH** to **Monitor HTTP**
3. Fill in:
    - **URL**: e.g. `https://1.2.3.4:3770`
    - **Monitor User** / **Monitor Password**: the agent's panel login
    - **Monitor Ignore certificate**: only for a self-signed certificate

A server added this way carries **no SSH credentials at all**. There is nothing
for the app to fall back to, which is the point: you have not given it a way
into the machine beyond what the agent allows.

## What each switch grants

The agent tells the app what it will accept, and the app offers exactly that.
It does not show buttons that would answer 403. The file API and the agent-panel
terminal are off unless the operator turns them on in `config.toml`.
`full_access` defaults on only on Linux, but it is effective for app
shell/command access only when `[remote_access.terminal] enabled = true` and the
request uses secure transport or the terminal's explicit `allow_insecure`
opt-in. None of these permissions can be widened from the web panel.

**Status, charts and stored history** need nothing beyond the login.

**`full_access`** lets a panel login reach the machine directly: a shell, a
command, as the account the agent runs as. This is what the app's process list,
systemd units, containers, snippets, power controls and terminal all depend on.

It is one switch rather than one per feature because there is only one decision
in it. Anyone who can open a shell can run anything in that shell, so granting
the terminal and withholding commands withholds nothing.

**Your panel password is then worth a shell on that machine.** That is why
`install.sh` runs the agent as an ordinary account rather than root. If you do
run it as root, turn `full_access` off. It defaults on for Linux and off for
macOS and Windows. The panel can turn it off but never on.

**`[remote_access.fs]`** serves the file browser, confined to the directories
named in `roots`. It has its own switch rather than riding on `full_access`,
because that grant means "a shell" and this one means "these directories".
Folding them together would give the narrower feature the wider permission.

`roots` has no default. Every request is resolved to a real path. Symlinks are
followed, `..` is refused, and anything landing outside the roots is denied, so a
link inside a root pointing at `/etc` is not a way out. `roots = ["/"]` makes
this equivalent to a shell, since anyone who can write `~/.ssh/authorized_keys`
has one; the agent warns about it at startup.

**`[remote_access.terminal]`** enables the terminal endpoint used by both the app
and the agent's own web panel. The panel's SSH-backed session acts as an SSH
client to its configured `ssh_addr`, while the app's passwordless session uses
the agent's local shell when `full_access` is granted. The panel password alone
grants no shell unless `full_access` is on.

It refuses to run on a plaintext listener unless
`[remote_access.terminal] allow_insecure = true`; TLS satisfies the transport
requirement, and so does a reverse proxy on the same host.

## What you do not get

**SFTP and port forwarding are not offered on a monitor server.** The agent has
no endpoint that relays a connection to an address the app names, so there is
nothing to carry them. File *browsing* works through the agent's own file API,
which is a different thing: it moves file contents through the agent rather
than opening a stream to somewhere.

If you need SFTP or port forwarding on that machine, add it over SSH.

## Widgets, push and the watch

These read the agent directly and do not involve the app being open.

- **Home screen widgets** take a URL ending in `/status`. See
  [Home Screen Widgets](/docs/advanced/widgets/)
- **The watch app** reads from the agent by itself, so it can only show servers
  that have one configured
- **Push alerts** are configured on the agent, in `[[monitoring.rules]]` and
  `[[push]]`

## Troubleshooting

**Buttons missing on the server page.** The app is showing what the agent said
it allows. Check `full_access` for commands and the terminal, and
`[remote_access.fs]` plus its `roots` for files. The agent re-reads its config
on restart.

**Certificate errors.** Either configure real TLS, put the agent behind a
reverse proxy, or turn on **Monitor Ignore certificate** for that server.

**The panel is on another origin.** An agent must allow it explicitly:
`cors_allowed_origins` in `config.toml`, or `SBM_CORS_ORIGINS`.

**Nothing at all.** Check the agent is running and the port is reachable, then
`access_log` in its database. It records who opened what, from where, and
whether it worked, and never records a credential.
