---
title: Monitor Agent
description: Reach a server through Monitor agent
---

Server Box Monitor is a lightweight monitoring service installed on a server. The App communicates with it over HTTP, so the server can be reached without exposing an SSH port. Monitor agent also powers push alerts, home-screen widgets, and the Watch app when the App is not open.

## SSH or Monitor agent?

| | SSH | Monitor agent |
|---|---|---|
| Requires additional software on the server | No | Yes |
| Status and charts | Yes | Yes |
| History from before the App connected | No | Yes |
| Terminal, commands, and file browsing | Yes | Depends on the features enabled by the operator |
| SFTP transfers and port forwarding | Yes | No |
| Push alerts, home-screen widgets, and Watch app | No | Yes |

SSH is usually the simplest option. Monitor agent is useful when the SSH port is unreachable from the current network, when you want charts to have history before the App connects, or when you want server alerts pushed to a phone.

The two methods can be used together: configure SSH in the App while running Monitor agent on the same server for widgets and the Watch app.

## Install Monitor agent

Download a published `monitor-v*` release when one is available, or build the agent yourself. The release workflow is manually dispatched. For an unreleased version or an offline installation, use a local package with `SBM_INSTALL_PKG`.

The installer detects the init system automatically:

```sh
# systemd: install a `systemctl --user` service running as the current user
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sh -s -- install

# No downloadable release, or an offline installation
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | SBM_INSTALL_PKG=/path/to/server-box-monitor sh -s -- install

# OpenRC (Alpine): writing /etc/init.d needs root, but the agent runs as
# the user who invoked sudo
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sudo sh -s -- install
```

Everything after `sh -s --` is passed to the script, so `uninstall` and
`upgrade` go the same way. It is also in the repository, so
`./monitor/install.sh install` from the root of a checkout does the same job —
with that checkout's copy of the script, which is not necessarily the one on
`main` that the commands above fetch.

The agent runs as an ordinary user by default. This limits the scope of `full_access`; see [Permission switches](#permission-switches).

The configuration file is `config.toml` next to the binary. Every option is documented in [`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml). The agent listens on `0.0.0.0:3770`; when `frontend/dist` exists, it also serves the web panel there.

If the agent must be reachable from another device, use HTTPS: configure built-in TLS with `[server.tls]`, or put the agent behind a reverse proxy. The App supports self-signed certificates when you explicitly enable that option.

## Add it in the App

1. Tap **+** to add a server.
2. Enable **Monitor HTTP**. SSH and Monitor HTTP are independent switches: you can enable either one or both. When both are enabled, use **Preferred transport** to choose which one the App tries first.
3. Enter:
   - **URL**: for example, `https://1.2.3.4:3770`
   - **Monitor User** / **Monitor Password**: the agent's web-panel credentials
   - **Monitor Ignore certificate**: enable only for a self-signed certificate
4. Save the configuration.

A server added through Monitor HTTP contains **no SSH credentials**. The App has no other way to reach the machine beyond the capabilities explicitly provided by the agent.

## Permission switches

The agent reports its current capabilities through `GET /api/v1/capabilities`, and the App shows only those capabilities. The file API and web-panel terminal are disabled by default and can only be enabled by the operator in `config.toml`.

**Status, charts, and stored history** require only panel login credentials.

**`full_access`** gives an authenticated user a shell and command execution as the user running the agent. The App's process, systemd, container, snippet, power-control, and terminal features depend on this grant.

There is one `full_access` switch because anyone who can open a shell can run arbitrary commands in it. Disabling a separate “commands” switch would not reduce that access. It defaults to enabled on Linux and disabled on macOS and Windows. The panel can disable it, but cannot enable it again; re-enabling requires a configuration-file change.

**The panel password is equivalent to shell access as the agent user.** This is why `install.sh` runs the agent as an ordinary user by default. If you run it as root, disable `full_access`.

**`[remote_access.fs]`** provides file browsing, restricted to directories listed in `roots`. It is independent of `full_access`: the file API grants access to selected directories, while `full_access` grants a shell. `roots` has no default; enabling the file API requires naming the directories explicitly.

The agent resolves every request to a real path, follows symlinks, and rejects `..`. The resolved path must remain within `roots`, so a symlink pointing to `/etc` cannot escape the restriction. Setting `roots = ["/"]` is effectively shell access, and the agent warns about it at startup.

Like the terminal, the file API also requires `[remote_access.fs] allow_insecure = true` on a plaintext HTTP connection. Setting only `enabled` and `roots` without TLS leaves the file API unavailable: `GET /api/v1/capabilities` reports that file access is unsupported, so the App hides the entry and the agent logs a warning at startup.

**`[remote_access.terminal]`** enables the terminal endpoint used by both the App and the web panel. The panel terminal connects to `ssh_addr` as an SSH client, with the permissions of that SSH account. The App's passwordless terminal uses the agent user's local shell when `full_access` is enabled. Panel login credentials alone do not grant a shell.

Unless `[remote_access.terminal] allow_insecure = true` is configured, the terminal will not run over plaintext HTTP because the first message may contain an SSH password. TLS or a same-host reverse proxy satisfies the transport requirement. The App must also enable **Allow insecure HTTP** for this individual Monitor connection; both settings are required.

## Unsupported features

A server configured only through Monitor HTTP does not provide SFTP or port forwarding. The agent has no endpoint that relays a connection to an address chosen by the App, so it cannot carry either feature. File **browsing** can use the agent's file API, but that API moves file contents rather than providing an arbitrary TCP byte stream.

If you need SFTP or port forwarding, configure SSH for the same server in the App.

## Widgets, push, and the Watch app

These features read directly from Monitor agent and do not depend on the App being in the foreground:

- **Home-screen widgets**: Configure the server in the App after installing Monitor agent. The widget selects from the server list published by the App; you do not enter a URL manually.
- **Watch app**: It can show only servers with Monitor agent configured. These servers sync by default, and you can exclude individual servers in the iOS settings.
- **Push alerts**: Configure them in the agent with `[[monitoring.rules]]` and `[[push]]`.

## Troubleshooting

**Features are missing from the server page.** The App shows what the agent reports. Commands and the terminal require `full_access` and the terminal endpoint; file browsing requires `[remote_access.fs]` and `roots`. Restart the agent after changing its configuration.

**Certificate errors.** Configure valid TLS, put the agent behind a reverse proxy, or enable **Monitor Ignore certificate** for that server.

**The panel is hosted on another origin.** Add the origin to `cors_allowed_origins` in `config.toml` or to the `SBM_CORS_ORIGINS` environment variable.

**Requests receive no response.** Confirm that the agent is running and the port is reachable, then inspect `access_log` in its database. It records the visitor, time, source, requested resource, and result, but never credentials.
