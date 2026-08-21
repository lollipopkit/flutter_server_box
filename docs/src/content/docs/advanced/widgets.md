---
title: Home Screen Widgets
description: Add server status widgets to your home screen
---

Requires a [monitor agent](/docs/advanced/monitor-agent/) on each server shown by the widget.

## Prerequisites

Install ServerBox Monitor on your server first. See its [README](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/README.md) for setup instructions.

After installation, verify that the server provides:
- HTTP/HTTPS endpoint
- `/status` API endpoint
- Optional authentication

## URL Format

```
https://your-server.com/status
```

The URL must end with `/status`.

## iOS Widget

### Setup

1. Long press home screen → Tap **+**
2. Search "ServerBox"
3. Choose widget size
4. Long press widget → **Edit Widget**
5. Enter URL ending with `/status`

### Notes

- Use HTTPS for remote endpoints; use HTTP only on a trusted local network.
- Max refresh rate: 30 minutes (iOS limit)
- Add multiple widgets for multiple servers

## Android Widget

### Setup

1. Long press home screen → **Widgets**
2. Find "ServerBox" → Add to home screen
3. Note the widget ID number displayed
4. Open ServerBox app → Settings → **App** → Setting → **Android Setting**
5. Tap **Config home widget url**
6. Add entry: `Widget ID` = `Status URL`

Example:
- Key: `17`
- Value: `https://my-server.com/status`

7. Tap widget on home screen to refresh

## watchOS

The watch reads each server from its monitor agent by itself, so it can only
show servers that have one configured. Add the agent to the server first. In
the server's edit page, set it as the connection method instead of SSH.

### Setup

1. Open iPhone app → Settings → **App** → Setting → **iOS Setting**
2. Tap **Watch app**
3. Pick the servers to show. The order you pick them in is kept, and the watch
   pages through that list
4. Wait for the watch app to sync

**Lock screen widget** is a separate entry on the same page and shows one server rather
than a list.

### Notes

- Try restarting the watch app if it is not updating
- Verify phone and watch are connected
- **Legacy status URLs** appear only when they were saved by an
  older version. Nothing creates new ones


## Troubleshooting

### Widget Not Updating

**iOS:** Wait up to 30 minutes, then remove and re-add
**Android:** Tap widget to force refresh, verify ID in settings
**watchOS:** Restart watch app, wait a few minutes

### Widget Shows Error

- Verify ServerBox Monitor is running
- Test URL in browser
- Check URL ends with `/status`

## Security

- **Use HTTPS** for all remote endpoints.
- **Use HTTP for local IPs** only on trusted networks.
