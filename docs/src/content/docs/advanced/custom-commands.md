---
title: Custom Commands
description: Show custom command output on the server detail page
---

Custom commands let you add server-specific checks to the server detail page.
Their output is collected whenever the App refreshes that server's status.

## Storage location

The commands live on each server, in
`~/.config/server_box/custom_cmds`. The App does not keep a local copy: the
editor loads the files from the server and writes changes back when you save.

This means:

- **Connect to the server before editing.** If the server is unreachable, you
  can view the editor but cannot save changes.
- **The App and Monitor agent use the same files.** Changes made in the
  Monitor web panel are immediately available to the App, and vice versa.

## Editing

1. Open the server's edit page and select **Custom commands → Edit**.
2. Add a command, change its name or shell text, or drag it to a new position.
3. Save the changes to the server.

Each entry contains a display name and a shell command. The App uses the name
as the output label on the server detail page.

The saved order is also the order used on the server detail page. Reorder
commands in the editor to change how they appear.

## Special name

### `server_card_top_right`

The command named `server_card_top_right` is a special case. Its output is
shown in the top-right corner of the server card on the home page rather than
in the regular custom-command list.

## Writing commands

**Use absolute paths:**

```sh
/usr/local/bin/my-script.sh
```

**Pipes are supported:**

```sh
ps aux | sort -rk 3 | head -5
```

**Format output:**

```sh
uptime | awk -F'load average:' '{print $2}'
```

**Keep execution time short.** Aim for less than one second because the
command runs on every status refresh.

**Limit output:**

```sh
tail -20 /var/log/syslog
```

## Security

Commands run with the account used for the connection: the SSH user for SSH
connections, or the Monitor agent process user for Monitor connections.

For Monitor connections, editing commands requires `full_access`. The agent
must also have terminal access enabled, and the request must use secure
transport or explicitly permit `allow_insecure`. Each file in this directory
is executable code: it runs as the agent user on every status refresh.

Use read-only commands where possible. A command can affect the server with
the permissions of its execution account. Never include passwords, tokens, or
other credentials in a command.

## Migrating from the old format

Older releases stored commands as a JSON object in the server settings. The
App preserved those entries when other settings changed, then moved them into
the server directory on the first connection. Current releases write commands
only to that directory.
