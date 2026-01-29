---
title: Bulk Import Servers
description: Import multiple servers at once from a JSON file
---

Import multiple server configurations at once using a JSON file.

## JSON Format

Create a JSON file with array of server objects:

```json
[
  {
    "name": "Server1",
    "ip": "example.com",
    "port": 22,
    "user": "root",
    "pwd": "password",
    "keyId": "",
    "tags": ["tag1"],
    "alterUrl": "root@192.168.1.1",
    "autoConnect": false
  }
]
```

## Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Display name for the server |
| `ip` | string | Yes | IP address or domain name |
| `port` | integer | Yes | SSH port (default: 22) |
| `user` | string | Yes | SSH username |
| `pwd` | string | No | Password (encrypted after import) |
| `keyId` | string | No | Private key name from App - Private Keys |
| `tags` | array | No | Tags for organizing servers |
| `alterUrl` | string | No | Alternative connection URL |
| `autoConnect` | boolean | No | Auto-connect on app start |

## Complete Example

```json
[
  {
    "name": "Production Server",
    "ip": "prod.example.com",
    "port": 22,
    "user": "admin",
    "keyId": "my-key",
    "tags": ["production", "web"],
    "autoConnect": false
  },
  {
    "name": "Development Server",
    "ip": "dev.example.com",
    "port": 2222,
    "user": "dev",
    "pwd": "dev-password",
    "tags": ["development"],
    "alterUrl": "dev@192.168.1.100"
  },
  {
    "name": "Database Server",
    "ip": "db.example.com",
    "port": 22,
    "user": "root",
    "keyId": "db-key",
    "tags": ["database", "production"]
  }
]
```

## Import Process

1. Create JSON file with server configurations
2. Open app
3. Go to **Settings** > **Backup**
4. Tap **Bulk Import Servers**
5. Select your JSON file
6. Confirm import

## Tips

### Use SSH Keys Instead of Passwords

```json
{
  "name": "Secure Server",
  "ip": "secure.example.com",
  "port": 22,
  "user": "admin",
  "keyId": "my-ssh-key",
  "pwd": ""
}
```

### Organize with Tags

```json
{
  "name": "Web Server",
  "ip": "web.example.com",
  "port": 22,
  "user": "admin",
  "keyId": "",
  "tags": ["web", "production", "us-east"]
}
```

### Alternative URL for Fallback

```json
{
  "name": "Multi-homed Server",
  "ip": "primary.example.com",
  "port": 22,
  "user": "admin",
  "keyId": "",
  "alterUrl": "admin@backup.example.com"
}
```

## Security Notes

- **Passwords are stored encrypted** after import
- **Consider using SSH keys** instead of passwords
- **Secure your JSON file** - delete after import
- **Don't commit to version control** with real passwords

## Template File

Save this as template and fill in your servers:

```json
[
  {
    "name": "YOUR_SERVER_NAME",
    "ip": "your.server.com",
    "port": 22,
    "user": "username",
    "pwd": "",
    "keyId": "",
    "tags": [],
    "alterUrl": "",
    "autoConnect": false
  }
]
```

## Troubleshooting

### Import Fails

- Verify JSON syntax is valid
- Check all required fields are present
- Ensure file is saved as .json
- Try validating JSON with online tool

### Servers Don't Connect

- Verify IP/domain is correct
- Check network connectivity
- Confirm SSH service is running
- Test credentials manually

### Passwords Not Working

- Ensure special characters are escaped
- Try SSH keys instead
- Verify user account is valid
