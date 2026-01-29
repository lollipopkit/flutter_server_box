---
title: Bulk Import Servers
description: Import multiple servers from JSON file
---

Import multiple server configurations at once using a JSON file.

## JSON Format

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
| `pwd` | No | Password |
| `keyId` | No | SSH key name (from Private Keys) |
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
    "pwd": "dev-password",
    "tags": ["development"]
  }
]
```

## Tips

- **Use SSH keys** instead of passwords when possible
- **Test connection** after import
- **Organize with tags** for easier management
- **Delete JSON file** after import (contains credentials)
