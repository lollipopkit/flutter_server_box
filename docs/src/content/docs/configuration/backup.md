---
title: Backup & Restore
description: Backup and restore your app data
---

Protect your server configurations and settings with built-in backup functionality.

## What Gets Backed Up

### Included in Backup

- **Server Configurations**: All saved servers with connection details
- **SSH Keys**: Imported private keys (encrypted)
- **Snippets**: Saved command snippets
- **Settings**: App preferences and customization
- **Known Hosts**: SSH fingerprint cache

### Not Included

- Server passwords (for security)
- External files
- App state (active connections)

## Backup Methods

### Local Backup

Save backup to local device storage:

1. Go to **Settings > Backup**
2. Tap **Create Backup**
3. Choose location (if prompted)
4. Backup saved with timestamp

### Cloud Backup

Sync backups to cloud storage:

- **iCloud**: iOS/macOS automatic backup
- **Google Drive**: Android integration
- Requires cloud permissions

### Manual Export

Export backup file:

1. Settings > Backup > Export
2. Choose format (JSON recommended)
3. Save to preferred location
4. Transfer to other devices or cloud storage

## Backup Format

### Encrypted JSON

Backups stored as encrypted JSON:

```json
{
  "version": "1.0",
  "timestamp": "2024-01-15T10:30:00Z",
  "servers": [...],
  "snippets": [...],
  "settings": {...}
}
```

Encrypted with device-specific key.

### Security

- **Encryption**: AES-256 encryption
- **Key**: Device-specific, not stored
- **Protection**: Biometric authentication required
- **No Cloud Keys**: Backups encrypted before upload

## Restore Process

### From Local Backup

1. Go to **Settings > Backup**
2. Tap **Restore Backup**
3. Select backup file
4. Authenticate (biometric/password)
5. Confirm restore
6. App restarts with restored data

### From Cloud

1. Sign in to same cloud account
2. Open app on new device
3. Go to **Settings > Backup**
4. Tap **Restore from Cloud**
5. Select backup from list
6. Authenticate and confirm

### Selective Restore

Choose what to restore:

- **All**: Restore everything
- **Servers Only**: Just server configurations
- **Settings Only**: Just app preferences
- **Snippets Only**: Just command snippets

## Backup Schedule

### Automatic Backups

Configure automatic backups:

**Settings > Backup > Auto Backup**

Options:
- **Daily**: Once per day
- **Weekly**: Once per week
- **Monthly**: Once per month
- **Off**: Manual only

### Retention Policy

Number of backups to keep:

**Settings > Backup > Keep Last**

Options:
- **3**: Keep last 3 backups
- **5**: Keep last 5 backups
- **10**: Keep last 10 backups
- **All**: Keep all backups

## Cross-Platform Restore

### iOS to Android

Backups are platform-independent:

1. Export backup on iOS
2. Transfer to Android device
3. Import and restore

### Desktop to Mobile

Same process works across all platforms.

## Troubleshooting

### Restore Failed

- Verify backup file integrity
- Ensure sufficient storage space
- Check app version compatibility
- Try restarting app before restore

### Missing Data

- Check backup included all data
- Verify restore completed successfully
- Check selective restore settings

### Password Required After Restore

**This is normal behavior**: Passwords are not backed up for security.

You'll need to:
1. Re-enter passwords for each server
2. Or use SSH keys (which are backed up)

## Best Practices

1. **Regular Backups**: Enable automatic backups
2. **Multiple Locations**: Keep backups on device and cloud
3. **Test Restores**: Verify backup integrity periodically
4. **Before Updates**: Backup before app updates
5. **Before Device Changes**: Backup before switching devices

## Security Tips

- Use **biometric authentication** for backup access
- Don't share backup files unencrypted
- Securely delete old backup files
- Use cloud backup with encryption enabled
