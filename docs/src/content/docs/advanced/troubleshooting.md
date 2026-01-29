---
title: Troubleshooting
description: Common issues and solutions
---

## SSH Connection Issues

### SSH Cannot Connect

**Symptoms:**
- Connection timeout
- Connection refused
- Authentication failed

**Solutions:**

1. **Check System Support**
   - Currently only Unix-like systems supported
   - Supported: Linux, macOS, Android (Termux)
   - Not supported: Windows servers

2. **Verify SSH Version**
   - Check server's OpenSSH version
   - Update to latest OpenSSH version
   ```bash
   ssh -V
   ```

3. **Test Connection Manually**
   ```bash
   ssh user@server -p port
   ```
   If this fails, issue is with server/SSH config, not app.

4. **Check Firewall**
   - Verify SSH port (default 22) is open
   - Check server firewall rules
   - Test with: `telnet server 22`

### SSH Terminal Disconnects

**Symptoms:**
- Terminal disconnects after inactivity
- Frequent disconnections

**Solutions:**

1. **Check Server Settings**
   - Review SSH server keep-alive settings
   - Check `ClientAliveInterval` in sshd_config
   ```bash
   # /etc/ssh/sshd_config
   ClientAliveInterval 60
   ClientAliveCountMax 3
   ```

2. **Disable Battery Optimization**
   - **MIUI:** Set battery strategy to "No limits"
   - **Android:** Disable battery optimization for app
   - **iOS:** Background refresh must be enabled

3. **Network Issues**
   - Check network stability
   - Try different network (Wi-Fi vs cellular)
   - Verify VPN isn't interfering

## Terminal Input Issues

### Keyboard Type Problems

**Symptoms:**
- Cannot input certain characters
- Chinese/Japanese input not working

**Solution:**

Change keyboard type:
1. Go to **Settings**
2. Find **Keyboard Type**
3. Switch to `visiblePassword`

**Note:** After this change, CJK input may not work, but terminal experience improves.

## App Issues

### App Won't Open After Settings Change

**Symptoms:**
- App crashes on startup
- Black screen

**Solution:**

1. **Clear App Data** (last resort)
   - Android: Settings > Apps > ServerBox > Clear Data
   - iOS: Delete and reinstall app

2. **Restore from Backup**
   - Use backup created before changing settings
   - Import backup file

3. **Reset JSON Settings**
   - If JSON settings were changed, restore defaults

### Backup/Restore Issues

**Backup Not Working**

1. Check available storage
2. Verify app has storage permissions
3. Try different location

**Restore Fails**

1. Verify backup file integrity
2. Check app version compatibility
3. Ensure sufficient storage

## Widget Issues

### Widget Not Updating

**iOS:**
- Wait for automatic refresh (max 30 min)
- Remove and re-add widget
- Check URL is correct
- Verify network connectivity

**Android:**
- Tap widget to force refresh
- Verify widget ID matches configuration
- Check app settings for correct URL

**watchOS:**
- Restart watch app
- Wait a few minutes after config change
- Verify URL format is correct
- Check phone and watch are connected

### Widget Shows Error

- Verify ServerBox Monitor is running
- Test URL in browser
- Check URL ends with `/status`
- Verify authentication (if enabled)

## Performance Issues

### App is Slow

**Solutions:**

1. **Reduce Refresh Rate**
   - Lower status refresh frequency
   - Disable auto-refresh for some features

2. **Check Network**
   - Test network speed
   - Try different network
   - Check server responsiveness

3. **Reduce Server Count**
   - Too many servers can slow app
   - Disable servers not frequently used

### High Battery Usage

**Solutions:**

1. **Adjust Refresh Intervals**
   - Increase time between refreshes
   - Disable background refresh

2. **Enable Battery Optimization**
   - Allow system to manage app
   - Note: May affect background features

3. **Reduce Active Connections**
   - Close unused SSH sessions
   - Disconnect servers not in use

## Data Issues

### Server Data Lost

**Solutions:**

1. **Restore from Backup**
   - Use backup file
   - Import via Settings > Backup

2. **Check Cloud Sync**
   - If cloud backup enabled, sync from cloud

### Settings Reset

**Solutions:**

1. **Check for Updates**
   - Update may have changed settings
   - Reconfigure as needed

2. **Restore Backup**
   - Use settings backup
   - Import previous configuration

## Getting Help

If issues persist:

1. **Check GitHub Issues**
   - Search for similar problems
   - https://github.com/lollipopkit/flutter_server_box/issues

2. **Create New Issue**
   - Include:
     - App version
     - Platform (iOS/Android/Desktop)
     - Detailed error description
     - Steps to reproduce

3. **Check Wiki**
   - This documentation
   - GitHub Wiki
   - DeepWiki

4. **Community**
   - GitHub Discussions
   - Check for existing solutions
