---
title: Agent
description: Ask a model to diagnose and operate your servers, one reviewed action at a time
---

The Agent connects a language model to configured servers and can open temporary SSH connections to other hosts.
It proposes one action at a time and waits for you to review it.

It is off until you give it an API endpoint and key. There is no default
provider, and nothing is sent anywhere before that.

## Two places it appears

**The Agent tab** works across every server you have configured. It can open its
own SSH connections to hosts that are not on the list, and read ServerBox's own
state to answer questions like which servers are down.

**The SSH Agent** lives in the terminal page and works on that one server. It
sees the terminal's context. Select some output and ask what happened, and the
selection goes with the question.

The Agent tab can also float over the other tabs, so a diagnosis can stay on
screen while you work in the terminal or the file browser. Settings → **App** →
AI → **Float over other tabs**.

## Setup

Settings → **App** → **AI**:

| Setting | Default |
|---|---|
| **API endpoint** | `https://api.openai.com` |
| **Model** | `gpt-5.4-mini` |
| **API key** | empty |
| **Protocol** | Auto |

The endpoint takes either a service base URL or a full Chat Completions or
Responses endpoint. The app completes the path for the protocol in use. **Auto**
picks Responses for the official OpenAI endpoint and Chat Completions for
compatible providers, so most third-party gateways work without changing it.

Any provider speaking either protocol works. The key is stored on the device in
the same encrypted store as your server passwords.

## What it can do

| Tool | What it does |
|---|---|
| **Shell** | Run one complete, non-interactive command |
| **Read file** | Read a text file over SFTP |
| **Write file** | Replace a text file over SFTP, after review |
| **SSH connect** | Open a connection to a host that is not configured |
| **Disconnect SSH** | Close one of those |
| **ServerBox** | Read the app's own state, including which servers exist and their status |

## Review and approval

Every action the model proposes is shown before it happens, with the command and
a description of the action and its risks. You approve or decline. Declining
tells the model so, and it continues from there.

**Auto-run read-only commands** (Settings → App → AI) lets clearly read-only,
idempotent commands run without a prompt. It is **off by default**, and it
applies to servers only.

The model marks each action as safe or not, and that marking is an input to the
decision, not the decision. Read the command.

## Connecting to a host that is not configured

The Agent can open an ad-hoc SSH connection. When it needs a password, the app
asks you in a dialog, **never in the conversation**, because anything typed
there is stored with the conversation and sent to the model.

Those connections are temporary and listed separately. If one turns out to be
worth keeping, save it as a server; the host and the password you typed are then
stored on the device like any other.

## Running commands on this device

Separate from everything above, and **off until you turn it on**: Settings →
App → AI → **Run commands on this device**.

A server was added deliberately and is somewhere else. This machine is where the
app's own data, your private keys and your keychain live, and nobody opted into
a model touching those by adding a server. So this is its own switch, and
**nothing here ever runs unattended.** Every command needs review no matter how
read-only it looks, whatever the auto-run setting says.

What "this device" means depends on the platform:

- **Desktop**: the computer itself, with your files on it
- **Android and iOS**: the Alpine Linux container ServerBox installs, which
  cannot see the phone's own filesystem, the app's data or your files. See
  [Terminal on This Device](/docs/advanced/local-terminal/)

The switch is absent where it could not be honoured. The sandboxed macOS build
from the App Store cannot start a shell at all, and neither can an iOS build
with no Linux engine.

## History

Agent tab conversations are saved on the device and can be reopened. Clear them
all from the conversation history screen.

## Important behavior

- **The model can be wrong.** The app says so on every conversation, and the
  review step exists because of it.
- **Command output goes to the model.** That is how it works. Anything
  you select in the terminal and ask about. Consider what is on screen.
- **One action at a time.** The Agent does not queue up a plan and execute it;
  it proposes, waits, and continues from the result.
- **Enter sends by default.** Shift+Enter starts a new line. Settings → App →
  AI → **Send on Enter** swaps them.
