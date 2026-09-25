---
title: Home Screen Widgets
description: Add server status widgets to your home screen
---

To use a home-screen widget, install [Monitor agent](/docs/advanced/monitor-agent/)
on the server and add that server to the App. The App provides the widget with
the configured Monitor servers automatically.

## How widgets work

Widgets request data directly from Monitor agent, so the App does not need to
be open. For each server configured with Monitor agent, the App publishes its
name, address, and a short-lived read-only token. The token is stored in the
platform's secure credential storage.

Choose between two layouts: **Small** displays current readings, and
**Medium** displays charts for several metrics. During setup, select a server
and its leading metric. The widget gets its URL from the server configuration.

## iOS widgets

iOS 17 or later is required.

### Setup

1. Touch and hold the Home Screen, then tap **+**.
2. Search for “Server Box”.
3. Choose the **Small** or **Medium** widget.
4. After the widget appears, touch and hold it, then tap **Edit Widget**.
5. Select the server to display.

Each iOS widget displays one server. Small widgets show its current readings;
Medium widgets show charts for several metrics.

### Notes

- Add the server to the App with Monitor agent configured.
- The App applies that server's `allowInsecure` setting. Use HTTPS unless you intentionally need plaintext HTTP for a non-loopback connection.
- iOS chooses when widgets refresh; it does not guarantee a fixed interval.
- Add multiple widgets to show different servers.

## Android widgets

### Setup

1. Long-press the Home Screen and tap **Widgets**.
2. Find “Server Box”, choose the Small or Medium type, and add it.
3. On the configuration page, select a server and leading metric.
4. Tap Save.
5. Tap the widget to refresh it manually when needed.

Every Android widget instance keeps its own server and metric selection, so
widgets can show different information. The App supplies the server list. If
it is empty, add a server configured with Monitor agent first.

## Watch app

The Watch app requires watchOS 10 or later and reads data directly from
Monitor agent. It can show only servers configured with Monitor agent in the
App. Those servers sync by default. To exclude one, open **iOS Settings → App
→ iOS → Watch app**.

### Setup

1. Open Server Box on the iPhone.
2. Open **Settings → App → iOS → Watch app**.
3. Exclude any servers you do not want on the Watch; the remaining Monitor servers will sync.
4. Wait for synchronization to finish.

The Watch app sorts its server pages by name, regardless of the order in the
App. To add a **Lock screen widget**, use the system widget gallery and select
a server there; it has no separate setting in Server Box.

## Troubleshooting

### Widgets or the Watch app do not update

- Make sure Monitor agent is running and reachable at the configured address.
- Check the Monitor username, password, certificate, and `allowInsecure` setting in the App.
- iOS controls the refresh schedule. Wait for another refresh, or remove and add the widget again.
- Tap an Android widget to refresh it. Open its configuration to confirm the selected server and metric.
- Pair the Watch with an iPhone. After changing server settings, open Server Box on the iPhone and wait for sync.

### A widget shows an error or no servers

- Add at least one Monitor agent server in the App.
- Check the agent's HTTPS configuration, saved credentials, and network reachability.
- Widgets use the App's server list instead of manually entered `/status` URLs. If an old URL remains, follow the one-time in-app prompt to configure the server again.

## Security

- Prefer HTTPS.
- To use plaintext HTTP with a non-loopback address, enable **Allow insecure HTTP** for that server in the App. Widget endpoints (`/api/v1/metrics`, `/api/v1/metrics/history`, and `/api/v1/watch-token`) have no agent-side switch. The agent's `allow_insecure` options apply to `[remote_access.terminal]` and `[remote_access.fs]` only.
- Keep Monitor credentials and widget tokens out of public documentation and version control.
