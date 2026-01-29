---
title: Custom Commands
description: Add custom commands to server monitoring
---

You can add custom shell commands to display their output on the server detail page.

## Setting Up Custom Commands

1. Open server settings
2. Scroll to **Custom Commands** section
3. Enter commands in JSON format

## JSON Format

```json
{
  "Command Name": "shell command"
}
```

### Example

```json
{
  "Memory": "free -h",
  "Disk Usage": "df -h",
  "Uptime": "uptime"
}
```

## Viewing Results

After setting up custom commands:
1. Open server detail page
2. Find **Custom Commands** card
3. View command outputs
4. Card refreshes automatically

## Special Command Names

### server_card_top_right

Display custom output on home page server card (top-right corner).

```json
{
  "server_card_top_right": "grep Tsensor /proc/msp/pm_cpu | awk '{print $4}'"
}
```

This enables custom temperature display (see [Issue #313](https://github.com/lollipopkit/flutter_server_box/issues/313)).

## Command Tips

### Use Absolute Paths

```json
{
  "My Script": "/usr/local/bin/my-script.sh"
}
```

### Pipe Commands

```json
{
  "Top Process": "ps aux | sort -rk 3 | head -5"
}
```

### Format Output

```json
{
  "CPU Load": "uptime | awk -F'load average:' '{print $2}'"
}
```

## Advanced Examples

### System Information

```json
{
  "Kernel": "uname -r",
  "OS": "cat /etc/os-release | grep PRETTY_NAME",
  "Arch": "uname -m"
}
```

### Network Stats

```json
{
  "Connections": "netstat -an | grep ESTABLISHED | wc -l",
  "Open Ports": "netstat -tuln | grep LISTEN"
}
```

### Hardware Info

```json
{
  "CPU Model": "cat /proc/cpuinfo | grep 'model name' | head -1",
  "RAM Total": "free -h | grep Mem | awk '{print $2}'",
  "Disk Total": "df -h / | tail -1 | awk '{print $2}'"
}
```

## Security Considerations

- Commands run with SSH user permissions
- Avoid commands that modify system state
- Be careful with sensitive data in output
- Test commands before adding to production

## Troubleshooting

### Command Not Showing

- Check JSON syntax is valid
- Verify command works in SSH terminal
- Ensure user has permission to run command
- Check for special characters needing escape

### Output Too Long

- Use `head` to limit output:
  ```json
  {"Logs": "tail -20 /var/log/syslog"}
  ```
- Use `grep` to filter:
  ```json
  {"Errors": "journalctl -n 50 | grep -i error"}
  ```

### Command Timeout

Commands have limited execution time:
- Keep commands fast (< 5 seconds)
- Avoid commands that hang
- Use timeouts where possible:
  ```json
  {"Ping": "ping -c 1 -W 2 google.com"}
  ```
