---
title: Bulk Import Servers
description: Import multiple servers from JSON file
---

Import multiple server configurations at once using a JSON file.

## JSON Format

:::danger[Security Warning]
**Never store plaintext passwords in files!** This JSON example shows a password field for demonstration only, but you should:

- **Prefer SSH keys** (`pubKeyId`) instead of `pwd` - they're more secure
- **Use secret managers** or environment variables if you must use passwords
- **Delete the file immediately** after import - don't leave credentials lying around
- **Add to .gitignore** - never commit credential files to version control
:::

```json
[
  {
    "name": "My Server",
    "ssh": {
      "ip": "example.com",
      "port": 22,
      "user": "root",
      "pwd": "password",
      "pubKeyId": ""
    },
    "tags": ["production"],
    "autoConnect": false
  }
]
```

The SSH settings are nested under `ssh`. This is what the app writes, and the
example the import dialog shows you.

The old flat layout — `ip`/`port`/`user`/... at the top level — is still
accepted, so files exported by an older version and `~/.ssh/config` imports keep
working. Nothing writes it any more.

## Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Display name |
| `ssh` | No | SSH settings, see below. Omit for a monitor-only server |
| `monitorHttp` | No | Monitor agent: `addr`, `user`, `pwd`, `ignoreCert` |
| `tags` | No | Organization tags |
| `autoConnect` | No | Auto-connect on startup |
| `custom` | No | Per-server extras: `pveAddr`, `preferTempDev`, `logoUrl`, ... |
| `wolCfg` | No | Wake-on-LAN configuration |
| `envs` | No | Environment variables, SSH terminal only |
| `customSystemType` | No | Skip system auto-detection |
| `disabledCmdTypes` | No | Status commands to skip on this server |
| `id` | No | Stable server id; omitted or empty values are generated on import |

Inside `ssh`:

| Field | Required | Description |
|-------|----------|-------------|
| `ip` | Yes | Domain or IP address |
| `port` | Yes | SSH port (usually 22) |
| `user` | Yes | SSH username |
| `pwd` | No | Password (avoid - use SSH keys instead) |
| `pubKeyId` | No | Private key id (from Private Keys - recommended) |
| `alterUrl` | No | Fallback address, `user@ip:port` |
| `jumpIds` | No | Jump server chain, by server id |
| `proxyCommand` | No | ProxyCommand; desktop only, and exclusive with `jumpIds` |

A record with no `ssh` and no `monitorHttp` imports as a server with no way to
reach it — give it one or the other.

## Import Steps

1. Create JSON file with server configurations
2. Settings → **Backup** → Import → **Server**
3. Select your JSON file
4. Confirm the count it reports

## Example

```json
[
  {
    "name": "Production",
    "ssh": {
      "ip": "prod.example.com",
      "port": 22,
      "user": "admin",
      "pubKeyId": "my-key"
    },
    "tags": ["production", "web"]
  },
  {
    "name": "Development",
    "ssh": {
      "ip": "dev.example.com",
      "port": 2222,
      "user": "dev",
      "pubKeyId": "dev-key"
    },
    "tags": ["development"]
  },
  {
    "name": "Behind NAT",
    "monitorHttp": {
      "addr": "https://10.0.0.5:3770",
      "user": "admin",
      "pwd": "panel-password"
    },
    "tags": ["monitor"]
  }
]
```

## Tips

- **Use SSH keys** instead of passwords when possible
- **Test connection** after import
- **Organize with tags** for easier management
- **Delete JSON file** after import
- **Never commit** JSON files with credentials to version control
