---
title: Terminal & SSH
description: SSH terminal setup and configuration
---

Complete SSH terminal access with full keyboard support and customizable interface.

## Basic Setup

### First Connection

1. Add server with SSH credentials
2. Tap server card to connect
3. Accept host key fingerprint (first time only)
4. Terminal opens automatically

### Virtual Keyboard (Mobile)

Customizable virtual keyboard for terminal access:

| Button | Function |
|--------|----------|
| **Ctrl, Alt, Shift** | Modifier keys (tap before other key) |
| **Esc, Tab** | Special characters |
| **Arrows** | Navigation |
| **F1-F12** | Function keys |
| **SFTP** | Open current directory in file browser |
| **Clipboard** | Copy selection / Paste clipboard |
| **Snippets** | Quick command execution |

**Customize keyboard:** Settings → SSH Virtual Keys
- Enable/disable keys
- Reorder layout
- Add/remove buttons

## Terminal Settings

### Appearance

**Font Size:** Settings → Terminal Font Size
- Affects all new sessions
- Typical range: 8-24 pixels

**Colors:** Settings → Terminal Color
- Text color
- Background color & opacity
- Blur effect (iOS/macOS)
- Cursor color

### Keyboard Type

If you can't input certain characters:

1. Settings → Keyboard Type
2. Switch to `visiblePassword`
3. Note: CJK input may not work after this change

## Connection Management

### Multi-Tab

- **Desktop**: Ctrl+T (new), Ctrl+W (close)
- **Mobile**: Tap + button
- Sessions persist between app launches

### Auto-Connect

Set server to auto-connect on app open:
1. Server settings → Auto-Connect
2. Enable toggle

### Jump Server

Route through intermediate server:

1. Add and configure jump server first
2. Target server settings → Select jump server
3. Connection routes through jump server automatically

## SSH Keys (Recommended)

More secure than passwords:

1. Generate key: Settings → Private Keys → Add
2. Upload public key to server: `ssh-copy-id -i pubkey user@server`
3. Server settings → Use key instead of password

## Common Issues

### Can't Connect

**Timeout/Refused:**
- Verify server is Unix-like (Linux, macOS, Android/Termux)
- Check firewall allows SSH port (default 22)
- Test manually: `ssh user@server -p port`

**Auth Failed:**
- Verify username and password
- Check SSH key is uploaded correctly
- Ensure account is not locked

### Terminal Disconnects

**Frequent disconnections:**

1. Check server keep-alive settings:
   ```bash
   # /etc/ssh/sshd_config
   ClientAliveInterval 60
   ClientAliveCountMax 3
   ```

2. Disable battery optimization:
   - **MIUI**: Battery → "No limits"
   - **Android**: Settings → Apps → Disable optimization
   - **iOS**: Enable background refresh

### Can't Input Characters

Change keyboard type to `visiblePassword` in settings.

## Tips

- **Test connection** first with regular SSH client
- **Use SSH keys** instead of passwords for security
- **Save snippets** for frequently used commands
- **Pinch to zoom** for temporary font size change (mobile)
