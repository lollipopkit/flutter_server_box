---
title: Common Issues
description: Common problems and how to resolve them
---

## Connection issues

### SSH will not connect

Typical symptoms include a timeout, a refused connection, or a login failure.

Check the following in order:

1. Confirm that SSH server software is installed and running. Supported hosts include Linux, macOS, Android/Termux, and Windows with OpenSSH Server.
2. From another terminal, try `ssh user@server -p port`.
3. Check the network route and firewall rules, then verify that the SSH port is reachable.
4. Check the username and the configured password or SSH key.
5. If you use a jump server or ProxyCommand, test that route to the target separately.

### Connections disconnect frequently

You may see the terminal disconnect while idle or shortly after the App goes into the background.

Try these steps:

1. Configure SSH keep-alive on the server in `/etc/ssh/sshd_config`:

   ```text
   ClientAliveInterval 60
   ClientAliveCountMax 3
   ```

2. On Android, enable **Background running**, allow notifications, and exempt Server Box from battery optimization. MIUI/HyperOS may also require the battery policy **No restrictions**.
3. iOS may suspend background connections. Return to Server Box and wait for it to reconnect.

## Input issues

### Some characters cannot be entered

1. Use the terminal's virtual keyboard for Esc, Tab, Ctrl/Alt combinations, and common symbols.
2. Tap **IME** to show or hide the system keyboard.
3. If a third-party keyboard sends unexpected input, switch to the system keyboard and try again.

## App issues

### The App crashes on startup or shows a black screen

An invalid value in the JSON settings editor can stop the App from starting.

1. Restore a backup made before the setting was changed.
2. Android: open **System Settings → Apps → Server Box → Storage** and clear the App data.
3. iOS: delete and reinstall the App, then restore the backup.

Clearing app data or reinstalling removes anything that was not backed up. Use these steps only if you cannot recover another way.

### Backup or restore fails

**Backup fails:**

- Check the device's available storage.
- Confirm that the App can access the selected destination.
- Try another destination.

**Restore fails:**

- Make sure the backup file is complete and has not been altered.
- Confirm that it was created by a compatible App version.
- If it contains credentials, check that the App can access the platform's secure storage needed to decrypt them.

## Widget and Watch App issues

### Widgets or the Watch App do not update

- Confirm that Monitor agent is running and reachable at the configured URL.
- Check the Monitor username, password, certificate, and `allowInsecure` setting in the App.
- iOS decides when to refresh widgets. Wait for its next refresh, or remove and add the widget again.
- On Android, tap the widget to refresh it. Open its configuration to confirm the selected server and metric.
- The Watch App must be paired with an iPhone. After changing a server, open Server Box on the iPhone and wait for it to sync.

### A widget shows an error or no servers

- Add at least one Monitor agent server in the App.
- Verify that the agent's HTTPS address is reachable and its credentials are correct.
- Widgets use the server list from the App; they no longer read manually entered `/status` URLs. If an older version left a URL behind, follow the one-time in-app prompt to configure the server again.

## Performance issues

### The App is slow

- Increase the status refresh interval.
- Check network latency and available bandwidth.
- Temporarily disable servers or status cards you do not need.
- Run fewer terminal sessions and file transfers at the same time.

### High battery usage

- Increase the status refresh interval.
- Turn off background running or refresh when it is not needed.
- Close SSH sessions you are not using.

## Getting help

If these steps do not resolve the issue:

1. Search [GitHub Issues](https://github.com/lollipopkit/flutter_server_box/issues).
2. Open an Issue with the App version, platform, relevant logs, and steps to reproduce the problem.
3. For Monitor agent problems, include its version and relevant configuration. Remove passwords, tokens, and other secrets first.
