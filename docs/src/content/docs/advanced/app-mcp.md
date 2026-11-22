---
title: App MCP
description: List local, SSH and Monitor targets and run saved command presets from an MCP client
---

Open **Settings → AI → MCP Server**. Choose **New token** to add a named token and save the displayed value. Turn on the switch and connect to `http://127.0.0.1:49762/mcp` with the token as a Bearer credential. Use the delete button next to a named token to revoke it. Every token has the same tools and targets. Deletion takes effect on the next request.

Select **Listen** to change the listening address and port. Choose **All** for the wildcard address, **LAN** to select an IP from a Wi-Fi, Ethernet or VPN interface such as Tailscale, or **This device** for loopback. Presets keep the current port. LAN saves the selected IP, so select it again if your network assigns a different address. **Custom** accepts an address and port such as `[::]:49762`. On another device, connect to the server device’s actual address, for example `http://192.168.1.20:49762/mcp`. The listener uses HTTP, so use a trusted network or a TLS tunnel for remote connections.

For stdio clients, run `python3 /absolute/path/to/scripts/app-mcp-stdio.py` with the token in `SERVERBOX_MCP_TOKEN`. Set `SERVERBOX_MCP_HOST` and `SERVERBOX_MCP_PORT` on the client if its destination differs from `127.0.0.1:49762`. For desktop automation, `SERVERBOX_MCP_POLICY` selects a local registry file when the app has no saved listener preference. The app stores token digests and labels on this device. Named command presets are shared by all clients. An example registry follows.

```json
{
  "tokens": {"<lowercase SHA-256 digest of token>": "Desktop"},
  "commands": {"uptime": "uptime"}
}
```

Call `list` for SSH, Monitor and local target IDs and preset names. The local target `#local` uses the desktop shell, Android proot, or the installed iOS iul guest.

Call `run_command` with `host` and `preset` to execute the exact saved command through the host’s preferred transport. SSH reuses an existing connection or connects with the saved host configuration. If the host key needs approval, a key needs a passphrase, or keyboard-interactive authentication needs an answer, connect in ServerBox first and retry. Monitor uses its authenticated command endpoint and enforces its own access rules. The response contains stdout, stderr, and the exit code when available. Output is limited to 256 KiB combined and SSH command channels close after 30 seconds. Monitor enforces its own execution timeout and reports truncated output or a timeout. Removing all commands hides the preset execution tool.

### Host inspections

Pass the host ID from `list` as the single `host` argument. Inspections run on the selected target and return stdout, stderr and exit status. A missing utility or service manager produces a tool error.

| Tool | Result |
| --- | --- |
| `machine_capabilities` | The App’s platform classification, configured transports and permitted inspections for that platform |
| `machine_status` | Uptime and load, or last boot time on Windows |
| `machine_metrics` | Memory statistics |
| `storage` | Mounted filesystems and capacity |
| `processes` | Process table |
| `services` | Services reported by the platform service manager |
| `containers` | Docker container IDs, names and status |
| `tmux` | tmux sessions on Unix hosts |

Use `cpu`, `network` and `disk_io` for additional metrics. Pass a numeric `pid` to `process_detail` to inspect a single process. Use `images` to list Docker images, then pass the full image ID to `image_inspect` or `image_remove`.

### App settings, containers and services

`app_settings` takes no arguments and lists editable preferences with their current JSON values. `app_setting_set` takes `key` and a typed JSON `value` and writes through the same device store used by the settings page. These are App-wide tools and take no host ID. Discover the allowed types, choices and ranges for each key in the tool’s input schema. For example, set `editorFontSize` to `15.5`, `serverStatusUpdateInterval` to `4` seconds, `motionPref` to `"reduce"`, `trayMetrics` to `["cpu", "disk"]`, or `distNameMap` to `{"arch": "archlinux"}`. Arrays and maps replace the entire setting.

`container_logs` reads the last 100 lines. `container_stats` reads one resource snapshot. Both take a host and a Docker container ID from `containers`. `container_action` takes the same arguments and an `action` of `start`, `stop` or `restart`.

The `locale`, `timeOut` (seconds), and ordered `homeTabs` preferences accept a locale code, integer, and list of tab names respectively. To edit a keyboard shortcut on the current platform, set `keybindings` to a single entry such as `{"settings.search":"Ctrl+Shift+F"}`.

On Linux hosts running systemd, pass a unit name from `services` (for example `demo.service`) as `key` with the `host` ID. `service_logs` reads the last 100 journal entries and `service_action` accepts `start`, `stop` or `restart`. The host account must already have permission.
