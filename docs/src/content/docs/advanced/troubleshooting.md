---
title: Common Issues
description: Solutions to common problems
---

## Connection Issues

### SSH Won't Connect

**Symptoms:** Timeout, connection refused, auth failed

**Solutions:**

1. **Verify server type:** Only Unix-like systems supported (Linux, macOS, Android/Termux)
2. **Test manually:** `ssh user@server -p port`
3. **Check firewall:** Port 22 must be open
4. **Verify credentials:** Username and password/key correct

### Frequent Disconnections

**Symptoms:** Terminal disconnects after inactivity

**Solutions:**

1. **Server keep-alive:**
   ```bash
   # /etc/ssh/sshd_config
   ClientAliveInterval 60
   ClientAliveCountMax 3
   ```

2. **Disable battery optimization:**
   - MIUI: Battery → "No limits"
   - Android: Settings → Apps → Disable optimization
   - iOS: Enable background refresh

## Input Issues

### Can't Type Certain Characters

**Solution:** Settings → Keyboard Type → Switch to `visiblePassword`

Note: CJK input may not work after this change.

## App Issues

### App Crashes on Startup

**Symptoms:** App won't open, black screen

**Causes:** Corrupted settings, especially from JSON editor

**Solutions:**

1. **Clear app data:**
   - Android: Settings → Apps → ServerBox → Clear Data
   - iOS: Delete and reinstall

2. **Restore backup:** Import backup created before changing settings

### Backup/Restore Issues

**Backup not working:**
- Check storage space
- Verify app has storage permissions
- Try different location

**Restore fails:**
- Verify backup file integrity
- Check app version compatibility

## Widget Issues

### Widget Not Updating

**iOS:**
- Wait up to 30 minutes for automatic refresh
- Remove and re-add widget
- Check URL ends with `/status`

**Android:**
- Tap widget to force refresh
- Verify widget ID matches configuration in app settings

**watchOS:**
- Restart watch app
- Wait a few minutes after config change
- Verify URL format

### Widget Shows Error

- Verify ServerBox Monitor is running on server
- Test URL in browser
- Check authentication credentials

## Performance Issues

### App is Slow

**Solutions:**
- Reduce refresh rate in settings
- Check network speed
- Disable unused servers

### High Battery Usage

**Solutions:**
- Increase refresh intervals
- Disable background refresh
- Close unused SSH sessions

## Getting Help

If issues persist:

1. **Search GitHub Issues:** https://github.com/lollipopkit/flutter_server_box/issues
2. **Create New Issue:** Include app version, platform, and steps to reproduce
3. **Check Wiki:** This documentation and GitHub Wiki
