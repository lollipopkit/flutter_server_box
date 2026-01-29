---
title: Server Setup
description: Configure and manage server connections
---

## Adding a Server

1. Tap the **+** button on the main screen
2. Fill in connection details:
   - **Name**: Friendly name for identification
   - **Host**: IP address or domain name
   - **Port**: SSH port (default: 22)
   - **Username**: SSH login user
   - **Authentication**: Password or SSH key

3. Configure optional settings:
   - **Initial Directory**: Starting directory for terminal/SFTP
   - **Environment**: Custom environment variables
   - **Keep-alive Interval**: Connection keep-alive setting

4. Tap **Save**

## Connection Types

### Password Authentication

Simple username/password authentication:

- Enter password in the password field
- Password is stored securely (encrypted)
- Requires re-entry on app restart (unless saved)

### SSH Key Authentication

More secure, passwordless authentication:

1. Generate or import SSH key
2. Add key to server's `~/.ssh/authorized_keys`
3. Select key in app when adding server

See [SSH Keys](/configuration/ssh-keys/) for detailed setup.

## Server Groups

Organize servers into groups for easier management:

1. Go to Settings > Server Groups
2. Create a new group
3. Assign servers to groups
4. Groups appear as sections in main view

## Server Cards

Customize what information appears on server cards:

1. Go to Settings > Server Card Settings
2. Enable/disable metrics:
   - CPU
   - Memory
   - Disk
   - Network
3. Reorder cards by dragging

## Connection Profiles

Save connection profiles for different use cases:

- **Default Profile**: Standard settings
- **Low Bandwidth**: Reduced refresh rate
- **High Performance**: Maximum refresh rate

## Troubleshooting

### Connection Refused

- Check server is running
- Verify SSH port
- Check firewall rules

### Authentication Failed

- Verify username/password
- Check SSH key permissions
- Ensure SSH service is running

### Timeout

- Check network connectivity
- Increase timeout in settings
- Try different network
