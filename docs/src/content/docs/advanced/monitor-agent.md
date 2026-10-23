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

Do not install it as a root system service. Whoever signs in to the agent
may do what the account it runs as may do; as root, that is the whole
machine.

Do not add `full_access`, `listen_public`, `roots`, or an `enabled` key
under `[remote_access]` to config.toml. The agent does not read them: there
are no per-feature permissions to configure.

When you finish, report:
- the path of config.toml and of the SQLite database beside it
- the path of initial-admin-credentials.txt. Do not print what it contains.
- the address and port it listens on
- what `loginctl show-user <user> -p Linger` says. Without linger a --user
  service stops when I log out.
- the mode of config.toml and of the database. The config can hold push
  credentials and the database holds the agent's password hash, so neither
  should be group- or world-readable.
```

</details>

<details>
<summary>Prepare the machine for remote access</summary>

```text
Prepare the ServerBox Monitor agent on <host> for
<a terminal / file browsing / commands / port forwarding> from the app.

Before changing anything, explain the consequences and wait for my approval.

Keep these details in mind:

- There are no permissions to turn on. Whoever signs in to the agent may do
  what the system account it runs as may do. Do not move it to root to make
  something work; tell me what that account lacks instead.
- Everything beyond reading the numbers needs TLS or a loopback caller, and
  a reverse proxy on the same host counts. If the agent binds 127.0.0.1, or
  a same-host proxy terminates TLS, nothing more is needed. Only consider
  `[remote_access] allow_insecure = true` if the agent is reached directly
  over plaintext from another machine, and say so before you do.

Restart the agent after changing config.toml. Then tell me what you changed.
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

- The App offers what the agent reports. `GET /api/v1/capabilities` with a
  login shows `access`: `ok`, and when it is false, `why`.
  `insecure_transport` means it needs TLS or a loopback caller, or
  `[remote_access] allow_insecure`. The machine pages it serves are listed
  under `features`.
- Signing in allows what the system account the agent runs as may do. A
  command, file or port that account cannot reach fails.
- SFTP is never available through the agent: it needs SSH configured for
  the same server in the app.
- An agent older than the relay or the listener offers no port forwarding
  or remote desktop. Update it.
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
| Terminal, commands, and file browsing | Yes | Yes, as the account the agent runs as |
| SFTP transfers | Yes | No |
| Port forwarding (local, dynamic, remote) and remote desktop | Yes | Yes |
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

