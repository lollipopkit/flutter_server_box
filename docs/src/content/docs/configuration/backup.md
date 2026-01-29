---
title: Backup & Restore
description: Backup and restore your app data
---

Protect your server configurations and settings with built-in backup functionality.

## What Gets Backed Up

- **Server Configurations**: All saved servers
- **SSH Keys**: Imported private keys (encrypted)
- **Snippets**: Saved command snippets
- **Settings**: App preferences

**Not included:** Passwords (for security)

## Creating Backups

### Manual Backup

1. Settings → Backup
2. Tap **Create Backup**
3. Choose location
4. Backup saved with timestamp

### Auto Backup

Settings → Backup → Auto Backup:
- Daily / Weekly / Monthly / Off

### Cloud Sync

- **iOS/macOS**: iCloud automatic backup
- **Android**: Google Drive integration

## Restoring

### From Local Backup

1. Settings → Backup → Restore Backup
2. Select backup file
3. Authenticate (biometric/password)
4. Confirm restore

### From Cloud

1. Sign in to same cloud account
2. Settings → Backup → Restore from Cloud
3. Select backup from list
4. Authenticate and confirm

## Important Notes

### Passwords Not Backed Up

After restore, you'll need to re-enter passwords for each server.

**Tip:** Use SSH keys instead - they ARE backed up.

### Cross-Platform

Backups work across all platforms (iOS ↔ Android ↔ Desktop).

## Best Practices

1. **Enable auto backup** for peace of mind
2. **Test restore** periodically to verify backups work
3. **Backup before** updating app or switching devices
4. **Use SSH keys** to avoid re-entering passwords

## Troubleshooting

**Restore failed:**
- Check backup file integrity
- Ensure sufficient storage
- Verify app version compatibility

**Missing data after restore:**
- Passwords are not backed up (re-enter them)
- Check selective restore settings
