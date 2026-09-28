---
title: Monitor Agent
description: Reach a server through Monitor agent
---

Server Box Monitor runs on a server and sends its status to the App. You can
monitor a host without exposing SSH, and keep push alerts, home-screen widgets,
and the Watch app up to date while the App is closed.

## Prompts for an AI agent

The prompts below are for an AI agent that can reach the server over SSH.
They include configuration details that are easy to get wrong. For example,
an invalid alert rule may be logged but never trigger, leaving you without the
alert you expected.

Replace every placeholder in angle brackets before sending a prompt.

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

- The App shows features that the agent currently enables. A terminal,
  commands, containers, processes, systemd, power
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

SSH is usually the simplest way to connect. Use Monitor agent if SSH is
unreachable from your current network, if you need charts to include data
collected before the App connected, or if you want server alerts on your
phone.

You can use both methods for one server. Configure SSH in the App and run
Monitor agent on the host to provide widgets, Watch app data, and alerts.

## Install Monitor agent

Install a published `monitor-v*` release when available, or build the agent
from source. Releases are created by a manually dispatched workflow. For an
unreleased build or an offline install, provide a local package through
`SBM_INSTALL_PKG`.

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

Arguments after `sh -s --` are passed to the installer; use the same pattern
for `uninstall` and `upgrade`. The script is also in the repository, so you
can run `./monitor/install.sh install` from a checkout root. That uses the
checked-out script, which may differ from the version fetched from `main` by
the commands above.

