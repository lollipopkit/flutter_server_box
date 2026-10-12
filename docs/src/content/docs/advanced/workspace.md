---
title: Workspace
description: Several views of several servers side by side, with keyboard shortcuts
---

The **Workspace** tab shows several server views side by side. For example,
you can place a server's terminal beside its status page, or show one server's
shell above another server's containers. Each pane hosts a page you can also
open from a server's detail page.

A fresh install does not put the tab in the bar: open it from **More**, or add
it under **Settings › Application › Home Tabs**.

## Workspaces, panes and tabs

- A **workspace** is a named arrangement. You can keep several and switch
  between them from the name at the top left.
- A workspace is split into **panes**. Split a pane right or down, drag the
  line between two panes to resize them, and double-click that line to make
  the two halves equal again.
- Each pane holds **tabs**. A tab is one view of one server: terminal, status,
  files, Agent, containers, processes, services or snippets.

Drag a tab to another pane's edge to split that pane, or to its middle to add
it there. On iOS and Android, press and hold a tab before dragging. If the
pane is on a phone or too narrow to show its tabs, drag the pane bar instead.

A narrow window shows two panes at a time: the focused one and the one focused
before it. The panes button at the top lists every pane and moves the focus.

**Maximize** fills the workspace with one pane and hides the others until you
restore it. Double-clicking a pane's strip of tabs does the same. A narrow
window has no maximize: it already shows at most two panes.

You can undo the most recent tab or pane close from the message that appears,
or use the **Reopen closed tab** shortcut. Reopening restores the workspace to
the state before that close, so it also discards any layout changes made since.
You cannot undo the close after closing that workspace or deleting a server used in it.

## After a restart

Workspaces are kept on the device. When the app starts again, tabs of a
server set to connect at launch reconnect as they are shown. Tabs of any other
server wait until you tap **Connect**, or until the server is connected from
the server tab; either connects all of that server's tabs. A tab on a server
that has been deleted is removed.

## Sync input

**Sync input** sends each key you type to every other terminal in the
workspace, like tmux `synchronize-panes`. A bar above each terminal shows when
it is enabled. Terminal-generated replies, such as cursor-position reports,
are not copied.

## Templates

**Save layout as template** stores the pane layout and each pane's view types,
without server assignments. Choosing a template creates a workspace with
that layout. Its tabs use the server assigned to the active tab in the focused
pane; if that pane is empty, you choose a server.

## Moving a terminal into a workspace

In the **Terminal** tab, **Move to workspace** moves the current server
terminal into a workspace. This option is not available for a terminal on
this device. The connection, shell, and screen contents are preserved.

## Keyboard shortcuts

**Settings › Application › Keyboard shortcuts** lists the app's shortcuts.
You can change or remove configurable shortcuts; fixed shortcuts are listed
but cannot be changed. Workspace shortcuts work only in a workspace. Global
shortcuts, such as opening Settings, work on every page. In a terminal outside
a workspace, shortcuts assigned to workspace, Settings, or server-tab actions
are sent to the shell because those actions are unavailable there. The
terminal's copy, paste, and select-all controls are not configurable shortcuts.

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
