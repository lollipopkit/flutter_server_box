---
title: Custom Commands
description: Show the output of your own commands on the server page
---

Add shell commands of your own and their output appears on the server detail
page, refreshed with the rest of the status.

## Where they live

Each command is a **file in a directory on the server**
(`~/.config/server_box/custom_cmds`), and that directory is the only copy. The
app does not keep its own copy. It reads the directory when you open the editor and
writes it back when you save.

Two consequences:

- **The server has to be reachable to edit them.** The editor says so instead of
  collecting changes that would have nowhere to go.
- **The same set is shared.** A monitor agent's web panel edits the same
  directory, and the app's status script reads it. All three use the same
  directory; no synchronization step is required.

## Editing

1. Server settings → **Custom Command** → **Edit**
2. Add, rename, edit or reorder entries
3. Save

Each entry is a name and a command. The name is what labels the output on the
server detail page.

**Order is stored.** It is the order the status page lists the commands in,
which is why the editor is a reorderable list.

## Special names

### server_card_top_right

A command with this name is not listed with the others. Its output goes in the
top-right corner of the server card on the home page.

## Tips

**Use absolute paths:**

```sh
/usr/local/bin/my-script.sh
```

**Pipes work:**

```sh
ps aux | sort -rk 3 | head -5
```

**Format the output:**

```sh
uptime | awk -F'load average:' '{print $2}'
```

**Keep execution time low.** Commands run on every status refresh.

**Limit the output:**

```sh
tail -20 /var/log/syslog
```

## Security

Commands run as the account the app reaches the server with: the SSH user, or
the account a monitor agent runs as. On a monitor server, editing them at all
requires the agent's `full_access` grant. The grant is usable only when the
agent's terminal capability is enabled and the request meets its secure-transport
or explicit `allow_insecure` requirement, because adding a file to that directory
arranges for code to run on every refresh.

Avoid commands that change system state.

## Migrating from the old format

Earlier versions stored these as a JSON object in the server's own settings.
Those entries are carried through untouched when you edit anything else on the
server, and move to the server's directory on the first connection. The app no
longer writes to the old location.
