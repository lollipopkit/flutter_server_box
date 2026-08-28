---
title: Bulk Import Servers
description: Import multiple server configurations from a JSON file
---

You can import multiple server configurations from one JSON file.

## JSON format

:::danger[Security warning]
**Do not store plaintext passwords in the file.** The example below includes a sample password only to show the format. In real files:

- **Prefer SSH keys** (`pubKeyId`) instead of `pwd`.
- If a password is unavoidable, generate the file through a secret manager or environment variable.
- Delete the file immediately after import.
- Add it to `.gitignore`; never commit credential files to version control.
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

SSH fields are nested under the `ssh` object. This is the format exported by the App and shown in the import dialog.

The older flat format, with `ip`, `port`, `user`, and other fields at the top level, is still accepted. Files exported by older versions and `~/.ssh/config` imports therefore remain usable; the current version does not write this format.

## Fields

| Field | Required | Description |
|---|---|---|
| `name` | Yes | Server name shown in the App |
| `ssh` | No | SSH configuration; omit for a server configured only through Monitor HTTP |
| `monitorHttp` | No | Monitor agent configuration: `addr`, `user`, `pwd`, `ignoreCert`, `allowInsecure` |
| `preferredTransport` | No | Which transport leads when both SSH and Monitor HTTP are configured: `ssh` or `monitorHttp`. SSH leads when omitted |
| `tags` | No | Tags used to group servers |
| `autoConnect` | No | Connect automatically when the App starts |
| `custom` | No | Per-server extras such as `pveAddr`, `preferTempDev`, and `logoUrl` |
| `wolCfg` | No | Wake-on-LAN configuration |
| `envs` | No | Environment variables for the SSH terminal only |
| `customSystemType` | No | Skip automatic system-type detection |
| `disabledCmdTypes` | No | Status commands to skip on this server |
| `id` | No | Stable server ID; omitted or empty values are generated during import |

Inside `ssh`:

| Field | Required | Description |
|---|---|---|
| `ip` | Yes | Domain name or IP address |
| `port` | Yes | SSH port, usually `22` |
| `user` | Yes | SSH username |
| `pwd` | No | Password; not recommended, use an SSH key instead |
| `pubKeyId` | No | ID of a private key stored in the App, not a PEM file path |
| `keyPath` | No | Desktop-only private-key path produced by a `~/.ssh/config` import; read from disk when connecting |
| `alterUrl` | No | Fallback address in the form `user@ip:port` |
| `jumpIds` | No | Jump-server chain specified by server ID |
| `proxyCommand` | No | ProxyCommand; desktop only and mutually exclusive with `jumpIds` |

A record that omits both `ssh` and `monitorHttp` cannot connect to anything after import. Provide at least one.

`allowInsecure` defaults to `false`. Set it only when you intentionally allow this Monitor connection to use plaintext HTTP, including for non-loopback private addresses. Monitor agent independently checks its own `allow_insecure` setting for sensitive endpoints.

## Import steps

1. Create a JSON file containing the server configurations.
2. Open **Settings → Backup → Import → Server**.
3. Select the JSON file.
4. Confirm the number of servers to import.
5. Delete the JSON file after the import completes.

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

## Recommendations

- Prefer SSH keys over passwords.
- Test every connection after importing.
- Use tags to organize servers.
- Delete the JSON file after importing.
- Never commit a JSON file containing credentials.