The agent runs as an ordinary user by default. This limits the scope of `full_access`; see [Permission switches](#permission-switches).

The agent reads `config.toml` from the directory beside its binary. See
[`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml)
for every available option. By default, the agent listens on `0.0.0.0:3770`.
If `frontend/dist` is present, it also serves the web panel from that address.

Collection intervals, alert rules, notification channels, data retention, and
allowed panel origins can be edited without opening `config.toml`. Use
**Server Settings** in the web panel, or open the server in the App and tap
the settings button in the top bar. Both interfaces update the same agent and
configuration file.

The JWT secret, `database_url`, and `[remote_access]` switches can only be
changed in the configuration file. Keeping the access switches out of the
panel prevents a panel password from granting additional capabilities.

The editor never returns stored secrets such as ServerChan or Bark keys, an
iOS push token, or an `Authorization` header. It shows that each value is
*set* while leaving the field empty. Leave it empty to keep the existing
secret, or enter a replacement.

Changes to notification channels, alert rules, the collection interval, data
retention, and allowed origins take effect after a restart. The extended cycle
interval and both idle-pause settings apply immediately. The App marks any
setting that needs a restart.

If other devices need to connect to the agent, protect the connection with
HTTPS. Configure built-in TLS under `[server.tls]` or use a reverse proxy. To
connect with a self-signed certificate, explicitly enable **Monitor Ignore
certificate** for that server in the App.

## How far back the App can ask

The available chart range depends on how long Monitor agent retains data and
how much history it has collected. The App shows only the ranges the agent can
provide. For API fields and history-query behavior, see
[Monitor agent API and access model](/docs/development/monitor-agent/).

## Panel credentials

The App and web panel authenticate with a user account stored in the agent's
SQLite database. These credentials are not configured in `config.toml`. The
`jwt_secret` in that file signs session tokens; it is not a user password.

Run the commands below from the agent's working directory and as the account
that runs the service: `/opt/server-box-monitor` for a root-owned service, or
`~/.local/share/server-box-monitor` otherwise. Both `config.toml` and the
database path are relative to this directory. Running a command elsewhere
would create a new default configuration and empty database, then update a
database the service does not use.

### The first password

When the agent starts with an empty user table for the first time, it creates
an `admin` user with a random password. The password is written next to the
database in `initial-admin-credentials.txt`, with mode 0600 on Unix:

```sh
cd /opt/server-box-monitor
cat initial-admin-credentials.txt
```

Change the password and delete this file. If the database is later removed or
moved and the user table is empty while the file remains, the agent stops
instead of overwriting the original credentials with a new set.

### Change or reset a password

```sh
cd /opt/server-box-monitor
./server_box_monitor user set-password admin
```

The command prompts for the new password twice without displaying it. It
requires at least 8 characters. If the named user does not exist, the command
creates it; use this to add another account as well.

To set the password from an environment variable, use the following in a
script or when you want to keep it out of shell history. This uses Bash or
Zsh: `read -s` is not available in POSIX `sh`. The check prevents a failed or
empty read from setting an empty password:

```bash
read -rsp 'Password: ' SBM_PW && echo
[ -n "$SBM_PW" ] || { echo 'no password entered' >&2; exit 1; }
SBM_PW="$SBM_PW" ./server_box_monitor user set-password admin --password-env SBM_PW
```

The command deliberately has no password argument: command-line arguments
can appear in `ps` output and shell history.

The new password applies to the next login; no restart is needed because the
agent reads the user table at each login. Existing sessions remain valid for
up to one hour. To invalidate them immediately, change `jwt_secret` in
`config.toml` and restart the agent with `systemctl --user restart
server_box_monitor`, or `rc-service server-box-monitor restart` on OpenRC.

After changing the password, update **Monitor Password** in the App and
replace it in any other client that uses the account. Clients are not notified
about password changes and cannot sign in until their saved credentials are
updated.

### A forgotten password

There is no password recovery flow in the panel. Reset the password on the
server with the command above.

Login attempts are rate-limited by both source address and username. The first
three failures have no delay; after that, the delay doubles from one second up
to five minutes. A forgotten password may therefore make the agent appear
slow or unresponsive.

## Add it in the App

1. Tap **+** to add a server.
2. Enable **Monitor HTTP**. This connection is independent of SSH, so you can
   enable either transport or both. If both are enabled, set **Preferred
   transport** to choose which one the App tries first.
3. Enter:
   - **URL**: for example, `https://1.2.3.4:3770`
   - **Monitor User** / **Monitor Password**: the agent's web-panel credentials — see [Panel credentials](#panel-credentials)
   - **Monitor Ignore certificate**: enable only for a self-signed certificate
4. Save the configuration.

Monitor HTTP does not configure SSH credentials. With no SSH connection, the
App can reach the server only through capabilities that Monitor agent exposes.

## Integrated GPU monitoring

On Linux, the agent reads AMD integrated GPU metrics through the kernel's
DRM/sysfs interfaces; an APU does not need ROCm, `amd-smi`, or `rocm-smi` to
report utilization. Intel GPU utilization requires `intel_gpu_top`, usually
provided by the `intel-gpu-tools` package.

Neither the App nor Monitor agent prompts for an interactive `sudo` password
during collection. If the SSH or agent account cannot read Intel GPU
performance counters, the GPU remains listed and unavailable values are left
out. To collect utilization, grant that account the appropriate GPU PMU
permission for the Linux distribution.

Each Linux GPU is identified by its PCI address, for example
`0000:00:02.0`. Systems with multiple integrated or discrete GPUs therefore
show a distinct, stable entry for each device.

## Permission switches

The App displays only the features enabled by the Monitor agent operator. The
file API and web-panel terminal start disabled; an operator must enable them
in `config.toml`.

**Status, charts, and stored history** are available after panel login.

**`full_access`** lets an authenticated user run a shell and commands as the
agent's operating-system account. The App requires it for process, systemd,
container, snippet, power-control, and terminal features. RDP and VNC remote
desktop use it as well. Remote desktop has no separate switch because shell
access already allows port forwarding. This permission is available only while
`[remote_access.terminal] enabled = true`.

The agent uses a single `full_access` switch. A user with shell access can run
arbitrary commands, so a separate “commands” switch would not limit the
permission. The default is enabled on Linux and disabled on macOS and Windows.
The panel can turn it off. To turn it back on, edit the configuration file.

**A panel password grants shell-level access as the agent user when
`full_access` is enabled.** The installer therefore runs the agent as an
ordinary user by default. If you choose to run it as root, disable
`full_access`.

**`[remote_access.fs]`** enables file browsing within directories listed in
`roots`. This grants access to those paths; `full_access` grants a shell.
`roots` is empty by default, so list the directories explicitly when enabling
file access.

Setting `roots = ["/"]` exposes the whole filesystem and grants access close
to shell access; the agent warns about this configuration at startup. To use
the File API over plaintext HTTP from another device, also set
`[remote_access.fs] allow_insecure = true`. For path validation and transport
details, see
[Monitor agent API and access model](/docs/development/monitor-agent/).

**`[remote_access.terminal]`** enables terminal access for the App and web
panel. The panel terminal connects to the configured SSH server and uses that
SSH account's permissions. When `full_access` is enabled, the App's terminal
uses the agent account's local shell. Panel credentials alone do not grant
shell access.

Use HTTPS for terminal access. Plaintext HTTP requires both
`[remote_access.terminal] allow_insecure = true` in the agent configuration
and **Allow insecure HTTP** for this server in the App. See
[Monitor agent API and access model](/docs/development/monitor-agent/) for
transport rules and endpoint behavior.

## Unsupported features

A Monitor HTTP connection cannot provide SFTP or port forwarding. The agent
does not relay arbitrary TCP connections to addresses selected by the App.
The file API supports **browsing** by transferring file contents; it does not
provide a general-purpose byte stream.

To use SFTP or port forwarding, also configure SSH for that server in the App.

## Widgets, push, and the Watch app

Widgets, push notifications, and the Watch app read from Monitor agent, so the
App does not need to stay in the foreground:

- **Home-screen widgets**: Configure the server in the App after installing Monitor agent. The widget selects from the server list published by the App; you do not enter a URL manually.
- **Watch app**: It can show only servers with Monitor agent configured. These servers sync by default, and you can exclude individual servers in the iOS settings.
- **Push alerts**: A rule decides when to alert and a channel decides where it goes — `[[monitoring.rules]]` and `[[push]]` in `config.toml`, or the same two lists in the App and the web panel, where a channel also has a **Send a test** button. See [Alert rules](#alert-rules) for how a rule is written.

## Alert rules

Each rule has four fields: `name`, `monitor_type`, `matcher`, and `threshold`.
The metric selects what to measure, the matcher selects which part of that
metric to evaluate, and the threshold sets when to send an alert.

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

The aliases `mem`, `net`, and `temp` are also accepted for configurations
migrated from the Go agent. Any other metric is logged once per cycle, and its
rule never fires.

### Threshold

A threshold combines a comparator, value, and unit. Examples: `>=80%`,
`<10%`, `>10m/s`, and `>=70c`.

| Comparator | Fires when the reading is |
| --- | --- |
| `>=` | At or above the value |
| `>` | Above the value |
| `<=` | At or below the value |
| `<` | Below the value |
| `=` | Exactly the value |

If you omit the comparator, the rule uses `<`. For example, `80%` means
“below 80 percent”; write `>=80%` to alert at or above 80 percent.

The unit must match the metric:

| Unit | Kind | Use with |
| --- | --- | --- |
| `%` | Percent | `cpu`, `memory`, `swap`, `disk` |
| `c` | Temperature | `temperature` |
| `/s` after a size, as in `10m/s` | Speed | `network` |
| `b`, `k`, `m`, `g`, `t` | Size | `network` |

Network sizes use base 1024 and lowercase units. If a unit does not match its
metric, such as `>=80%` on a `network` rule, the agent logs the error and the
rule never fires.

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

- **Network rules need two samples.** After startup, a collection gap, or a
  newly detected interface, the first sample provides no speed value. The
  rule can be evaluated after the next sample arrives.
- **Missing readings skip a cycle.** If memory or disk data is unavailable,
  the agent skips that rule instead of treating the reading as zero.
- **Temperature rules need a temperature reading.** Some machines do not
  report one.

Rate limits apply to each notification channel. Configure `push_rate` in
`config.toml` or **Rate limit** in the App.

## Troubleshooting

**A feature is missing from the server page.** The App displays only the
features the agent reports. Commands and terminal access require
`full_access` and the terminal endpoint; file browsing requires
`[remote_access.fs]` and configured `roots`. Restart the agent after changing
its configuration.

**Certificate errors.** Configure valid TLS, put the agent behind a reverse proxy, or enable **Monitor Ignore certificate** for that server.

**The panel uses a different origin.** Add that origin to
`cors_allowed_origins` in `config.toml` or the `SBM_CORS_ORIGINS` environment
variable.

**Login is rejected, or the password is lost.** Reset it on the server with `user set-password`; see [Panel credentials](#panel-credentials). Repeated failures are throttled, so a wrong password can also present as a slow or unresponsive agent.

**A request gets no response.** Confirm that the agent is running and its
port is reachable. Then inspect the database's `access_log` table, which
records the visitor, time, source, requested resource, and result without
storing credentials.
