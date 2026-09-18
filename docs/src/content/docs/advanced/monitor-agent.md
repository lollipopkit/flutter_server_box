---
title: Monitor Agent
description: Reach a server through Monitor agent
---

Server Box Monitor is a small service that runs on your server and reports its status to the App. It lets you check the server without opening an SSH port, and keeps push alerts, home-screen widgets, and the Watch app working when the App is closed.

## Prompts for an AI agent

Each prompt is ready to give to an AI agent that can reach the server over SSH. It spells out the details an agent should not have to guess: rule syntax and permission switches can fail silently, so a mistake may look fine until an alert never arrives.

Replace the angle-bracketed placeholders before sending a prompt.

<details>
<summary>Install the agent</summary>

```text
Install the ServerBox Monitor agent on <host> via SSH.

The installer is
https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh
It detects the init system automatically. When piped to `sh`, it installs a
`systemctl --user` service for my user. On Alpine, use `sudo sh` so it can
write to /etc/init.d; the agent still runs as the user who invoked sudo.

Do not install it as a root system service. Running the agent as root makes
`full_access` much more dangerous.

Leave every switch under `[remote_access]` turned off, and write
`full_access = false` there explicitly.

It is the one switch in that section that is not off by default: unset, it
follows the platform, and on Linux that means on. Nothing comes of it on
its own, because it is gated on the terminal being enabled and the terminal
is off — but whoever turns the terminal on later would be opening a
passwordless shell without having written `true` anywhere. An explicit
`false` in the file is also sticky: `SBM_FULL_ACCESS=1` cannot reopen it.

I will decide separately whether to enable any of the others.

When you finish, report:
- the path of config.toml and of the SQLite database beside it
- the address and port it listens on
- what `loginctl show-user <user> -p Linger` says. Without linger a --user
  service stops when I log out.
- the mode of config.toml and of the database. The config can hold push
  credentials and the database holds the panel user table, so neither
  should be group- or world-readable.
```

</details>

<details>
<summary>Turn on remote access</summary>

```text
Configure remote access for the ServerBox Monitor agent on <host> so the app
and panel can <open a terminal / browse files / run commands>.

Before changing anything, explain the consequences and wait for my approval.
`full_access = true` makes the panel password equivalent to a shell for the
account running the agent, without any SSH authentication in between.

Keep these details in mind:

- These switches exist only in the agent's config.toml. No API or panel
  control can turn them on; the panel can only turn `full_access` off. Editing
  the file is the only way to enable them.
- `full_access` is gated on `[remote_access.terminal] enabled`. Setting
  full_access by itself does nothing.
- The terminal and the file API refuse plaintext requests that arrive over
  the network, and serve loopback callers — including a reverse proxy on the
  same host — without TLS. So if the agent binds 127.0.0.1, or a same-host
  proxy terminates TLS, `allow_insecure` is not needed. Only consider it if
  the agent is reachable directly over plaintext from another machine, and
  say so before you do.
- `[remote_access.fs]` does nothing without `roots`. Name the directories
  that actually need browsing. `roots = ["/"]` makes the panel password
  worth a shell, because anyone who can write ~/.ssh/authorized_keys has
  one, and the agent warns about it at startup.

Restart the agent afterwards and show me the `Remote access:` line from its
log. It summarizes what is actually enabled. If everything is off, the line
will not appear.
```

</details>

<details>
<summary>Add an alert rule and a notification channel</summary>

```text
Add an alert rule to the ServerBox Monitor agent on <host>.

What I want to be alerted about: <describe it>

Use this exact rule format:

- A rule is a `[[monitoring.rules]]` table with `name`, `monitor_type`,
  `matcher` and `threshold`.
- `monitor_type` is one of cpu, memory, swap, disk, network, temperature.
  `mem`, `net` and `temp` are accepted as well. Anything else is logged and
  the rule will never fire.
- `matcher` picks part of the metric: `cpu0` for a single core,
  `used`/`free`/`avail` for memory and swap, `rx`/`tx` for network. Disk
  and temperature ignore it entirely.
- `matcher` is NOT an interface name or a mount point. A network rule with
  `matcher = "eth0"` silently measures total rx+tx instead of that
  interface.
- `threshold` is a comparator, a value and a unit: `>=80%`, `<10%`,
  `>10m/s`, `>=70c`. A threshold with no comparator means `<`, so `80%`
  reads as "below 80 percent".
- The unit has to fit the metric: `%` for cpu/memory/swap/disk, `c` for
  temperature, a size or a size with `/s` for network. Sizes are base 1024
  and lowercase. A mismatch is logged and never fires.

If I also asked for a notification channel, add a `[[push]]` table for it.
`push_rate` in config.toml limits notifications per channel, not per rule.

The agent reads rules and channels at startup, so restart it afterwards. Then
show me exactly what you wrote.
```

</details>

<details>
<summary>Work out why a feature is missing in the app</summary>

