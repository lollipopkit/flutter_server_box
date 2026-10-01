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

Do not install it as a root system service. An account whose role holds the
`shell` grant runs commands as whoever the agent runs as; as root, that is the
whole machine.

Pass `--permissions read` to the installer (`sh -s -- install --permissions
read`), so the admin account it creates starts with no grants. I will turn on
what I need from the app or the web panel.

Do not add `full_access`, `listen_public`, or an `enabled` key under
`[remote_access]` to config.toml. The agent no longer reads them: who may do
what is each account's role, kept in the agent's database.

When you finish, report:
- the path of config.toml and of the SQLite database beside it
- the path of initial-admin-credentials.txt. Do not print what it contains.
- the address and port it listens on
- what `loginctl show-user <user> -p Linger` says. Without linger a --user
  service stops when I log out.
- the mode of config.toml and of the database. The config can hold push
  credentials and the database holds the panel user table, so neither
  should be group- or world-readable.
```

</details>

<details>
<summary>Prepare the machine for remote access</summary>

```text
Prepare the ServerBox Monitor agent on <host> so that accounts can be given
<a terminal / file browsing / commands / port forwarding>.

Before changing anything, explain the consequences and wait for my approval.

Keep these details in mind:

- Who may do what is not in config.toml. Each account has a role, and a role
  holds grants: shell, ssh_terminal, files, connect and listen. An admin
  edits accounts and roles from the app or the web panel, entering their own
  password again to do it. Do not try to grant anything by editing
  config.toml or the database.
- config.toml still decides the machine side:
  - Everything beyond reading the numbers needs TLS or a loopback caller,
    and a reverse proxy on the same host counts. If the agent binds
    127.0.0.1, or a same-host proxy terminates TLS, nothing more is needed.
    Only consider `[remote_access] allow_insecure = true` if the agent is
    reached directly over plaintext from another machine, and say so before
    you do.
  - The files grant serves nothing without `[remote_access.fs] roots`. Name
    the directories that actually need browsing. `roots = ["/"]` with write
    access is worth a shell, because anyone who can write
    ~/.ssh/authorized_keys has one; the agent warns about it at startup.
  - The panel's SSH terminal signs in to `[remote_access] ssh_addr`.

Restart the agent after changing config.toml. Then tell me which grants to
turn on, for which role, in the app or the panel.
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

- The App offers what the agent allows the account it signed in with. Each
  grant comes with `ok` and, when it is not usable, `why`: `not_granted`
  (the account's role does not hold it; an admin changes that from the app
  or the panel), `insecure_transport` (it needs TLS or a loopback caller,
  or `[remote_access] allow_insecure`), or `not_configured` (files without
  `[remote_access.fs] roots`). `GET /api/v1/capabilities` with that
  account's login shows it under `grants`.
- Commands, processes, systemd, containers, snippets, power, scheduled tasks
  and the App's terminal need `shell`. File browsing needs `files`; with
  `mode = "read"` nothing can be changed. Remote desktop and local or
  dynamic forwards need `connect`, and its `allow` list, when it has
  entries, must include the address. Remote forwards need `listen`; binding
  anything but loopback needs its `public` option.
- SFTP is never available through the agent: it needs SSH configured for
  the same server in the app.
- An agent from before roles reports only `remote_access`, and one older
  than the relay or the listener offers no port forwarding or remote
  desktop. Update it.
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
| Terminal, commands, and file browsing | Yes | Depends on the account's role |
| SFTP transfers | Yes | No |
| Port forwarding (local, dynamic, remote) and remote desktop | Yes | With the `connect` or `listen` grant |
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

To start with an admin account that holds no grants, add
`--permissions read`:

```sh
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sh -s -- install --permissions read
```

`--permissions full|read` decides what the admin account starts with on a
fresh install: every grant (`full`, the default) or none (`read`), to be
turned on later from the App or the panel. It reaches the agent as
`SBM_INIT_PERMISSIONS` in the service's environment; when you run the binary
yourself, pass `serve --init-permissions read`. It only applies when the agent
creates its first account, so an existing installation keeps its roles.

Arguments after `sh -s --` are passed to the installer; use the same pattern
for `uninstall` and `upgrade`. The script is also in the repository, so you
can run `./monitor/install.sh install` from a checkout root. That uses the
checked-out script, which may differ from the version fetched from `main` by
the commands above.

