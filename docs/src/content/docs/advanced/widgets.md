---
title: Home Screen Widgets
description: Add server status widgets to your home screen
---

Home-screen widgets require [Monitor agent](/docs/advanced/monitor-agent/) on the server. After installing and configuring the agent, configure the server in the App; the widgets receive the available server list automatically.

## How widgets work

Widgets read Monitor agent's authenticated API directly and do not depend on the App being open. The App publishes the names, addresses, and short-lived read-only tokens for servers with Monitor agent configured. Tokens are stored in the platform's secure credential storage.

There are two fixed layouts: **Small** shows current readings, and **Medium** shows charts for several metrics. When adding a widget, choose a server and leading metric; you do not enter a URL manually.

## iOS widgets

iOS widgets require iOS 17 or later.

### Setup

1. Long-press the Home Screen and tap **+**.
2. Search for “Server Box”.
3. Choose the **Small** or **Medium** widget.
4. After adding it, long-press the widget and tap **Edit Widget**.
5. Select the server to display.

Small widgets show current readings. Medium widgets show charts for multiple metrics. Each widget selects one server.

### Notes

- The server must be configured with Monitor agent in the App.
- The App checks the server's `allowInsecure` setting. Use HTTPS for non-loopback connections unless plaintext HTTP is explicitly intended.
- iOS controls the refresh schedule; a fixed interval is not guaranteed.
- You can add multiple widgets and select a server for each one.

## Android widgets

### Setup

1. Long-press the Home Screen and tap **Widgets**.
2. Find “Server Box”, choose the Small or Medium type, and add it.
3. On the configuration page, select a server and leading metric.
4. Tap Save.
5. Tap the widget to refresh it manually when needed.

Each Android widget instance stores its own configuration, so different widgets can show different servers or metrics. The server list comes from the App; if it is empty, configure a server with Monitor agent first.

## Watch app

The Watch app requires watchOS 10 or later. It reads directly from Monitor agent, so it can show only servers with Monitor agent configured in the App. These servers sync by default; exclude servers at **iOS Settings → App → iOS → Watch app**.

### Setup

1. Open Server Box on the iPhone.
2. Go to **Settings → App → iOS → Watch app**.
3. Exclude servers that you do not want to show; all remaining Monitor servers synchronize.
4. Wait for the Watch app to synchronize.

The Watch app pages through servers sorted by name, independently of the App's server-list order. The **Lock screen widget** has no separate setting; add it from the system widget gallery and select a server there.

## Troubleshooting

### Widgets or the Watch app do not update

- Confirm that Monitor agent is running and that the device can reach its URL.
- Verify the Monitor username, password, certificate, and `allowInsecure` settings in the App.
- iOS schedules widget refreshes itself; wait, or remove and re-add the widget.
- Tap an Android widget to refresh it manually, then reopen its configuration page to check the selected server and metric.
- The Watch app requires an iPhone pairing. After changing a server, open the iPhone App and wait for synchronization.

### A widget shows an error or no servers

- Configure at least one server with Monitor agent in the App.
- Check the agent's HTTPS configuration, credentials, and network reachability.
- Widgets no longer use manually entered `/status` URLs. If an older version left one behind, follow the one-time notice in the App and configure the server again.

## Security

- Use HTTPS whenever possible.
- For non-loopback plaintext HTTP, enable **Allow insecure HTTP** for that server in the App. The widget endpoints (`/api/v1/metrics`, `/api/v1/metrics/history`, and `/api/v1/watch-token`) have no corresponding agent-side switch; `allow_insecure` applies only to `[remote_access.terminal]` and `[remote_access.fs]`, not to widgets.
- Do not put Monitor credentials or widget tokens in public documentation or version control.
