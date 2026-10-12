---
title: Workspace
description: Several views of several servers side by side, with keyboard shortcuts
---

The **Workspace** tab shows several views at once: a terminal next to the
status of the same server, the containers of a database host under a shell on
the application host, and so on. Each view is the same page the app opens from
a server's detail page, shown inside a pane.

A fresh install does not put the tab in the bar: open it from **More**, or add
it under **Settings › App › Home Tabs**.

## Workspaces, panes and tabs

- A **workspace** is a named arrangement. You can keep several and switch
  between them from the name at the top left.
- A workspace is split into **panes**. Split a pane right or down, drag the
  line between two panes to resize them, and double-click that line to make
  the two halves equal again.
- Each pane holds **tabs**. A tab is one view of one server: terminal, status,
  files, Agent, containers, processes, services or snippets.

Drag a tab to another pane's edge to split that pane, or to its middle to add
the tab to it. On a phone, press and hold the pane bar to drag.

A narrow window shows two panes at a time: the focused one and the one focused
before it. The panes button at the top lists every pane and moves the focus.

**Maximize** fills the workspace with one pane and hides the others until you
restore it. Double-clicking a pane's tab bar does the same.

Closing a tab or a pane can be undone from the message that appears, or with
**Reopen closed tab**.

## After a restart

Workspaces are kept on the device. When the app starts again, tabs of a
server set to connect at launch reconnect as they are shown. Tabs of any other
server wait until you tap **Connect**, or until the server is connected from
the server tab; either connects all of that server's tabs. A tab on a server
that has been deleted is removed.

## Sync input

**Sync input** sends what you type in one terminal to every other terminal of
the workspace, key by key, like tmux `synchronize-panes`. A bar over each
terminal says it is on. Replies a terminal sends by itself, such as a cursor
position report, are not copied.

## Templates

**Save layout as template** stores the layout and the views of each pane,
without servers. Choosing a template in the workspace list creates a new
workspace with that layout, with every tab on the server of the focused pane.

## Moving a terminal into a workspace

In the **Terminal** tab, **Move to workspace** puts the terminal on screen into
a workspace. The connection, the shell and what is on the screen stay as they
are.

## Keyboard shortcuts

**Settings › App › Keyboard shortcuts** lists every key combination the app
uses, and lets you change or remove each one. When a terminal has focus, these
combinations are handled by the app and are not sent to the shell; any
combination not listed still reaches the shell.

| Command | Windows / Linux | macOS |
| --- | --- | --- |
| Quick open | `Ctrl+Alt+P` | `⌃⌘P` |
| Split right | `Ctrl+Alt+\` | `⌃⌘\` |
| Split down | `Ctrl+Alt+-` | `⌃⌘-` |
| Move focus between panes | `Ctrl+Alt+←↑→↓` | `⌃⌘←↑→↓` |
| New tab | `Ctrl+Alt+N` | `⌃⌘N` |
| Close tab | `Ctrl+Alt+W` | `⌃⌘W` |
| Next / previous tab | `Ctrl+Alt+]` / `Ctrl+Alt+[` | `⌃⌘]` / `⌃⌘[` |
| Tabs of the focused pane | `Ctrl+Alt+O` | `⌃⌘O` |
| Reopen closed tab | `Ctrl+Alt+Shift+T` | `⌃⌘⇧T` |
| Maximize or restore pane | `Ctrl+Alt+M` | `⌃⌘M` |
| Sync input | `Ctrl+Alt+I` | `⌃⌘I` |
| Switch workspace | `Ctrl+Alt+S` | `⌃⌘S` |

On Windows and Linux, combinations with Control and Alt are taken from the left
Alt key only. The right Alt key (AltGr) types characters such as `\` and `[`
on many keyboard layouts, so it is left to the shell.
