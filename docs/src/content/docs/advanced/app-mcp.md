---
title: App MCP
description: Reach every server ServerBox knows from an MCP client, with the same tools and token model as the Monitor
---

The app serves the same MCP server as the [Monitor](/development/monitor-agent/#api-tokens-and-mcp), for every server it reaches: the tools, their answers, the token format and the scopes are shared. Each tool that is about a server takes a `host` argument, an id from `list`.

## Setup

Open **Settings → AI → MCP Server**. Choose **New token**, give it a name, pick its scopes, and save the displayed token: it is shown once. Turn on the switch and connect to `http://127.0.0.1:49762/mcp` with the token as a Bearer credential. Delete a token to revoke it; the next request is refused.

Select **Listen** to change the address and port. **All** listens on the wildcard address, **LAN** on one IP of a Wi-Fi, Ethernet or VPN interface such as Tailscale, and **This device** on loopback. LAN saves the selected IP, so select it again if your network assigns a different address. **Custom** accepts an address and port such as `[::]:49762`.

Loopback uses HTTP. LAN and wildcard listeners require TLS: put the PEM certificate chain and its private key beside the registry, appending `.crt` and `.key` to its filename (by default `app-mcp.json.crt` and `app-mcp.json.key`). On iOS, supply both in one passwordless PKCS#12 file ending in `.p12`. Restrict access to the private key, and connect to a name or IP in the certificate. Alternatively, keep the listener on loopback and reach it through an authenticated SSH tunnel.

For stdio clients, run `python3 /absolute/path/to/scripts/app-mcp-stdio.py` with the token in `SERVERBOX_MCP_TOKEN`. Set `SERVERBOX_MCP_HOST` and `SERVERBOX_MCP_PORT` if the destination differs from `127.0.0.1:49762`. The bridge verifies remote HTTPS certificates; for a private CA, set `SSL_CERT_FILE` to its PEM bundle. To reach a TLS listener on a loopback IP, set `SERVERBOX_MCP_SCHEME=https`.

## Tokens and scopes

A token is `sbt_` and 64 hex digits, stored as its BLAKE3 digest in the registry file (`app-mcp.json` in the app's documents folder; `SERVERBOX_MCP_POLICY` selects another one for desktop automation when no listener is saved). The registry is read again on every request, so it can be edited by hand:

```json
{
  "policy": {
    "scopes": ["read", "exec", "service"],
    "commands": { "mode": "allow_all", "deny": ["rm -rf *"] }
  },
  "tokens": [
    {
      "id": "<lowercase BLAKE3 digest of the token>",
      "name": "Desktop",
      "scopes": ["read"],
      "commands": { "mode": "allowlist", "allow": ["uptime", "df *"] },
      "created_at": 0
    }
  ]
}
```

A missing `scopes` grants every scope, including any a newer version adds. A token can do what both its own scopes and the policy's allow, and `run_command` must pass both command policies. Command rules use the Agent's pattern syntax, as on the Monitor.

| Scope | Tools |
| --- | --- |
| `read` | `list`, `machine_capabilities`, `processes`, `services`, `containers`, `tmux`, `app_settings` |
| `exec` | `run_command` |
| `process` | `kill_process` |
| `service` | `service_action` |
| `container` | `container_action` |
| `settings` | `app_setting_set` |

## Tools

`list` returns every server with its id, name, whether it is connected, and its transports (`ssh`, `monitor`, `local`). Ids are digests of the app's own server ids. **This device** is listed when **Settings → AI → Run commands on this device** is on.

A call reaches its server the way the app does: over SSH (reusing an open connection or connecting with the saved configuration, jump servers and `ProxyCommand` included), through the Monitor, or on this device. A host key to approve, a key passphrase or a keyboard-interactive question is answered by the person: the call fails, nothing is counted against the server's reconnect limit, and the next call works once the server is connected in the app.

`processes`, `services`, `containers`, `tmux`, `kill_process`, `service_action` and `container_action` take the Monitor's arguments and return its answers. `machine_capabilities` returns the server's platform and transports. When the app has not read the server yet, its platform is probed first.

`run_command` takes `host` and `command` and returns `exit_code`, `stdout`, `stderr`, `truncated` and `timed_out`. The command runs in the account's own shell. Output is kept up to 256 KiB and a command is stopped after 30 seconds; a Monitor applies its own limits too.

`app_settings` lists the app's editable preferences with their current values. `app_setting_set` takes `key` and a typed `value`, as the tool's input schema describes, and writes through the same store as the settings page. For example, set `editorFontSize` to `15.5`, `motionPref` to `"reduce"`, `trayMetrics` to `["cpu", "disk"]`, or `keybindings` to `{"settings.search": "Ctrl+Shift+F"}`. Arrays and maps replace the whole setting.