The agent runs as an ordinary user by default. Whoever signs in may do what that user may do, so the account the agent runs as sets the limit; see [Access](#access). Adding `--system` (with `sudo`) installs it as root instead, and signing in then means a root shell.

The agent reads `config.toml` from the directory beside its binary. See
[`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml)
for every available option. By default, the agent listens on `0.0.0.0:3770`.
If `frontend/dist` is present, it also serves the web panel from that address.

Collection intervals, alert rules, notification channels, data retention, and
allowed panel origins can be edited without opening `config.toml`. Use
**Server Settings** in the web panel, or open the server in the App and tap
the settings button in the top bar. Both interfaces update the same agent and
configuration file.

The JWT secret, `database_url`, and `[remote_access]` options (plaintext
tolerance, SSH address, and size limits) can only be changed in the
configuration file.

The editor never returns stored secrets such as ServerChan or Bark keys, an
iOS push token, an `Authorization` header, an SMTP password, a Telegram bot
token, a Discord webhook URL, or an ntfy token. It shows that each value is
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

### Upgrade

Run this on the server as the account the agent was installed from:

```sh
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sh -s -- upgrade
```

It installs the newest `monitor-v*` release and keeps `config.toml` and the
database. Without `--user` or `--system`, the installer finds the installed
form itself: a `systemctl --user` unit, a system unit, or an OpenRC service.
For the last two it runs itself again through `sudo`, which asks for the
password. When it finds no installation, as for an agent in Docker, it changes
nothing; for Docker, pull the new image and recreate the container.

The agent upgrades in place: the new files replace the old ones while it runs,
and it restarts last. So the command can run in a terminal the agent itself
opened; that terminal closes when the agent restarts, and the agent is back
within a few seconds.

#### Update from the panel or the App

The agent checks its releases every 12 hours and leaves a notification when a
newer one is out. It knows how it was installed: by `install.sh`, in a
container, by the NixOS module, or otherwise. Only the first can update itself;
the others are told how to update instead.

The update runs apart from the agent: under systemd as a transient service of
its own (`systemd-run`), elsewhere in a session of its own. The agent's restart
ends every connection through it, the panel's and the App's included, but not
the update. The output goes to `update.log` in the agent's directory, and the
agent that comes back reports how it went. Under OpenRC the installer needs
root, so the agent asks for the sudo password; it is used once and not saved.

- **Panel**: **Settings → Server → ServerBox Monitor** shows the version and
  the newest release, with **Check now** and **Update now**. While the update
  runs, the page shows its output, says when the agent is restarting, and shows
  the new version when it is back. Clicking the notification opens this page.
- **App**: the **Monitor** tab marks an agent with a newer release, and one too
  old for the App to sign in to. Tapping the mark opens the same steps with
  **Update now**. An agent too old to sign in to with the password alone still
  asks for an account name: the App asks for it (often `admin`), signs in once
  with it and the saved password, and starts the same update through that
  agent's command endpoint. The name is not saved. When the App reaches the
  server over SSH and the agent cannot start the update itself, the App runs the
  command in an SSH terminal, which the restart does not affect.

## How far back the App can ask

The available chart range depends on how long Monitor agent retains data and
how much history it has collected. The App shows only the ranges the agent can
provide. For API fields and history-query behavior, see
[Monitor agent API and access model](/docs/development/monitor-agent/).

## Panel credentials

The agent has one account, signed in with its password alone; there is no
username. The password is stored in the agent's SQLite database, not in
`config.toml`. The `jwt_secret` in that file signs session tokens; it is not a
password.

Run the commands below from the agent's working directory and as the account
that runs the service: `/opt/server-box-monitor` for a root-owned service, or
`~/.local/share/server-box-monitor` otherwise. Both `config.toml` and the
database path are relative to this directory. Running a command elsewhere
would create a new default configuration and empty database, then update a
database the service does not use.

### The first password

On its first start the agent sets a random password. The password is written
next to the database in `initial-admin-credentials.txt`, with mode 0600 on
Unix:

```sh
cd /opt/server-box-monitor
cat initial-admin-credentials.txt
```

Change the password and delete this file. If the database is later removed or
moved and has no account while the file remains, the agent stops instead of
overwriting the original credentials with a new set.

### Change or reset a password

```sh
cd /opt/server-box-monitor
./server_box_monitor password
```

The command prompts for the new password twice without displaying it. It
requires at least 8 characters. If the database has no account yet, the
command creates it.

To set the password from an environment variable, use the following in a
script or when you want to keep it out of shell history. This uses Bash or
Zsh: `read -s` is not available in POSIX `sh`. The check prevents a failed or
empty read from setting an empty password:

```bash
read -rsp 'Password: ' SBM_PW && echo
[ -n "$SBM_PW" ] || { echo 'no password entered' >&2; exit 1; }
SBM_PW="$SBM_PW" ./server_box_monitor password --password-env SBM_PW
```

The command deliberately has no password argument: command-line arguments
can appear in `ps` output and shell history.

A password change signs out everything else:

- **Logins and paired devices, at once, whichever way the password was
  changed.** Logins from before the change are refused from the next request,
  and paired widgets and Watch are unpaired. No restart is needed for this,
  and `jwt_secret` does not need to change.
- **Open terminals, port forwards and listeners, at once when the password is
  changed from the App or the panel.** The command above writes the database
  and cannot reach the running agent, so connections already open under the
  old password keep running until the agent restarts: `systemctl --user
  restart server_box_monitor`, or `rc-service server-box-monitor restart` on
  OpenRC. Restart it after a reset made because the password may be known to
  someone else.

The password can also be changed from the App (the server's settings button,
then **Access**) or the panel; both ask for the current password. Changing it in the App updates the password the App has
saved for that server.

After changing the password on the server, update **Monitor Password** in the
App and replace it in any other client that uses it. Clients are not notified
about password changes and cannot sign in until their saved credentials are
updated.

### A forgotten password

There is no password recovery flow in the panel. Reset the password on the
server with the command above.

Login attempts are rate-limited. Each sign-in gives the App or the browser a
device token, sent with every later sign-in. A device that has signed in
before is limited by its source address and on its own, so failed attempts
from anywhere else cannot lock it out; any other client is limited by its
source address and by a counter all of them share. Per address and per device,
the first three failures have no delay; the shared counter allows twenty.
After that, the delay doubles from one second up to five minutes. A forgotten
password may therefore make the agent appear slow or unresponsive. Changing
the password forgets every device.

## Add it in the App

1. Tap **+** to add a server.
2. Enable **Monitor HTTP**. This connection is independent of SSH, so you can
   enable either transport or both. If both are enabled, set **Preferred
   transport** to choose which one the App tries first.
3. Enter:
   - **URL**: for example, `https://1.2.3.4:3770`
   - **Monitor Password**: the agent's password — see [Panel credentials](#panel-credentials)
   - **Monitor Ignore certificate**: enable only for a self-signed certificate
4. Save the configuration.

Monitor HTTP does not configure SSH credentials. With no SSH connection, the
App can reach the server only through capabilities that Monitor agent exposes.

## The Monitor tab

The App's **Monitor** tab shows every server added through the Monitor agent.
A fresh install does not put the tab in the bar: open it from **More**, or add
it under **Settings › Application › Home Tabs**. On a wide window the sections
and the servers are in a column on the left; on a phone the section is picked
from the bar's title and the server from its server button.

- **Overview**: each agent, whether it answers, its version (with the newest
  release when it is older), the [alert rules](#alert-rules) firing now with
  the reading and how long they have fired, and shortcuts to unread
  notifications and to web apps that are down or have an update.
- **Web apps**: see [Monitor web apps](../monitor-apps/#open-apps-from-the-serverbox-app).
- **Notifications**: what the agents reported, newest first, in the App's
  language: a rule that started firing, a web app down, back or with an
  update, a disk, array or pool in trouble. Read state is shared with the panel.
- **Audit log**: one server at a time. Sign-ins (accepted and refused, with the
  address), terminals, commands, file writes, machine management, deployments
  and the rest, filtered by type and result. It is shown only over a link the
  agent lets act (HTTPS, loopback, or `allow_insecure`).
- **Sessions & devices**: one server at a time. Terminal sessions,
  connections relayed through the agent (forwarded ports, desktops, consoles),
  watch and widget tokens, and the devices that signed in with the password.
  A session or connection can be ended and a token revoked. Forgetting a device
  makes its next sign-in count against the account-wide limit on failed
  attempts; it does not sign the device out, since a device that has the
  password signs in again. To keep a device out, change the password.

An agent older than a section says so instead of showing it.

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
<a id="accounts-and-permissions"></a>

## Access

Signing in to the agent allows what the operating-system account the agent
runs as may do: commands, processes, systemd, containers, snippets, power,
scheduled tasks, the firewall, the terminal, files, remote desktop, port
forwarding, and the web panel's Proxmox VE, libvirt and BMC pages. There are
no roles or per-feature permissions; that account is the limit.

The installer therefore runs the agent as an ordinary user by default. With
`--system` it runs as root, and signing in then means a root shell. To limit
what the agent can reach, install it as an account that can reach only that.

Whatever that account can reach, the file API never serves the agent's own
files — its database, `jwt.secret`, `credentials.key`, `config.toml` and its
backups, `.env`, the TLS key and certificate, and the custom commands — since
they hold credentials.

The credentials the agent stores (BMC and Proxmox VE passwords, Agent mode
provider keys, MCP tokens, the WebDAV password) are encrypted in the database
with `credentials.key`, kept beside it. Copy the two together when moving the
agent by hand; without the key, those credentials have to be entered again. A
settings backup does not need the key.

### Upgrading from an agent with several accounts

Earlier agents had several accounts, with roles and grants. On upgrade the
oldest admin account's password becomes the agent's password. The other
accounts' Agent mode tasks, memory and desk themes move to it; their desk
layout, windows and paired watches are removed. Roles and grants are not
carried over.

The `config.toml` keys of that model — `full_access`, `listen_public`,
`[remote_access.terminal] enabled`, `[remote_access.fs] enabled`, and
`[remote_access.fs] roots` — are not read and can be deleted.

### Plaintext HTTP

Everything beyond reading the numbers needs HTTPS or a caller on the same
host, which includes a reverse proxy there. On a private network that already
encrypts traffic, such as Tailscale, set `[remote_access] allow_insecure =
true` and enable **Allow insecure HTTP** for this server in the App; both are
required. TODO: Remove the legacy `allow_insecure` keys when existing
configurations no longer need them. Until then, `[remote_access.terminal]
allow_insecure` and `[remote_access.fs] allow_insecure` count as
`[remote_access] allow_insecure`.

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

## Notification channels

A `[[push]]` entry has a `name`, a `push_type` and that type's settings.
`{{message}}` and `{{name}}` (this server's name) are replaced in the text
fields. Every type is listed in
[`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml).

| `push_type` | Required | Optional |
| --- | --- | --- |
| `webhook` | `url` | `method`, `headers`, `body_template` |
| `serverchan` | `sc_key` | `title`, `desp` |
| `bark` | `key` | `server`, `title`, `subtitle`, `body`, `markdown`, `level`, `volume`, `badge`, `sound`, `icon`, `image`, `group`, `url`, `copy`, `auto_copy`, `call`, `is_archive`, `ttl`, `action`, `cipher_key` |
| `ios` | `token` | `title`, `content` |
| `smtp` | `host`, `from`, `to` | `port`, `security`, `username`, `password`, `subject`, `body` |
| `telegram` | `bot_token`, `chat_id` | `text`, `parse_mode`, `message_thread_id`, `disable_notification`, `disable_link_preview`, `api_base` |
| `discord` | `webhook_url` | `content`, `username`, `avatar_url`, `thread_id` |
| `ntfy` | `topic` | `server`, `title`, `message`, `priority`, `tags`, `click`, `icon`, `attach`, `delay`, `email`, `markdown`, `token`, `username`, `password` |

- **Credentials from the environment**: in `config.toml`, a credential
  (`sc_key`, Bark `key` and `cipher_key`, iOS `token`, a webhook header value,
  SMTP and ntfy `password`, ntfy `token`, `bot_token`, `webhook_url`) may name
  an environment variable as `${NAME}`, alone or inside the value
  (`Authorization = "Bearer ${HA_TOKEN}"`); `$${` writes a literal `${`. It is
  read when a notification is sent, from the agent's environment or its
  `.env`; `config.toml` keeps the reference. A channel whose variable is unset
  or empty is refused on save and fails to send, naming the variable. Other
  settings are not expanded. A credential entered in the App or the web panel
  is taken as typed, never as a reference: signing in does not give access to
  the agent's environment.
- **Bark**: with `cipher_key` set, the notification is encrypted with AES-CBC
  (a 16, 24 or 32 character key for AES-128/192/256). Enter the same key and
  algorithm under Push Encryption in the Bark app. Only the device key and the
  ciphertext reach the Bark server.
- **SMTP**: `security` is `starttls` (port 587, the default), `tls` (465) or
  `none` (25). With `none`, a password is accepted only for a server on the
  same machine. `to` takes several addresses, comma-separated.
- **Telegram**: with `parse_mode`, the message and the server name are escaped
  for that mode, so only your own `text` is read as markup.
- **Discord**: mentions in the text, such as `@everyone`, do not notify
  anyone.

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
| `disk` | Ignored | Percent used across this machine's filesystems; NFS, SMB and similar count only with `disk_counts_network = true` under `[monitoring]` (also in Monitor settings) |
| `network` | `rx` or `in` | Receive speed |
| `network` | `tx` or `out` | Transmit speed |
| `network` | Blank or anything else | Receive plus transmit |
| `temperature` | Ignored | The reading the agent reports as the machine's temperature |

TODO: Remove the Go-agent aliases after the migration window. Configurations
migrated from Go may use `mem`, `net`, and `temp`; other unknown metrics are
logged once per cycle and their rules do not fire.

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

**A feature is missing or greyed out.** The App offers what the agent
reports. Everything beyond reading the numbers needs HTTPS or a caller on the
same host; see [Plaintext HTTP](#plaintext-http). An agent older than a
feature does not report it; update the agent. Restart the agent after editing
`config.toml`.

**An action fails with a permission error.** The agent acts as the
operating-system account it runs as, and cannot reach what that account
cannot. See [Access](#access).

**Certificate errors.** Configure valid TLS, put the agent behind a reverse proxy, or enable **Monitor Ignore certificate** for that server.

**The panel uses a different origin.** Add that origin to
`cors_allowed_origins` in `config.toml` or the `SBM_CORS_ORIGINS` environment
variable.

**Login is rejected, or the password is lost.** Reset it on the server with `server_box_monitor password`; see [Panel credentials](#panel-credentials). Repeated failures are throttled, so a wrong password can also present as a slow or unresponsive agent.

**A request gets no response.** Confirm that the agent is running and its
port is reachable. Then inspect the database's `access_log` table, which
records the visitor, time, source, requested resource, and result without
storing credentials.
