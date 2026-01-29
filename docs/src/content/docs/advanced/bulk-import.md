---
title: Bulk Import Servers
description: Import multiple servers from JSON file
---

Import multiple server configurations at once using a JSON file.

## JSON Format

> [!WARNING] SECURITY WARNING
> **Never store plaintext passwords in files!** This JSON example shows a password field for demonstration only, but you should:
> - **Prefer SSH keys** (`keyId`) instead of `pwd` - they're more secure
> - **Use secret managers** or environment variables if you must use passwords
> - **Delete the file immediately** after import - don't leave credentials lying around
> - **Add to .gitignore** - never commit credential files to version control

```json
[
  {
    "name": "My Server",
    "ip": "example.com",
    "port": 22,
    "user": "root",
    "pwd": "password",
    "keyId": "",
    "tags": ["production"],
    "autoConnect": false
  }
]
```

## Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Display name |
| `ip` | Yes | Domain or IP address |
| `port` | Yes | SSH port (usually 22) |
| `user` | Yes | SSH username |
| `pwd` | No | Password (avoid - use SSH keys instead) |
| `keyId` | No | SSH key name (from Private Keys - recommended) |
| `tags` | No | Organization tags |
| `autoConnect` | No | Auto-connect on startup |

## Import Steps

1. Create JSON file with server configurations
2. Settings → Backup → Bulk Import Servers
3. Select your JSON file
4. Confirm import

## Example

```json
[
  {
    "name": "Production",
    "ip": "prod.example.com",
    "port": 22,
    "user": "admin",
    "keyId": "my-key",
    "tags": ["production", "web"]
  },
  {
    "name": "Development",
    "ip": "dev.example.com",
    "port": 2222,
    "user": "dev",
    "keyId": "dev-key",
    "tags": ["development"]
  }
]
```

## Tips

- **Use SSH keys** instead of passwords when possible
- **Test connection** after import
- **Organize with tags** for easier management
- **Delete JSON file** after import
- **Never commit** JSON files with credentials to version control
