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

Part of that file can be edited without opening it. Collection intervals, alert rules, notification channels, data retention and the allowed panel origins are editable from the web panel's **Server Settings** page, and from the App: open a server that has an agent and use the settings button in its top bar. Both reach the same agent and write the same file. What is not editable this way is deliberate: the JWT secret, `database_url` and the `[remote_access]` switches stay in the file, so a panel password can never widen what the agent exposes.

Keys and tokens already in the file — a ServerChan key, a Bark key, an iOS push token, an `Authorization` header — are never sent back to an editor. They show as *set* with an empty box; leaving it empty keeps the stored value, and typing into it replaces it. A saved notification channel reaches the agent's rule engine only when it next starts, and so do alert rules, the collection interval, data retention and the allowed origins. Only the extended cycle interval and the two idle-pause settings apply at once. The App marks the fields that need a restart.

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
- **Push alerts**: A rule decides when to alert and a channel decides where it goes — `[[monitoring.rules]]` and `[[push]]` in `config.toml`, or the same two lists in the App and the web panel, where a channel also has a **Send a test** button. See [Alert rules](#alert-rules) for how a rule is written.

## Alert rules

A rule has four fields. **Metric** picks what is read, **matcher** picks which part of it, and **threshold** decides when that reading is worth an alert.

```toml
[[monitoring.rules]]
name = "CPU busy"
monitor_type = "cpu"
matcher = "cpu"
threshold = ">=80%"
```

### Metric and matcher

| Metric | Matcher | Reading |
| --- | --- | --- |
| `cpu` | `cpu` or blank | Usage across all cores |
| `cpu` | `cpu0`, `cpu1`, … | Usage of one core |
| `memory` | `used`, `memory` or blank | Percent used |
| `memory` | `free` | Percent not used |
| `memory` | `avail` | Percent available |
| `swap` | `used`, `swap` or blank | Percent used |
| `swap` | `free` | Percent not used |
| `disk` | Ignored | Percent used across all filesystems |
| `network` | `rx` or `in` | Receive speed |
| `network` | `tx` or `out` | Transmit speed |
| `network` | Blank or anything else | Receive plus transmit |
| `temperature` | Ignored | The reading the agent reports as the machine's temperature |

`mem`, `net` and `temp` are accepted as well, so a configuration migrated from the Go agent keeps working. Any other metric is written to the agent's log once per cycle and the rule never fires.

### Threshold

A comparator, a value, and a unit: `>=80%`, `<10%`, `>10m/s`, `>=70c`.

| Comparator | Fires when the reading is |
| --- | --- |
| `>=` | At or above the value |
| `>` | Above the value |
| `<=` | At or below the value |
| `<` | Below the value |
| `=` | Exactly the value |

**A threshold with no comparator means `<`.** `80%` is "below 80 percent", not "above" — write `>=80%` for the usual case.

The unit decides what kind of threshold it is, and it has to match the metric:

| Unit | Kind | Use with |
| --- | --- | --- |
| `%` | Percent | `cpu`, `memory`, `swap`, `disk` |
| `c` | Temperature | `temperature` |
| `/s` after a size, as in `10m/s` | Speed | `network` |
| `b`, `k`, `m`, `g`, `t` | Size | `network` |

Sizes are base 1024 and lowercase. A threshold whose unit does not fit its metric — `>=80%` on a `network` rule — is written to the log and never fires, so the rule is silently inactive rather than wrong.

### Examples

```toml
[[monitoring.rules]]
name = "Core 0 pinned"
monitor_type = "cpu"
matcher = "cpu0"
threshold = ">=95%"

[[monitoring.rules]]
name = "Memory running out"
monitor_type = "memory"
matcher = "avail"
threshold = "<10%"

[[monitoring.rules]]
name = "Disk filling up"
monitor_type = "disk"
matcher = ""
threshold = ">=90%"

[[monitoring.rules]]
name = "Download burst"
monitor_type = "network"
matcher = "rx"
threshold = ">10m/s"

[[monitoring.rules]]
name = "Running hot"
monitor_type = "temperature"
matcher = ""
threshold = ">=70c"
```

### When a rule stays quiet

- **A network rule does not fire on the first cycle** after the agent starts, after a gap in collection, or for an interface that has just appeared. A speed is the difference between two samples, and there is no speed until the second one lands.
- **A cycle with no reading is skipped, not judged.** If memory or disk cannot be read, the rule is passed over rather than evaluated against a zero — otherwise a `>=90%` rule would go quiet on a machine that is filling up, and a `<10%` rule would fire on one that is fine.
- **A temperature rule needs a temperature.** Not every machine reports one.

Rate limiting applies per channel, not per rule: see `push_rate` in `config.toml`, or **Rate limit** in the App.

## Troubleshooting

**Features are missing from the server page.** The App shows what the agent reports. Commands and the terminal require `full_access` and the terminal endpoint; file browsing requires `[remote_access.fs]` and `roots`. Restart the agent after changing its configuration.

**Certificate errors.** Configure valid TLS, put the agent behind a reverse proxy, or enable **Monitor Ignore certificate** for that server.

**The panel is hosted on another origin.** Add the origin to `cors_allowed_origins` in `config.toml` or to the `SBM_CORS_ORIGINS` environment variable.

**Requests receive no response.** Confirm that the agent is running and the port is reachable, then inspect `access_log` in its database. It records the visitor, time, source, requested resource, and result, but never credentials.
