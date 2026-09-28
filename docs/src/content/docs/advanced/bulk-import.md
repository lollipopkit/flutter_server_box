---
title: Bulk Import Servers
description: Import multiple server configurations from a JSON file
---

Use a JSON file to add several servers in one import. Each array item describes
one server, including its connection method and optional grouping or startup
settings.

## JSON format

:::danger[Security warning]
Import files are plain text and may contain credentials. Keep them out of
shared folders and source control, and remove them as soon as the import is
complete.

- Prefer an SSH key already stored in the App and reference it with
  `pubKeyId`; do not put private key material in this file.
- If a password or token must be included, restrict access to the file and
  delete it immediately after import.
- Add any import file to `.gitignore`. Never commit it, even if you think its
  credentials are temporary.
:::

```json
[
  {
    "name": "My Server",
    "ssh": {
      "ip": "example.com",
      "port": 22,
      "user": "root",
      "pubKeyId": ""
    },
    "tags": ["production"],
    "autoConnect": false
  }
]
```

SSH settings belong in the `ssh` object. This nested layout is used by the
App's exports and by the import dialog example.

For backward compatibility, import also accepts the older flat layout, where
fields such as `ip`, `port`, and `user` are at the top level. This keeps files
from older releases and `~/.ssh/config` imports usable. New exports use the
nested layout above.

## Fields

| Field | Required | Description |
|---|---|---|
| `name` | Yes | Server name shown in the App |
| `ssh` | No | SSH configuration; omit for a server configured only through Monitor HTTP |
| `monitorHttp` | No | Monitor agent configuration: `addr`, `user`, `pwd`, `ignoreCert`, `allowInsecure` |
| `preferredTransport` | No | Which transport leads when both SSH and Monitor HTTP are configured: `ssh` or `monitorHttp`. SSH leads when omitted |
| `tags` | No | Tags used to group servers |
| `autoConnect` | No | Connect automatically when the App starts |
| `custom` | No | Per-server extras such as `preferTempDev` and `logoUrl` |
| `pve` | No | Proxmox VE configuration; see below |
| `wolCfg` | No | Wake-on-LAN configuration |
| `envs` | No | Environment variables for the SSH terminal only |
| `customSystemType` | No | Skip automatic system-type detection |
| `disabledCmdTypes` | No | Status commands to skip on this server |
| `id` | No | Stable server ID; omitted or empty values are generated during import |

The following fields belong inside `ssh`:

| Field | Required | Description |
|---|---|---|
| `ip` | Yes | Domain name or IP address |
| `port` | Yes | SSH port, usually `22` |
| `user` | Yes | SSH username |
| `pwd` | No | Password; not recommended, use an SSH key instead |
| `fileTransport` | No | Which protocol carries files: `sftp` or `scp`. Defaults to `sftp`; use `scp` for a host with no SFTP subsystem |
| `pubKeyId` | No | ID of a private key stored in the App, not a PEM file path |
| `keyPath` | No | Desktop-only private-key path produced by a `~/.ssh/config` import; read from disk when connecting |
| `alterUrl` | No | Fallback address in the form `user@ip:port` |
| `jumpIds` | No | Jump-server chain specified by server ID |
| `proxyCommand` | No | ProxyCommand; desktop only and mutually exclusive with `jumpIds` |

The following fields belong inside `pve`:

| Field | Required | Description |
|---|---|---|
| `addr` | Yes | PVE web address, for example `https://127.0.0.1:8006`; the host is resolved on the server's side of the connection |
| `auth` | No | `token` or `password`. Defaults to `password` |
| `tokenId` | For `token` | API token ID in the form `user@realm!tokenid` |
| `tokenSecret` | For `token` | The token's secret; a credential, so treat the file as one |
| `pwd` | No | For `password`: the PVE password of the SSH user in the `pam` realm. Omit it to reuse the SSH password |
| `certSha256` | No | SHA-256 of the certificate to trust, lowercase hex. Omit it to confirm the certificate on the first connection |

Older exports may put `pveAddr`, `pveIgnoreCert`, and `pvePwd` inside
`custom`. Import still recognizes those fields and converts them to password
authentication without a pinned certificate. This legacy format is for
import compatibility; current exports use `pve`.

A server needs at least one connection method. If both `ssh` and
`monitorHttp` are omitted, the imported record cannot connect to a host.

`allowInsecure` defaults to `false`. Set it only if you intend this Monitor
connection to use plaintext HTTP, including when the address is a private
non-loopback IP. The Monitor agent separately enforces its own
`allow_insecure` setting for sensitive endpoints.

## Import steps

1. Create a JSON array containing the server records.
2. Open **Settings → Backup → Import → Server**.
3. Select the JSON file.
4. Check the displayed server count and confirm the import.
5. Remove the import file and any copies as soon as the import finishes.

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
      "user": "admin"
    },
    "tags": ["monitor"]
  }
]
```

After importing, test each connection and confirm that the expected tags and
transport settings appear on the server records.
