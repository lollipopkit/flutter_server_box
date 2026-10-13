---
title: Desk Apps
description: Install third-party apps in the Monitor panel's desk
---

The [Monitor agent](/docs/advanced/monitor-agent/)'s web panel is a desk with
apps in windows. Besides its own apps, an administrator can install
third-party apps from `.fsba` packages. These are different from
[Monitor Apps](/docs/advanced/monitor-apps/), which deploy Docker Compose
services on the server.

An installed app runs in a sandboxed frame of the panel. It has no network
access and cannot use the agent's API. It reaches the desk only through what
its permissions allow: its window, notifications, and storage of its own. An
app of the `wasm` kind also has a backend that the agent runs, which can read
the server's status, read files, or run commands when its permissions allow.

## Install an app

Installing, approving and removing apps needs an administrator account.

1. Open **Settings → Apps** in the panel.
2. Under **Installed**, select **Install…** and choose the `.fsba` package.
   The agent checks the package and refuses it when the check fails, for
   example a manifest with an unknown field or an entry outside the package.
3. The app is listed as **Waiting**. Select **Approve**, read what it asks
   for, and enter your password.

After approval the app appears in **All Apps** for every account on the
server. Other open desks see it the next time they start.

Every new package waits for approval again, including a newer version of an
approved app, even when it asks for the same permissions. The row shows the
version and the first characters of the package's SHA-256, so you can compare
it with what the publisher lists.

## Permissions

| Permission | Allows |
|---|---|
| `notifications` | Showing notifications on the desk |
| `background` | Running while its window is hidden |
| `status` | `wasm` only: reading the server's status |
| `files.read` | `wasm` only: reading files inside `[remote_access.fs] roots`, for accounts with the `files` grant |
| `exec` | `wasm` only: running commands, for accounts with the `shell` grant |

An app never gets more than the account using it: the agent checks the
account's grants on every call of the backend. See
[Accounts and permissions](/docs/advanced/monitor-agent/#accounts-and-permissions).

An approved app runs as whoever opens it and can read whatever that account's
permissions and its own allow. The sandbox blocks its network requests, but it
cannot stop an app from sending what it has read elsewhere by navigating its
frame. Install apps only from publishers you trust.

## Use and remove an app

Each app has a page under **Settings → Apps → All apps**: whether it is in the
dock, whether it keeps running while hidden (when it has the `background`
permission), and the permissions it was approved with.

**Remove** under **Installed** removes the app for every account on the
server, together with what its users stored in it.

## Build an app

See [Developing Desk Apps](/docs/development/desk-apps/).
