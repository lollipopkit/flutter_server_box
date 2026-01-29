---
title: Process & Services
description: Monitor processes and manage systemd services
---

## Process Management

View and manage running processes on your servers.

### Process List

- All running processes with details
- PID (Process ID)
- CPU and memory usage
- User ownership
- Process command

### Process Actions

- **Kill**: Terminate processes
- **Filter**: By name or user
- **Sort**: By CPU, memory, or PID
- **Search**: Find specific processes

## Systemd Services

Manage systemd services for service control.

### Service List

- All systemd services
- Active/inactive status
- Enabled/disabled state
- Service description

### Service Actions

- **Start**: Launch a stopped service
- **Stop**: Stop a running service
- **Restart**: Restart a service
- **Enable**: Enable auto-start on boot
- **Disable**: Disable auto-start
- **View Status**: Check service status and logs
- **Reload**: Reload service configuration

## Requirements

- SSH user must have appropriate permissions
- For service management: `sudo` access may be required
- Process viewing: Standard user permissions usually sufficient

## Tips

- Use process list to identify resource hogs
- Check service logs for troubleshooting
- Monitor critical services with auto-refresh
