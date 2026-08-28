---
title: Common Issues
description: Common problems and how to resolve them
---

## Connection issues

### SSH will not connect

**Common symptoms:** The connection times out, is refused, or authentication fails.

**Troubleshooting steps:**

1. Confirm that the server runs an SSH server. Supported targets include Linux, macOS, Android/Termux, and Windows with OpenSSH Server.
2. Test the connection in another terminal: `ssh user@server -p port`.
3. Check the firewall and network routes, and confirm that the SSH port is reachable.
4. Verify the username, password, or SSH key.
5. If you configured a jump server or ProxyCommand, verify that it can connect to the target independently.

### Connections disconnect frequently

**Common symptoms:** The terminal disconnects after being idle, or the connection disappears after the App moves to the background.

**What to do:**

1. Configure SSH keep-alive in `/etc/ssh/sshd_config`:

   ```text
   ClientAliveInterval 60
   ClientAliveCountMax 3
   ```

2. On Android, enable **Background running**, allow notifications, and disable battery optimization for Server Box. MIUI/HyperOS may also require the battery policy to be set to “No restrictions”.
3. iOS cannot guarantee that a connection stays alive in the background. Return to the App and wait for it to reconnect.

## Input issues

### Some characters cannot be entered

1. Use the terminal's virtual keyboard to send Esc, Tab, Ctrl/Alt combinations, and common symbols.
2. Use the **IME** key to show or hide the system keyboard.
3. If a third-party keyboard behaves incorrectly, switch temporarily to the system keyboard.

## App issues

### The App crashes on startup or shows a black screen

An invalid setting edited through the JSON editor can prevent startup.

1. First try restoring the backup created before the change.
2. Android: open **System Settings → Apps → Server Box → Storage** and clear the App data.
3. iOS: delete and reinstall the App, then restore the backup.

Clearing data or reinstalling deletes data that was not backed up. Use it only as a last resort.

### Backup or restore fails

**Backup fails:**

- Check the device's available storage.
- Confirm that the App can access the selected destination.
- Try another destination.

**Restore fails:**

- Confirm that the backup file is complete and unchanged.
- Check that the file comes from a compatible App version.
- If the backup contains credentials, make sure the App can access the platform secure storage used to decrypt the database.

## Widget and Watch App issues

### Widgets or the Watch App do not update

- Confirm that Monitor agent is running and that the device can reach its URL.
- Verify the Monitor username, password, certificate, and `allowInsecure` settings in the App.
- iOS schedules widget refreshes itself. Wait, or remove and re-add the widget.
- Tap an Android widget to refresh it manually, then reopen its configuration page to check the selected server and metric.
- The Watch App requires an iPhone pairing. After changing a server, open the iPhone App and wait for synchronization.

### A widget shows an error or no servers

- Configure at least one server with Monitor agent in the App.
- Check the agent's HTTPS configuration, credentials, and network reachability.
- Widgets no longer use manually entered `/status` URLs. If an older version left one behind, follow the one-time notice in the App and configure the server again.

## Performance issues

### The App is slow

- Increase the server status refresh interval.
- Check network latency and bandwidth.
- Temporarily disable unused servers or status cards.
- Reduce the number of concurrent terminal and file-transfer tasks.

### High battery usage

- Increase the status refresh interval.
- Disable background running or background refresh when you do not need it.
- Close unused SSH sessions.

## Getting help

If the issue persists:

1. Search [GitHub Issues](https://github.com/lollipopkit/flutter_server_box/issues).
2. Open a new Issue with the App version, platform, relevant logs, and reproduction steps.
3. For Monitor agent issues, include the agent version and relevant configuration after removing passwords, tokens, and other secrets.
