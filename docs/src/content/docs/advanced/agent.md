---
title: Agent
description: Ask a model to diagnose servers and review each action before it runs
---

Agent connects a language model to your servers. It suggests an action, shows
you what it plans to do, and runs it only after you approve.

Before the first message, add a provider at **Settings → App → AI →
Providers**: pick one of the built-in providers (OpenAI, Anthropic, Google and
others from the model catalog) and enter its API key, or add a custom
OpenAI-compatible, Anthropic or Google endpoint. The same page chooses the
model a new chat uses. API keys are stored in the system keychain, not in the
App's database, and are sent only to their own provider. A request is sent only
when you send a message.

## Choose an Agent

Server Box has two Agent entry points:

- **Agent tab** can work across configured servers. It can also open a
  temporary SSH connection to a host that is not in your server list, and read
  App state such as the list of servers and their connection status.
- **SSH Agent** is available from a terminal session. It works with the
  current server: it can read what the terminal shows and run commands on its
  connection. If you select terminal output and choose **Ask AI**, a new chat
  starts with that text in the message box, for you to add your question.

Each has its own chat list: a terminal's chats belong to that server. The
Agent tab can stay above other tabs while you work in the terminal or file
browser — use the float button in its header.

## Providers and models

**Settings → App → AI → Providers** lists the built-in providers and your
custom ones. For a custom provider, enter its base URL including the API
version (for example `https://api.example.com/v1`) and pick its protocol:
OpenAI Chat Completions, OpenAI Responses, Anthropic Messages or Google
Generative AI. For an OpenAI-compatible endpoint the App lists the models it
offers; otherwise enter the model IDs.

A custom provider at a plain `http://` address on another machine is refused
unless you turn on **Allow plain HTTP** for it, because the API key would be
sent unencrypted. `http://localhost` and other addresses on this device do not
need it.

Settings from an earlier version — endpoint, model, protocol and key — were
moved to a custom provider when you updated, and the key to the keychain.

## What Agent can do

The Agent tab's tools:

| Tool | Behavior |
|---|---|
| **Shell** | Runs a complete, non-interactive command on a server |
| **Read file** | Reads a text file from an SSH server over its configured SFTP or SCP transport; with local execution enabled, it can read a local file too |
| **Write file** | Replaces a text file over the configured transport; with local execution enabled, it can replace a local file too |
| **SSH connect** | Opens a temporary connection to a host not configured in the App |
| **Disconnect SSH** | Closes a temporary SSH connection |
| **Server Box** | Reads App state, including the server list and connection status |
| **Memory** | Keeps notes on this device that later chats can read |
| **Chat history** | Searches and reads your earlier Agent chats |
| **Web fetch** | Reads a web page, from this device |

A terminal's chats have only two: **Shell**, which runs in that terminal's
connection, and **Read the screen**. Tools can be switched off by group at
**Settings → App → AI → Tools**, where you can also add MCP servers, whose
tools the Agent tab then offers too.

Tap a server to edit it. One (Streamable HTTP) that wants a key takes it as
headers, a name and a value each, such as `Authorization` with
`Bearer <token>`. One that uses OAuth shows **Sign-in required**; **Log in**
opens the browser, and the App keeps the token and renews it. Headers and tokens stay on this device and are not backed up, and
are sent only over `https` unless the server is on this device.

## Skills

A skill is a set of instructions for a particular task — a `SKILL.md` and
any files beside it. Install one at **Settings → App → AI → Skills** from the
same sources `npx skills add` takes: `owner/repo`, `owner/repo@skill`, a
GitHub or GitLab link (to a repository or a folder in it), a link to a
`SKILL.md` or an archive, or a site that publishes a `/.well-known` skills
index. A whole `npx skills add …` command can be pasted as it is. A folder
or a `.zip` on this device can be installed too, from the buttons below the
field or by entering its path. When a
source has several skills, you pick which to install.

The model sees each skill's name and description, and loads the rest when a
task matches it; loading one needs no approval. Skills are separate from
tools: turning tools off leaves them on, and each can be switched off on its
own. A terminal's chats get them too. The model follows what a skill says,
so install only from sources you trust; scripts in a skill do not run by
themselves. **Check for updates** fetches each source again and replaces
the skills that changed.

Agent's file tools require SSH. A server configured only with Monitor HTTP does
not provide these tools. Its separate **File** tab can use the Monitor agent
file API when the operator enables `[remote_access.fs]` and the requested path
is under `roots`.

## Review actions

Before a server action runs, the App shows the command, how risky it looks and
the model's explanation of it. Read the command yourself, then allow or deny
it. A denial is sent back to the model so it can respond to your feedback. In
a terminal's chat you can also insert the command into the terminal, to edit
and run it yourself. The model's safe or unsafe label is only a hint for your
review.

Server actions are asked about every time; there is no "always allow" for
them. At **Settings → App → AI**, **Auto-run read-only commands** lets a server
command run without asking only when both the model and the App's local check
classify it as read-only, idempotent and non-destructive, and then at most three
times for one message. It is off by default and never applies to commands on
this device. For the other tools, "always allow" is offered on the approval
card and can be undone at **Tools**.

## Connect to another host

Agent can open a temporary SSH connection to a host outside your server list.
If it needs a password, the App asks for it in a separate dialog; do not enter
the password in the conversation. Conversation text is saved on the device and
sent to the provider. Temporary connections are listed separately. To keep one,
save it as a server; its host information and password are then stored like
your other server credentials.

## Run commands on this device

**Run commands on this device** is a separate option at **Settings → App → AI**
and is off by default. Enabling it does not allow unattended commands: every
local command requires your confirmation, even if it appears read-only or
**Auto-run read-only commands** is enabled.

The command target depends on the platform:

- **Desktop:** the computer running Server Box, including its files.
- **Android and iOS:** the Alpine Linux environment provided by the App. It
  cannot access the phone's own filesystem, App data, or user files. See
  [Terminal on This Device](/docs/advanced/local-terminal/).

The option is hidden on platforms that cannot run local commands. The
App Store build of macOS cannot start a shell because it is sandboxed. An iOS
build without the Linux engine cannot provide local command execution either.

## Conversation history

Chats are stored on the device, in the App's encrypted database, and long ones
are summarised as they grow. You can reopen, rename and delete them from the
history list. They are not included in backups or synced, and neither are your
providers, tool settings and memory notes. Messages and tool results can
contain command output, file contents and any terminal text you pasted; they
are sent to the provider when used in a chat.

## Before you send a message

- Models can produce incorrect advice or commands. Review every action before
  approving it.
- Command output, requested file contents, terminal text and fetched pages may
  be sent to the provider so the model can analyze them. Check for sensitive
  data before sending a message or approving a tool action.
