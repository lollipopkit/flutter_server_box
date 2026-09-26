---
title: Agent
description: Ask a model to diagnose servers and review each action before it runs
---

Agent connects a language model to your servers. It suggests one action at a
time and shows you what it plans to do before running it. You can approve or
reject each action.

Agent includes a default API endpoint and model, so you can use it without
setting up a provider first. To use another provider, change the endpoint,
model, protocol, or API key in **Settings → App → AI**. An API key is needed
only for providers that require authentication. The App sends a configured key
as a bearer token and stores it in the same encrypted database as server
passwords. A request is sent only when you send a message.

## Choose an Agent

Server Box has two Agent entry points:

- **Agent tab** can work across configured servers. It can also open a
  temporary SSH connection to a host that is not in your server list, and read
  App state such as the list of servers and their connection status.
- **SSH Agent** is available from a terminal session. It works with the
  current server and can use the terminal context. If you select terminal
  output before asking a question, that text is sent with your message.

The Agent tab can stay above other tabs while you work in the terminal or file
browser. Enable **Settings → App → AI → Float over other tabs**.

## Configure a provider

Open **Settings → App → AI** to configure the provider:

| Setting | Default |
|---|---|
| **API endpoint** | `https://api.openai.com` |
| **Model** | `gpt-5.6-luna` |
| **API key** | Empty |
| **Protocol** | Auto |

For **API endpoint**, enter either the service's base URL or a complete Chat
Completions or Responses endpoint. The App fills in the endpoint path for the
selected protocol. **Auto** selects Responses for the official OpenAI endpoint
and Chat Completions for compatible providers. Most third-party gateways work
without additional protocol settings. The provider must support at least one of
these protocols.

## What Agent can do

| Tool | Behavior |
|---|---|
| **Shell** | Runs a complete, non-interactive command on a server |
| **Read file** | Reads a text file from an SSH server over its configured SFTP or SCP transport; with local execution enabled, it can read a local file too |
| **Write file** | Replaces a text file over the configured transport; with local execution enabled, it can replace a local file too. Every write requires confirmation. |
| **SSH connect** | Opens a temporary connection to a host not configured in the App |
| **Disconnect SSH** | Closes a temporary SSH connection |
| **Server Box** | Reads App state, including the server list and connection status |

Agent's file tools require SSH. A server configured only with Monitor HTTP does
not provide these tools. Its separate **File** tab can use the Monitor agent
file API when the operator enables `[remote_access.fs]` and the requested path
is under `roots`.

## Review actions

Before an action runs, the App shows the command and the model's explanation of
its purpose and risks. Read the command yourself, then approve or reject it. A
rejection is sent back to the model so it can respond to your feedback. The
model's safe or unsafe label is only a hint for your review.

At **Settings → App → AI**, **Auto-run read-only commands** can run server
commands without asking each time only when both the model and the App's local
check classify the command as read-only. The command must also be idempotent
and non-destructive. This option is off by default and does not apply to
commands on this device. Agent handles one action at a time: it waits for each
result before proposing the next action.

## Connect to another host

Agent can open a temporary SSH connection to a host outside your server list.
If it needs a password, the App asks for it in a separate dialog; do not enter
the password in the conversation. Conversation text is saved on the device and
sent to the configured model. Temporary connections are listed separately. To
keep one, save it as a server; its host information and password are then stored
like your other server credentials.

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

Agent tab conversations are stored on the device. You can reopen them or clear
all conversations from the history screen. Messages and tool results can
contain command output, file contents, and any terminal text you selected; they
are sent to the configured model when used in a conversation.

## Before you send a message

- Models can produce incorrect advice or commands. Review every action before
  approving it.
- Command output, requested file contents, and selected terminal text may be
  sent to the provider so the model can analyze them. Check for sensitive data
  before sending a message or approving a tool action.
- Press **Enter** to send by default; **Shift+Enter** starts a new line. Change
  this under **Settings → App → AI → Send on Enter**.