```text
The ServerBox app does not offer <what> for the server connected to the
Monitor agent at <host>. Find out why, and tell me what you find before
changing anything.

Check these first:

- The app shows what the agent reports on `GET /api/v1/capabilities` and
  nothing else. A terminal, commands, containers, processes, systemd, power
  and scheduled tasks all need `full_access`, which is itself gated on
  `[remote_access.terminal] enabled`. File browsing needs
  `[remote_access.fs] enabled` together with a non-empty `roots`.
- SFTP and port forwarding are never available through the agent at all. No
  endpoint relays a connection to an address the app names, so those need
  SSH configured for the same server in the app.
- The terminal and the file API refuse plaintext requests arriving over the
  network. Loopback callers and a same-host reverse proxy are fine without
  TLS.
- The agent logs a `Remote access:` summary at startup when anything under
  that section is enabled. It logs nothing when everything is off.
- The `access_log` table in the agent's SQLite database records the visitor,
  time, source, requested resource and result. It never records credentials.
```

</details>

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

## Panel credentials

The user and password that the App and the web panel sign in with are rows in the agent's SQLite database, not settings in `config.toml`. `jwt_secret` in that file signs session tokens; it is not a login password.

Run the commands below in the agent's own directory — `/opt/server-box-monitor` for a root-owned service, `~/.local/share/server-box-monitor` otherwise — and as the account the agent runs as. `config.toml` and the database path are resolved relative to the working directory, so the same command run elsewhere writes a fresh default `config.toml`, creates an empty database, and reports success against a database that nothing reads.

### The first password

On its first start with an empty user table, the agent creates `admin` with a random password and writes it beside the database as `initial-admin-credentials.txt`, mode 0600 on Unix:

```sh
cd /opt/server-box-monitor
cat initial-admin-credentials.txt
```

Change the password, then delete the file. If it is still there on a later start while the user table is empty — after the database is deleted or moved, for example — the agent stops with an error instead of writing a second set of credentials over the first.

### Change or reset a password

```sh
cd /opt/server-box-monitor
./server_box_monitor user set-password admin
```

The new password is asked for twice, without echo, and must be at least 8 characters. The same command creates a user that does not exist yet, so it is also how a second account is added.

To take the password from the environment instead — in a script, or to keep it out of the shell history:

```sh
read -rs SBM_PW
SBM_PW="$SBM_PW" ./server_box_monitor user set-password admin --password-env SBM_PW
```

There is no option that accepts the password as an argument, because a command line is visible in `ps` and recorded by the shell.

The new password works at the next login and the agent does not need restarting; it reads the user table on every login. Sessions already signed in continue for up to an hour, the lifetime of a token. To end them at once, change `jwt_secret` in `config.toml` and restart the agent — `systemctl --user restart server_box_monitor`, or `rc-service server-box-monitor restart` under OpenRC — which invalidates every token issued so far.

Then update the password in the App, by editing the server and replacing **Monitor Password**, and in anything else that stores it. Nothing tells a client that the agent's password changed; it simply stops signing in.

### A forgotten password

The panel has no recovery path. Reset it on the server with the command above.

Failed logins are throttled per source address and per username: three failures are free, and the delay then doubles from one second up to five minutes. A forgotten password can therefore look like an agent that has stopped answering.

## Add it in the App

1. Tap **+** to add a server.
2. Enable **Monitor HTTP**. SSH and Monitor HTTP are independent switches: you can enable either one or both. When both are enabled, use **Preferred transport** to choose which one the App tries first.
3. Enter:
   - **URL**: for example, `https://1.2.3.4:3770`
   - **Monitor User** / **Monitor Password**: the agent's web-panel credentials — see [Panel credentials](#panel-credentials)
   - **Monitor Ignore certificate**: enable only for a self-signed certificate
4. Save the configuration.

A server added through Monitor HTTP contains **no SSH credentials**. The App has no other way to reach the machine beyond the capabilities explicitly provided by the agent.

## Integrated GPU monitoring

On Linux, AMD integrated GPUs are read from the kernel's DRM/sysfs interfaces. ROCm, `amd-smi`, and `rocm-smi` are not required for an APU to report utilization. Intel integrated GPU utilization requires `intel_gpu_top`, normally provided by the `intel-gpu-tools` package.

The App and Monitor agent never invoke interactive `sudo` during collection. If the account running the SSH command or Monitor agent cannot access Intel's GPU performance counters, the device still appears but unavailable values are omitted instead of shown as zero. Grant that account the distribution-appropriate permission for the GPU PMU if utilization is needed.

Each Linux GPU is labelled with its PCI address, such as `0000:00:02.0`, so systems with several integrated or discrete GPUs show separate, stable entries.

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

**Login is rejected, or the password is lost.** Reset it on the server with `user set-password`; see [Panel credentials](#panel-credentials). Repeated failures are throttled, so a wrong password can also present as a slow or unresponsive agent.

**Requests receive no response.** Confirm that the agent is running and the port is reachable, then inspect `access_log` in its database. It records the visitor, time, source, requested resource, and result, but never credentials.
