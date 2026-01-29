---
title: Widget Setup
description: Configure home screen widgets for iOS, Android, and watchOS
---

Home screen widgets require [ServerBox Monitor](https://github.com/lollipopkit/server_box_monitor) to be installed on your servers first.

## Prerequisites

### Install ServerBox Monitor

ServerBox Monitor provides a lightweight HTTP endpoint for server status.

**See:** [ServerBox Monitor Wiki](https://github.com/lollipopkit/server_box_monitor/wiki/Home) for setup instructions.

### After Installation

Your server should have:
- HTTP/HTTPS endpoint
- `/status` API endpoint
- Optional authentication

## iOS Widget Setup

### Requirements

- iOS 14.0 or later
- ServerBox Monitor running on server
- HTTPS URL (or local IP)

### Steps

1. **Add Widget**
   - Long press on home screen
   - Tap **+** in top-left
   - Search for "ServerBox"
   - Choose widget size

2. **Configure Widget**
   - Long press widget
   - Tap **Edit Widget**
   - Enter URL: `https://your-server.com/status`
   - Must end with `/status`

3. **Save**
   - Tap outside widget
   - Widget displays server status

### URL Requirements

- Must use HTTPS (except for local IPs)
- Must end with `/status`
- Format: `https://server1.srvbox.example.com/status`

### Multiple Widgets

Add multiple widgets for different servers:
- Each widget uses different URL
- Track multiple servers simultaneously

### Refresh Limitations

Due to iOS restrictions:
- Maximum refresh rate: 30 minutes
- Automatic refresh only
- No manual refresh option

## Android Widget Setup

### Requirements

- Android 8.0 (API 26) or later
- ServerBox Monitor running

### Steps

1. **Add Widget**
   - Long press on home screen
   - Tap **Widgets**
   - Find "ServerBox"
   - Add to home screen

2. **Note Widget ID**
   - Widget displays an ID number
   - Remember this ID (e.g., "17")

3. **Configure in App**
   - Open ServerBox app
   - Go to **Settings**
   - Tap **Config home widget link**
   - Add new key-value pair:
     - Key: Widget ID (e.g., "17")
     - Value: Your status URL

4. **Save and Refresh**
   - Tap **Save**
   - Go back to home screen
   - Tap widget to refresh

### Multiple Widgets

Repeat process for each widget:
- Each widget gets unique ID
- Configure each ID separately
- Different servers per widget

## watchOS App Setup

### Requirements

- Apple Watch Series 3 or later
- watchOS 8.0 or later
- iPhone with ServerBox installed
- ServerBox Monitor running

### Steps

1. **Open iPhone App**
   - Go to **Settings**
   - Navigate to **iOS Settings** > **Watch app**

2. **Add URL**
   - Tap **Add URL**
   - Enter: `https://your-server.com/status`
   - Must end with `/status`

3. **Save**
   - Tap **Save**
   - Wait for watch app to refresh

4. **Check Watch App**
   - Open ServerBox on Apple Watch
   - Status should display

### Update Timing

After configuration:
- May take few minutes to update
- Try restarting watch app if not updating
- Verify URLs are accessible

## URL Format

### Required Format

```
https://your-server.com/status
```

### Examples

```
https://server1.example.com/status
https://monitor.example.com/status
https://192.168.1.100/status  (local network only)
```

## Authentication (Optional)

If ServerBox Monitor requires authentication:

### Basic Auth

URL format:
```
https://username:password@server.com/status
```

### Token Auth

Check ServerBox Monitor documentation for token-based authentication.

## Troubleshooting

### Widget Not Updating

**iOS:**
- Wait for automatic refresh (max 30 min)
- Remove and re-add widget
- Check URL is correct

**Android:**
- Tap widget to force refresh
- Verify ID matches configuration
- Check app settings

**watchOS:**
- Restart watch app
- Wait a few minutes after config
- Verify URL format

### Connection Failed

- Verify ServerBox Monitor is running
- Check URL is accessible in browser
- Ensure network connectivity
- Check firewall rules

### Wrong Server Displayed

- Verify URL is correct
- Check for typos
- Reconfigure widget

## Security Notes

- **Local IPs** - Use only on trusted networks
- **HTTPS** - Use HTTPS when possible
- **Authentication** - Enable on ServerBox Monitor
- **Firewall** - Restrict access to Monitor

## Advanced Setup

### Reverse Proxy

Use reverse proxy for multiple servers:

```nginx
location /server1/status {
    proxy_pass http://server1.local:8080/status;
}

location /server2/status {
    proxy_pass http://server2.local:8080/status;
}
```

Widget URLs:
```
https://proxy.example.com/server1/status
https://proxy.example.com/server2/status
```

### SSL/TLS

Use Let's Encrypt for free SSL:
```bash
certbot --nginx -d monitor.example.com
```
