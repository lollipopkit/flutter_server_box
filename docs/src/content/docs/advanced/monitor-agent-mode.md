---
title: Monitor Agent Mode
description: Run an AI agent on a server from the Monitor panel, with permission modes, MCP servers, and skills
---

Agent mode is an AI agent in the Monitor panel. It runs commands on the machine
where the Monitor agent runs, as the system account the agent runs as.

Agent mode is a feature of the panel. The mobile app's
[Agent](/docs/advanced/agent/) is a separate feature with its own settings.
To install the Monitor agent, see [Monitor Agent](/docs/advanced/monitor-agent/).

## Settings

Open **Settings → Agent** in the panel to change the model, providers, MCP
servers, skills, and memory.

### Model and providers

Agent mode needs a model before it can run a task. Under **Providers**, select
a built-in provider and enter its **API key**. To use another endpoint, select
**Add a provider**. Set its **Name**, **Base URL**, and **API**. The API is one
of OpenAI Chat Completions, OpenAI Responses, Anthropic Messages, or Google
Generative AI.

The panel lists the models that an endpoint offers. If an endpoint does not
list its models, enter their IDs under **More model IDs**.

API keys are write-only. The panel shows only whether a key is set. To replace
a key, enter a new one. To keep the current key, leave the field empty. To
remove it, select **Remove the key**.

Under **Model**, choose the default model for new tasks. Select **None (Agent
mode off)** to stop Agent mode from running tasks.

A base URL that uses plain `http://` is accepted only for a loopback address,
such as `127.0.0.1`. For another address, turn on **Allow plain HTTP** for that
provider. The key and every prompt then travel unencrypted. Redirects are not
followed.

### Task defaults

- **Tasks at once** sets how many tasks run at the same time, from 1 to 8.
  Other tasks wait in the queue.
