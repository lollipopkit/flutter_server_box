---
title: Agent
description: Ask a model to diagnose and operate your servers, one reviewed action at a time
---

Agent connects a language model to the servers you configure. The model proposes one action at a time, and the App asks you to review it before execution.

Agent ships with a default API endpoint and model, so it is ready to use without being configured first; change either in settings to use a different provider. Only providers that require authentication need an API key; when configured, the App sends it as a bearer token. A request is what reaches the provider — nothing is sent until you send a message.

## Two entry points

**The Agent tab** works across the servers configured in the App. It can open temporary SSH connections to hosts that are not in the server list, and it can read Server Box's own server state—for example, to answer which servers are offline.

**SSH Agent** appears in the terminal page and works with the current server. It can read the terminal context. If you select terminal output and ask a question, the selected text is sent with the question.

The Agent tab can float above other tabs, so you can keep a diagnosis visible while working in the terminal or file browser. Open **Settings → App → AI → Float over other tabs**.

## Configuration

Open **Settings → App → AI**:

| Setting | Default |
|---|---|
| **API endpoint** | `https://api.openai.com` |
| **Model** | `gpt-5.6-luna` |
| **API key** | Empty |
| **Protocol** | Auto |

The endpoint can be a service base URL or a complete Chat Completions or Responses endpoint. The App completes the path for the selected protocol. **Auto** uses Responses for the official OpenAI endpoint and Chat Completions for compatible providers, so most third-party gateways work without additional changes.

Any provider that supports one of these protocols can be used. The API key is stored on the device in the same encrypted store as server passwords.

## Available tools

| Tool | What it does |
|---|---|
| **Shell** | Runs a complete, non-interactive command |
| **Read file** | Reads a text file from an SSH server using its configured file transport (SFTP or SCP); with local execution enabled, it can also read a local file |
| **Write file** | Replaces a text file using its configured file transport; with local execution enabled, it can also replace a local file, and every write requires confirmation |
| **SSH connect** | Connects to a host that is not configured in the App |
| **Disconnect SSH** | Closes a temporary SSH connection |
| **Server Box** | Reads the App's own state, including the server list and connection status |

## Review and approval

Every action proposed by the model is shown before execution, including the command and the model's description of its purpose and risks. You can approve or reject it. A rejection is returned to the model so it can continue with that information.

**Auto-run read-only commands** is available at **Settings → App → AI**. When enabled, the App can run commands that are explicitly read-only and idempotent without asking each time. It is off by default and applies to servers only.

The model labels each action as safe or unsafe. The label is an input to your decision, not a replacement for reading the command yourself.

Servers configured only through Monitor HTTP do not provide Agent's SFTP file tools, because those tools require SSH. Their separate **File** tab can use Monitor agent's `/api/v1/fs/*` file API when the operator enables `[remote_access.fs]` and the path is within `roots`.

## Connecting to an unconfigured host

Agent can open a temporary SSH connection. When it needs a password, the App asks for it in a separate dialog, **never in the Agent conversation**. Text entered in the conversation is stored with the conversation and sent to the model.

Temporary connections are listed separately. If you want to keep one, save it as a server. The host information and password are then stored on the device like other server credentials.

## Running commands on this device

**Run commands on this device** is independent of server operations and is off by default. Find it at **Settings → App → AI → Run commands on this device**. On desktop, the target is the computer itself. On mobile, the target is the Alpine Linux environment provided by the App.

Adding a server does not grant the model access to the device: the device contains the App's data, private keys, and keychain. Even after local execution is enabled, **no local command runs unattended**. Every local command requires confirmation, regardless of whether it appears read-only or the auto-run setting is enabled.

- **Desktop**: the computer running Server Box, including its files
- **Android and iOS**: the App-provided Alpine Linux environment, which cannot see the phone's own filesystem, App data, or user files. See [Terminal on This Device](/docs/advanced/local-terminal/).

The switch is not shown on platforms that cannot provide local execution. The sandboxed App Store macOS build cannot start a shell, and an iOS build without the Linux engine cannot provide this feature either.

## History

Agent tab conversations are stored on the device. You can reopen them or clear all of them from the conversation history screen.

## Important behavior

- **The model can be wrong.** The App states this in each conversation; review before execution is the safety step for that reason.
- **Command output is sent to the model.** This is required for analysis. Selected terminal output is sent as well, so check the visible content before submitting it.
- **One action at a time.** Agent does not queue and execute a complete plan. It proposes an action, waits for the result, and then continues.
- **Enter sends by default.** Shift+Enter starts a new line. Change this at **Settings → App → AI → Send on Enter**.
