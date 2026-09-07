---
title: Custom Commands
description: Show custom command output on the server detail page
---

You can add custom shell commands and view their output on the server detail page.

## Refresh interval

Custom commands run on their own schedule, separate from the status poll. **Settings → Server → More → Custom command interval** sets it; the default is 30 seconds.

They only run on a status poll, so the interval that takes effect is the one you set rounded up to a whole number of status update intervals: 7 seconds against a 3-second status poll means 9. The settings entry shows the value that takes effect.

Set it to `0` to run them on every status poll, which is what earlier versions did.

## Storage location

Each command is a file on the server under `~/.config/server_box/custom_cmds`. This is the only copy: the App does not store commands locally. The editor reads the directory from the server and writes back to it when you save.

Consequences:

- **The server must be reachable while editing.** If it is unavailable, the editor explains that the changes cannot be saved.
- **The App and Monitor agent share the same commands.** The Monitor web panel edits this directory, and the status script reads it, so no synchronization step is needed.
- **A save replaces the whole set, and is refused if it would discard someone else's edits.** The editor records what the directory held when it loaded, and the save checks that value before replacing anything. If another App or panel changed the commands in between, the save fails and offers to reload.

## Editing

1. Open the server edit page and choose **Custom commands → Edit**.
2. Add, rename, edit, or drag commands to reorder them.
3. Save.

Each entry has a name and a shell command. The name becomes the label for its output on the server detail page.

**The order is saved and determines the order on the status page.** That is why the editor uses a reorderable list.

## Special name

### `server_card_top_right`

A command named `server_card_top_right` is not listed with the other custom commands. Its output appears in the top-right corner of the server card on the home page.

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

**Keep execution time short.** Each command has a 5-second timeout on the server, and the commands run one after another.

**Limit output:**

```sh
tail -20 /var/log/syslog
```

## Security

Commands run as the identity used to reach the server: the SSH user for SSH connections, or the user running Monitor agent for Monitor connections.

On a Monitor server, editing custom commands requires `full_access`. The agent must also have terminal access enabled, and the request must use secure transport or explicitly allow `allow_insecure`. Adding a file to this directory schedules code to run as the agent user on every extended collection cycle.

Avoid commands that modify system state. Never put passwords, tokens, or other credentials in a custom command.

## Migrating from the old format

Older versions stored custom commands as a JSON object in the server settings. The App carried those entries through edits to other server fields and moved them to the server directory on the first connection. The current version no longer writes the old format.
