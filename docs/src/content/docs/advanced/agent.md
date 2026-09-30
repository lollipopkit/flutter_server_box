---
title: Agent
description: Ask a model to diagnose servers and review each action before it runs
---

Agent connects a language model to your servers. It suggests an action, shows
you what it plans to do, and runs it only after you approve — unless you let
read-only commands run by themselves (see [Review actions](#review-actions)).

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
Agent floats above the other tabs while you work in the terminal or file
browser, so what it does elsewhere in the App stays in view; turn that off
with the float button in the Agent tab's header.

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

A built-in provider with no key entered uses one from the environment the App
was started with, under the variable that provider's tools use —
`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` and so on — and the
provider list shows it under **System**, with the variable it came from. A key
entered in the App takes its place.

`OPENAI_BASE_URL` adds a provider of its own, **System**: an OpenAI-compatible
endpoint at that address, with `OPENAI_API_KEY` as its key and `OPENAI_MODEL`
as a model it may not list. `OPENAI_API_KEY` is then that endpoint's alone —
the built-in OpenAI provider does not send it to api.openai.com — unless the
address is OpenAI's own. Nothing of it is stored; it is whatever the App was
started with. A plain `http://` address on another machine is refused, as for
any provider. This is for a desktop App started from a shell: on macOS, an App
opened from Finder or the Dock does not see what your shell profile exports.

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
| **Snippets** | Lists your snippets, and adds, changes or deletes them — changes ask first. It never sets a snippet to run by itself on a server |
| **Virtualization** | Reads the VMs and containers the Virtualization tab has loaded; a host not loaded yet is left alone |
| **Benchmark** | Reads benchmark results, and runs or stops a benchmark — asking every time. A run takes 10 to 20 minutes; when it ends, the chat that started it is told, and the Agent reads the result |
| **Remote desktop** | Lists remote desktop profiles, and connects (on the Remote desktop tab) or disconnects one, asking first. A profile without a saved password is connected from the App |

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
themselves. Once a day, at launch or when you open the Skills page, the App
asks each source whether its skills changed and marks the ones that did;
**Update all** installs them, and **Check for updates** asks right away.
Nothing is installed without you.

One skill comes with the App: **serverbox-help**, on how to use Server Box and
run Monitor agent, so the Agent can answer questions about the App itself —
and set Monitor agent up on a server, with your approval. It is updated with
the App and can be switched off, but not removed.

Agent's file tools require SSH. A server configured only with Monitor HTTP does
not provide these tools. Its separate **File** tab can use the Monitor agent
file API when the operator enables `[remote_access.fs]` and the requested path
is under `roots`.

## Review actions

Before a server action runs, the App shows the command, how risky it looks and
the model's explanation of it — except a read-only command that auto-runs (see
below), which runs without a prompt. Read the command yourself, then allow or deny
it. A denial is sent back to the model so it can respond to your feedback. In
a terminal's chat you can also insert the command into the terminal, to edit
and run it yourself. The model's safe or unsafe label is only a hint for your
review.

Server actions that do not auto-run are asked about every time; there is no
"always allow" for them. At **Settings → App → AI**, **Auto-run read-only commands** lets a server
command run without asking only when both the model and the App's local check
classify it as read-only, idempotent and non-destructive, and then at most three
times for one message. It is off by default and never applies to commands on
this device. For the other tools, "always allow" is offered on the approval
card and can be undone at **Tools**.

## When the Agent asks you

The Agent can ask you in the conversation — a choice that is yours, or
something it cannot find out itself — and waits until you submit or cancel.
It asks up to four questions, each with a few options and what they mean,
one or several to pick; **Other** is always there for an answer of your own.
It can also ask for things to type in. The bar, the chat list and the floating pill mark a chat
waiting on you with a dot, apart from the spinner of one that is working.
Sending a message instead cancels the form, and your message goes to the Agent
with it.

A password, key or token is asked for in a secret field. What you type there
never reaches the model or the chat history: the Agent gets a one-time handle,
which the App trades for the value when a tool needs it — connecting a remote
desktop whose profile keeps no password, for example.

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
