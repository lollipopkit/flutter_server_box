---
title: Links (serverbox://)
description: Open a server, a function, a tab or a snippet from a link
---

ServerBox opens `serverbox://` links on iOS, macOS and Android. Use them from
Shortcuts, launchers, notes or a web page.

Windows and Linux do not handle these links.

## Getting a link

- **Server**: long-press (or right-click) a server in the list → **Copy link**.
- **Snippet**: open the snippet → the link button in the top bar.

Servers and snippets are named by their id, not their name: names can repeat
and change.

## Links

| Link | Opens |
| --- | --- |
| `serverbox://server/<id>` | The server's page |
| `serverbox://server/<id>/<function>` | One of the server's functions |
| `serverbox://tab/<tab>` | A tab |
| `serverbox://snippet/<id>` | A snippet, on a server picked after opening |
| `serverbox://snippet/<id>?server=<id>` | A snippet, on that server |
| `serverbox://add-server?host=…&port=…&user=…&name=…` | The add-server form, filled in |

`<function>` is one of `terminal`, `files`, `container`, `process`, `snippet`,
`iperf`, `systemd`, `portForward`, `power`, `users`, `scheduledTasks`,
`remoteDesktop`.

`<tab>` is one of `server`, `ssh`, `file`, `snippet`, `agent`, `benchmark`,
`remoteDesktop`, `virt`.

For `add-server`, only `host` is required.

## What a link can do

Any web page or app can open a link, so a link only does what a tap in the app
does, and asks wherever the app asks:

- A snippet is always shown and confirmed before it runs.
- `add-server` only fills in the form. Nothing is saved until you save it, and
  it never takes a password or key: a link ends up in browser history and
  clipboard managers.
- Power actions ask before they run, as they do from the server's page.

When the app is locked, a link waits until it is unlocked.