- **Thinking** sets the default thinking level: Off, Low, Medium, or High.
- **Copy tasks for pi** is off by default. See [Copy for pi](#copy-for-pi).

## Tasks

Open **Agent mode** in the desk. Describe what to do in the composer and send
it. The agent then runs commands on the server to complete the task.

Before a change, the agent lays out a plan. Select **Run** to approve the plan.
Select **Change the plan** to tell the agent what to change first.

### Attachments

Use **Add attachment**, drag files into the composer, or paste them. A task
accepts up to 10 files, 20 MB each. The agent receives the name, type, size,
and path of each file. Text files up to 16 KiB are included in the prompt.
Images up to 5 MB are sent to the model as images. An attachment that is not
sent with a task is removed after one hour.

### Model and thinking level

Each task has its own **Model** and **Thinking** level. Choose them in the
composer. The list shows the models of custom endpoints and of built-in
providers with a key set. If you change them while a task runs, the change
applies from the next request to the model.

### Permission mode per task

Each task has a permission mode. Choose it in the composer, or press Shift+Tab
to switch it. The mode applies to the task and is set when the task starts.
See [Permission modes](#permission-modes).

### Queue

At most **Tasks at once** tasks run together. A task that starts while the
limit is reached shows **Queued**. It starts when a task ahead of it ends.

### Reply

When a task finishes, type a reply in the reply box to continue it. The reply
runs in the same session, so the agent keeps the earlier context. You can also
add to a task while it runs.

### Stop and delete

Select **Stop** to end a running task. The command it is running stops with
the rest of its process group. Select **Delete** to remove a task. Deleting a
task also deletes its copy for pi, if one exists.

### Command time limit

Each command has a time limit, which the model sets for that command. The
limit is from 1 to 120 minutes. The default is 10 minutes. When a command
reaches its limit, the command and the processes it started are stopped.

### Output

Output appears as the command runs. A long output keeps its first 2000 and last
8000 lines. The model reads the last 12 000 characters of a command's output.

### Offline panel

If the panel loses its connection, tasks keep running on the server. The output
resumes when the panel reconnects.

## Permission modes

Each task runs in one of three permission modes. The mode decides what runs
without a question, after the command rules apply.

| Mode | Behaviour |
| --- | --- |
| Manual | Commands follow the command rules. A command that no rule matches waits for your confirmation. |
| Auto | The model judges each such command against the auto mode rules. An allowed command runs. A refused command stops, and the agent receives the reason. With no verdict, you are asked. |
| Allow all | Every command runs without a question, including deleting, restarting, and config changes. Deny and ask rules still apply. |

The default mode for new tasks is set under **Settings → Agent → Command
permissions → Default mode**.

You can select **Turn off Allow all** on that page. After that, no task
runs in Allow all. A task that was started in Allow all then runs as Manual.

## Command rules

Set the rules under **Settings → Agent → Command permissions**. There
are three lists: **Deny**, **Ask**, and **Allow**. Write one pattern per line.

- `*` matches any text. For example, `systemctl status *` matches every
  `systemctl status` command.
- A trailing `:*` has the same meaning as ` *`.
- A chained command, such as `a && b`, is checked part by part. Deny and ask
  apply when any part matches. Allow applies only when every part is covered.
- Rules match the command as written. `/bin/rm` does not match `rm *`.
- Rules are not a security boundary.

The rules are checked in this order: deny, then ask, then allow.

Outside Allow all, a command that cannot be undone, such as deleting data or
partitions, asks you to type the server's name before it runs. This applies
even when a rule allows the command.

### Always allow

When a command asks for confirmation, **Always allow** adds a rule for that
command to the server's allow rules. The rule then applies to every task.
The panel shows the rule before you
choose **Always allow**. A command that matches an ask rule gets no suggested
rule.

### Auto mode rules

The auto mode rules are on the same page, under **Auto mode rules**. They are
written in plain language for the model. The sections are **Environment**,
**Allow**, **Soft deny**, and **Hard deny**.

An empty section uses the built-in rules. Write `$defaults` on a line to keep
the built-in rules and add your own below it. The model applies the rules in
this order: hard deny, then soft deny, then allow. An allow rule, or a request
from you that is explicit, clears a soft deny.

### Sudo

When a command uses `sudo`, the panel asks for the password of the account that
runs the command. The password goes to `sudo` only.

The panel asks again for each command. If you select **Don't ask again for 15
minutes**, the password stays in memory for 15 minutes. It is never written to
disk. It is removed when the account's sessions end, for example after a
password change.

On Windows, commands run in Windows PowerShell. `sudo` is not available there.

## Memory

Open **Settings → Agent → Memory** to see the files the agent keeps across your
tasks. The agent reads the files and updates
them as needed. `MEMORY.md` is the index. The agent reads it at the start of
every task.

You can create, edit, and delete files in this page.

## Deployed apps

The agent knows which web apps the Monitor has deployed on the server. For each
app, the system prompt of every task gives the state, the health, the loopback
address, the exact `compose` command, and the data folders. You can ask the
agent about an app by name. For how to deploy apps, see
[Monitor Apps](/docs/advanced/monitor-apps/).

## MCP servers

Add MCP servers under **Settings → Agent → MCP servers**. The agent gets
the tools of each enabled server in every task.

Only the Streamable HTTP transport is supported. The address must use `https://`,
or `http://` with a loopback address such as `127.0.0.1`.

To add a server, enter a **Name** and an **Address**. Add each header that the
server requires under **Header** and **Value**, such as `Authorization`. The
panel shows the names of the headers that it sends. A value is write-only. To
change it, select **New Authorization value** (named after the header) and enter the new value. The panel
never shows a saved value again.

The status of a server shows **Not connected** when the panel cannot reach it.

A tool that is marked as read-only runs without a question. Any other tool
follows the task's permission mode, as a command does. In Manual, it waits for
your confirmation. In Auto, the model judges it. In Allow all, it runs and is
recorded in the audit log.

### Example: Home Assistant

1. In Home Assistant, add the **MCP Server** integration.
2. Create a long-lived access token in your Home Assistant user profile.
3. In **Settings → Agent → MCP servers**, add a server with these values:
   - **Name**: a name of your choice
   - **Address**: `http://127.0.0.1:8123/api/mcp`
   - **Header**: `Authorization`
   - **Value**: `Bearer <token>`, where `<token>` is the access token from
     step 2

The address uses loopback, so the Monitor agent must run on the same machine
as Home Assistant.

## Skills

Manage skills under **Settings → Agent → Skills**.

To install skills, select **Install**. In **GitHub repository**, enter a source
in one of these forms:

- `owner/repo`
- `owner/repo@skill`, to install one skill by name
- a `github.com` address
- an `npx skills add` line

The panel reports when the repository has no skill, has too many skills, or is
not a GitHub repository.

Each skill has an **On** switch and a **Remove** button. Each task is told
which skills are on, and what they are for. A task loads a skill when the task
matches it.

You can also put a folder that contains a `SKILL.md` file in the `skills`
folder of the agent's data directory. The panel lists these folders with the
installed skills.

## Search

The desk's **Search** can also ask the agent. Type a question,
a keyword, or a change. Search runs read-only: it can run commands that only
read the system. Nothing that a search runs changes the machine. A request for
a change returns a draft plan.

## Copy for pi

You can turn on **Copy tasks for pi** under **Settings → Agent**. When it
is on, each task is also saved as a session of pi's coding agent, in the
session directory of the agent's account. Run `pi -r` in the agent's working
folder to list the sessions. Deleting a task also deletes its copy.

## Privacy

To produce a response, the model provider receives:

- the prompts that you write, and the system prompt, which includes the memory
  index, the list of deployed apps, the enabled skills, and the instructions of
  MCP servers
- the output of the commands that the model reads
- the results of MCP tools
- the attachments of a task, as described in [Attachments](#attachments)

The audit log records permission decisions and changes to settings. It does not
record passwords, API keys, or command output.
