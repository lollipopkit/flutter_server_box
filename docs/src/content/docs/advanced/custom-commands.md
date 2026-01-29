---
title: Custom Commands
description: Display custom command output on server page
---

Add custom shell commands to show their output on the server detail page.

## Setup

1. Server settings → Custom Commands
2. Enter commands in JSON format

## Basic Format

```json
{
  "Display Name": "shell command"
}
```

**Example:**
```json
{
  "Memory": "free -h",
  "Disk": "df -h",
  "Uptime": "uptime"
}
```

## Viewing Results

After setup, custom commands appear on server detail page and refresh automatically.

## Special Command Names

### server_card_top_right

Display on home page server card (top-right corner):

```json
{
  "server_card_top_right": "your-command-here"
}
```

## Tips

**Use absolute paths:**
```json
{"My Script": "/usr/local/bin/my-script.sh"}
```

**Pipe commands:**
```json
{"Top Process": "ps aux | sort -rk 3 | head -5"}
```

**Format output:**
```json
{"CPU Load": "uptime | awk -F'load average:' '{print $2}'"}
```

**Keep commands fast:** Under 5 seconds for best experience

**Limit output:**
```json
{"Logs": "tail -20 /var/log/syslog"}
```

## Security

Commands run with SSH user permissions. Avoid commands that modify system state.
