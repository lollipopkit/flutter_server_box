---
title: Home Screen Widgets
description: Add server status widgets to your home screen
---

Requires [ServerBox Monitor](https://github.com/lollipopkit/server_box_monitor) installed on your servers.

## Prerequisites

Install ServerBox Monitor on your server first. See [ServerBox Monitor Wiki](https://github.com/lollipopkit/server_box_monitor/wiki/Home) for setup instructions.

After installation, your server should have:
- HTTP/HTTPS endpoint
- `/status` API endpoint
- Optional authentication

## URL Format

```
https://your-server.com/status
```

Must end with `/status`.

## iOS Widget

### Setup

1. Long press home screen → Tap **+**
2. Search "ServerBox"
3. Choose widget size
4. Long press widget → **Edit Widget**
5. Enter URL ending with `/status`

### Notes

- Must use HTTPS (except local IPs)
- Max refresh rate: 30 minutes (iOS limit)
- Add multiple widgets for multiple servers

## Android Widget

### Setup

1. Long press home screen → **Widgets**
2. Find "ServerBox" → Add to home screen
3. Note the widget ID number displayed
4. Open ServerBox app → Settings
5. Tap **Config home widget link**
6. Add entry: `Widget ID` = `Status URL`

Example:
- Key: `17`
- Value: `https://my-server.com/status`

7. Tap widget on home screen to refresh

## watchOS Widget

### Setup

1. Open iPhone app → Settings
2. **iOS Settings** → **Watch app**
3. Tap **Add URL**
4. Enter URL ending with `/status`
5. Wait for watch app to sync

### Notes

- May take a few minutes to update
- Try restarting watch app if not updating
- Verify phone and watch are connected

## Authentication

### Basic Auth

```
https://username:password@server.com/status
```

### Token Auth

Check ServerBox Monitor documentation for token-based authentication.

## Troubleshooting

### Widget Not Updating

**iOS:** Wait up to 30 minutes, then remove and re-add
**Android:** Tap widget to force refresh, verify ID in settings
**watchOS:** Restart watch app, wait a few minutes

### Widget Shows Error

- Verify ServerBox Monitor is running
- Test URL in browser
- Check URL ends with `/status`
- Verify authentication

## Security

- Use HTTPS when possible
- Enable authentication on ServerBox Monitor
- Local IPs only on trusted networks