The agent runs as an ordinary user by default. An account whose role holds `shell` runs commands as that user, so this limits what such an account can reach; see [Accounts and permissions](#accounts-and-permissions).

The agent reads `config.toml` from the directory beside its binary. See
[`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml)
for every available option. By default, the agent listens on `0.0.0.0:3770`.
If `frontend/dist` is present, it also serves the web panel from that address.

Collection intervals, alert rules, notification channels, data retention, and
allowed panel origins can be edited without opening `config.toml`. Use
**Server Settings** in the web panel, or open the server in the App and tap
the settings button in the top bar. Both interfaces update the same agent and
configuration file.

Only an admin account can see and change these settings. The JWT secret,
`database_url`, and `[remote_access]` (plaintext tolerance, file roots, the
SSH address, and size limits) can only be changed in the configuration file.
Who may do what is in neither place: it is each account's role, which an
admin edits from the App or the panel. See
[Accounts and permissions](#accounts-and-permissions).

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
an `admin` user in the `admin` role with a random password. The password is written next to the
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
creates it in the `viewer` role — or `admin`, when the agent has no admin
account yet; add `--role <name>` to give it another role, or to move an
existing account. An admin can also add accounts from the App or the panel;
see [Editing accounts and roles](#editing-accounts-and-roles).

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

A password change ends what the old password was used for:

- **Logins and paired devices, at once, whichever way the password was
  changed.** Logins from before the change are refused from the next request,
  and the account's paired widgets and Watch are unpaired. No restart is
  needed for this, and `jwt_secret` does not need to change.
- **Open terminals, port forwards and listeners, at once when the password is
  changed from the App or the panel.** The command above writes the database
  and cannot reach the running agent, so connections already open under the
  old password keep running until the agent restarts: `systemctl --user
  restart server_box_monitor`, or `rc-service server-box-monitor restart` on
  OpenRC. Restart it after a reset made because the password may be known to
  someone else.

Any account can also change its own password from the App or the panel; see
[Editing accounts and roles](#editing-accounts-and-roles). Changing it in the
App updates the password the App has saved for that server.

After changing the password on the server, update **Monitor Password** in the
App and replace it in any other client that uses the account. Clients are not notified
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

<a id="permission-switches"></a>

## Accounts and permissions

Every account can read status, charts, and stored history. Everything else is
a **grant**, and an account holds the grants of its **role**. Grants and roles
are kept in the agent's database and edited from the App or the web panel.
`config.toml` only decides the machine side, such as which directories files
may come from and whether plaintext HTTP is tolerated.

| Grant | Allows | Options |
|---|---|---|
| `shell` | Commands, processes, systemd, containers, snippets, power, scheduled tasks, and the App's terminal, as the agent's operating-system account | — |
| `ssh_terminal` | The web panel's terminal, which signs in to the SSH server at `[remote_access] ssh_addr` with that SSH account's own credentials | — |
| `files` | File browsing inside `[remote_access.fs] roots` | `read` (browse and download) or `write` (also upload, create, rename, chmod, and delete) |
| `connect` | Remote desktop (RDP, VNC) and local and dynamic port forwarding: connections the agent opens | `allow`: the addresses it may reach; empty is anywhere |
| `listen` | Remote port forwarding: the agent listens on the server | `public`: addresses other than loopback; a port range |

`shell` covers the others in practice: an account that can run commands can
read files, open connections, and listen by itself. Grant `files`, `connect`,
or `listen` without `shell` when an account needs only that, for example a
role that reaches one remote desktop and nothing else.

### Roles

The agent has two built-in roles:

- **admin** holds the grants it is given and, unlike any other role, manages
  accounts, roles, and the agent's settings: alert rules, notification
  channels, collection intervals, and allowed origins. Editing custom
  commands also needs `shell`, because the agent runs them.
- **viewer** holds no grants: status, charts, and history only.

An admin can change the grants of both built-in roles and add roles. A role
name uses lowercase letters, digits, `-`, and `_`, up to 32 characters.
Built-in roles cannot be renamed or deleted, and a role that an account still
has cannot be deleted. The last admin account cannot be deleted or moved to
another role.

### Editing accounts and roles

In the App, open the server, tap the settings button in the top bar, and use
**Accounts** and **Roles** under **Access**. In the web panel they are at the
end of **Server Settings**. Every change to an account or a role asks for your
own password again; wrong attempts count against the same limit as logins.

A change applies at once. A session that relies on a grant its account no
longer holds, such as a terminal, a remote desktop, or a port forward, is
closed. A deleted account cannot use any existing session.

Every account, admin or not, can see its own role and change its own password:
under **Access** in the App, and under **Your account** in the panel.

### Permissions of a new installation

On a fresh install, the `admin` account starts in the `admin` role with every
grant: `files` with write access, `connect` to anywhere, `listen` on loopback
with any port, `shell`, and `ssh_terminal`. Install with `--permissions read`
to start with none and turn on what you need from the App or the panel; see
[Install Monitor agent](#install-monitor-agent).

If the `config.toml` the agent starts with still sets the old switches
(`full_access`, `[remote_access.terminal] enabled`, `[remote_access.fs]
enabled`, `listen_public`) — a mounted configuration on a new data volume, an
old example copied over — a fresh install honours them: the admin role gets
only what they allowed as well, and the log says so.

`files` still needs `[remote_access.fs] roots`. Until they are set, the App
reports file browsing as not set up on the agent. Whatever the roots, the file
API never reaches the agent's own files — its database, `jwt.secret`,
`config.toml` and its backups, `.env`, the TLS key and certificate, and the custom
commands — since reading them would hand out an admin login.

**An account whose role holds `shell` has a shell as the agent's user.** The
installer therefore runs the agent as an ordinary user by default. Keep this
in mind before running it as root.

### Upgrading from an agent without roles

Earlier agents used switches in `config.toml` instead of roles. The first
start of an agent with roles converts them once: every existing account
becomes an admin, and the `admin` role holds what the old switches actually
allowed.

| Old setting | Becomes |
|---|---|
| `[remote_access.terminal] enabled` | `ssh_terminal` |
| `full_access` (including its platform default and `SBM_FULL_ACCESS`), counted only while the terminal was enabled | `shell`, `connect` to anywhere, and `listen` |
| `listen_public` | `listen` with `public` |
| `[remote_access.fs] enabled` with non-empty `roots` | `files` with write access |

After that, the agent no longer reads these keys and logs once that they can
be deleted. Turning off shell access from the panel's first-use notice removes
`shell`, `connect`, and `listen` from every role.

### Plaintext HTTP

Everything beyond reading the numbers needs HTTPS or a caller on the same
host, which includes a reverse proxy there. On a private network that already
encrypts traffic, such as Tailscale, set `[remote_access] allow_insecure =
true` and enable **Allow insecure HTTP** for this server in the App; both are
required. The older keys still count, each for what it used to
cover: `[remote_access.terminal] allow_insecure` for shell, terminal, connect
and listen, `[remote_access.fs] allow_insecure` for files only.

### Limits on connecting and listening

`connect.allow` takes one entry per line: an IP address or a CIDR range,
optionally followed by a port or a port range, such as `127.0.0.1:3389`,
`10.0.0.0/8`, or `[::1]:5900-5910`. When a connection names a host, the agent
resolves it and every resulting address must be allowed. `localhost` usually
resolves to both `127.0.0.1` and `::1`, so allowing only one of them refuses
`localhost`; enter the address itself in the App.

A remote forward binds loopback addresses only, as sshd does with
`GatewayPorts no`, unless the role's `listen` has **public** turned on. A port
range on `listen` limits which ports it may bind.

For path validation, endpoint behavior, and error codes, see
[Monitor agent API and access model](/docs/development/monitor-agent/).

## Unsupported features

A Monitor HTTP connection cannot provide SFTP: it runs through an SSH channel.
The file API supports **browsing** by transferring file contents; it does not
provide a general-purpose byte stream.

A server whose agent leads (the agent alone, or both with the agent preferred)
runs every port forward through the agent and never falls back to SSH. A
dynamic forward is a SOCKS5 proxy on your device; each connection it carries
is dialled from the server.

To use SFTP, also configure SSH for that server in the App. An agent older than
the relay or the listener offers no remote desktop or port forwarding; update
it.

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

**A feature is missing or greyed out.** The App offers what the agent allows
the account it signed in with, and says why when it does not: the account's
role lacks the grant, which an admin can change; the connection needs HTTPS;
or the agent's operator has not set it up, such as file `roots`. See
[Accounts and permissions](#accounts-and-permissions). Role changes apply at
once; restart the agent after editing `config.toml`.

**Settings cannot be changed.** Only an admin account can view and change the
agent's settings, notification channels, and alert rules. Sign in with an
admin account, or ask an admin to change your role.

**Certificate errors.** Configure valid TLS, put the agent behind a reverse proxy, or enable **Monitor Ignore certificate** for that server.

**The panel uses a different origin.** Add that origin to
`cors_allowed_origins` in `config.toml` or the `SBM_CORS_ORIGINS` environment
variable.

**Login is rejected, or the password is lost.** Reset it on the server with `user set-password`; see [Panel credentials](#panel-credentials). Repeated failures are throttled, so a wrong password can also present as a slow or unresponsive agent.

**A request gets no response.** Confirm that the agent is running and its
port is reachable. Then inspect the database's `access_log` table, which
records the visitor, time, source, requested resource, and result without
storing credentials.
