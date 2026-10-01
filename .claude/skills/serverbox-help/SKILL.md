---
name: serverbox-help
description: Help with using the ServerBox app itself — adding a server over SSH or through the ServerBox Monitor agent, why a button or feature is missing for a server, installing and configuring the Monitor agent on a server (permissions, TLS, alert rules), home-screen widgets, push alerts and the watch app, backups, the terminal, and the Agent's own settings (providers, tools, MCP servers, skills). Use it whenever the user asks how to do something in ServerBox, why something in the app is unavailable or failing, or wants the Monitor agent set up — including questions that never name the app, such as "why is there no terminal button", "how do I get alerts when CPU is high", or "can I see this on my watch".
---

# ServerBox help

ServerBox is the app this conversation is in. It manages Linux, BSD, macOS and
Windows servers: status and charts, a terminal, a file browser, containers,
processes, systemd, snippets. It runs on iOS, Android, macOS, Linux, Windows
and watchOS.

You are answering someone who **uses** the app, not someone building it. Talk
about screens and settings, not source files.

## How the app reaches a server

A server is reached over **SSH**, through the **ServerBox Monitor agent**'s
HTTP API ("Monitor HTTP"), or both. The two are configured independently in the
same server entry; with both, **Preferred transport** decides which is tried
first, and the other stays available.

| | SSH | Monitor agent |
|---|---|---|
| Needs something installed on the server | no (an SSH server) | yes, the agent |
| Status and charts | yes | yes, with history from before the app connected |
| Terminal, commands, processes, containers, systemd, snippets, power, firewall | yes | only if the account's role holds `shell`, over a secure transport |
| File browser | yes (SFTP) | only if the role holds `files` (read-only or writable) and the agent has a non-empty `[remote_access.fs] roots` |
| Port forwarding (local, dynamic, remote), remote desktop | yes | local, dynamic and remote desktop with the role's `connect` grant, remote forwards with `listen` (an agent older than the relay or the listener reports none: update it). Remote forwards bind loopback only unless the role's `listen` has `public` |
| SFTP transfers | yes | **never** — configure SSH for the same server too |
| Push alerts, home-screen widgets, watch app | no | yes, they read the agent with the app closed |

Recommend SSH unless there is a reason not to. The agent is the answer when the
SSH port cannot be reached from the phone, when charts should already be filled
in on open, or for alerts, widgets and the watch.

## "The button is missing"

The app only shows what the server can do. For a server reached **only**
through the agent, a missing terminal, command, container or process control
almost always means the account the app signed in with is not allowed it: its
role on the agent lacks the grant, which an admin of that agent changes from the
app or the web panel. An agent installed with `--permissions read` starts with
no grants at all.
Missing SFTP, or remote and dynamic forwards, means SSH is not configured for
that server. A greyed button says why when tapped or hovered.
It is a configuration answer, not a bug. Details and the fix:
`references/monitor.md`.

## Helping with the Monitor agent

You may be able to do this for the user: in the Agent tab you can run commands
on their servers, each one approved by them. Before you change an agent's
configuration or a role, say what the change allows and wait for a yes — a
role with `shell` makes that account's password worth a shell on that machine.
Never install the agent as root, and never grant access the user did not ask
for.
Everything needed is in `references/monitor.md`.

## Where things are in the app

`references/app.md` maps the settings, the Agent's own settings (providers,
tools, MCP, skills), backups, the terminal and the common problems.

## The documentation

The full documentation is at <https://serverbox.lollipopkit.com/docs/>, and in
Chinese under `/docs/zh/`. When a question goes past what is here and a web
fetch tool is available to you, read the page rather than answering from
memory; otherwise give the user the link.

| Topic | Page |
|---|---|
| Install the app | `/docs/installation/` |
| First steps | `/docs/quick-start/` |
| Monitor agent: install, permissions, alert rules, prompts for an AI | `/docs/advanced/monitor-agent/` |
| Widgets and the watch app | `/docs/advanced/widgets/` |
| The Agent (you): providers, tools, MCP, skills, approvals | `/docs/advanced/agent/` |
| Terminal on this device | `/docs/advanced/local-terminal/` |
| Common problems | `/docs/advanced/troubleshooting/` |
| Custom status commands | `/docs/advanced/custom-commands/` |
| Custom server logo | `/docs/advanced/custom-logo/` |
| Bulk import of servers | `/docs/advanced/bulk-import/` |
| Hidden settings (JSON editor) | `/docs/advanced/json-settings/` |
| Remote desktop | `/docs/advanced/remote-desktop/` |
| BMC (IPMI / Redfish) | `/docs/advanced/bmc/` |
| Themes | `/docs/advanced/theme-packages/` |
| What is sent where | `/docs/privacy/` |

## Reporting a problem

Recurring problems are collected in the wiki:
<https://github.com/lollipopkit/flutter_server_box/wiki>. A bug report goes to
<https://github.com/lollipopkit/flutter_server_box/issues> and should carry the
whole app log (the log button is at the top of the settings page) — check it
for server names and addresses the user would rather not publish first.
