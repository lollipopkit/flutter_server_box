---
title: Desk Apps
description: Install third-party apps in the Monitor panel's desk
---

The [Monitor agent](/docs/advanced/monitor-agent/)'s web panel is a desk with
apps in windows. Besides its own apps, you can install third-party apps from `.fsba` packages. These are different from
[Monitor Apps](/docs/advanced/monitor-apps/), which deploy Docker Compose
services on the server.

An installed app runs in a sandboxed frame of the panel. It has no network
access and cannot use the agent's API. It reaches the desk only through what
its permissions allow: its window, notifications, and storage of its own. An
app of the `wasm` kind also has a backend that the agent runs, which can read
the server's status, run programs, or run scripts as root when its
permissions allow. Before anything runs as root the desk shows its own dialog,
naming the app and what it says it does, and asks for sudo's password; the
password goes to the agent with that request, never to the app.

## Install an app

The **App Store** lists the desk apps the agent offers, those ServerBox signed
marked **ServerBox** and others **Unknown publisher**. **Install** shows what
the app asks for and installs and approves it with your password.

A package from elsewhere:

1. Open **Settings → Apps** in the panel.
2. Under **Installed**, select **Install…** and choose the `.fsba` package.
   The agent checks the package and refuses it when the check fails, for
   example a manifest with an unknown field or an entry outside the package.
3. The app is listed as **Waiting**. Select **Approve**, read what it asks
   for, and enter your password.

After approval the app appears in **All Apps**. Other open desks see it the
next time they start.

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
| `process` | `wasm` only: running programs as the agent's system account |
| `root` | `wasm` only: running scripts as root, each time after you confirm in the desk's dialog with sudo's password (it can be remembered for 15 minutes) |

What a backend may do is bounded by the permissions the app was approved with
and by the agent's transport rule: `process` and `root` need HTTPS or a
caller on the same host, as the rest of the agent does. They reach what the
system account the agent runs as can reach; see
[Access](/docs/advanced/monitor-agent/#access).

An approved app can read whatever its permissions allow. The sandbox blocks its network requests, but it
cannot stop an app from sending what it has read elsewhere by navigating its
frame. Install apps only from publishers you trust.

## Use and remove an app

Each app has a page under **Settings → Apps → All apps**: whether it is in the
dock, whether it keeps running while hidden (when it has the `background`
permission), and the permissions it was approved with.

**Remove** under **Installed** removes the app, together with what was stored
in it.

## Build an app

See [Developing Desk Apps](/docs/development/desk-apps/).
