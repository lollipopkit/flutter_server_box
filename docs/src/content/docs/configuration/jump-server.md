---
title: Jump Server
description: Configure jump servers for multi-hop connections
---

Jump servers allow you to route connections through intermediate servers, useful for:

- Accessing private network resources
- Multi-hop SSH connections
- Bastion host configurations
- Reduced attack surface

## Setting Up Jump Servers

### 1. Create Jump Server

Add jump server as a normal server first:

1. Add server with jump host details
2. Ensure SSH key or password authentication works
3. Test connection

### 2. Configure Target Server

For servers reachable via jump host:

1. Add or edit target server
2. Find **Jump Server** option
3. Select jump server from list
4. Save configuration

## How It Works

```
Your Device → Jump Server → Target Server
```

The connection flows through:

1. **First Hop**: Connect to jump server
2. **Tunnel**: Establish SSH tunnel through jump
3. **Second Hop**: Connect to target via tunnel
4. **Session**: Full SSH session to target

## Authentication

### Jump Server Authentication

Jump server can use:

- **Password**: Stored securely
- **SSH Key**: Preferred for security
- **Keyboard-Interactive**: Supported

### Target Server Authentication

Target server authentication same as direct connection:

- **Password**: Authenticated through tunnel
- **SSH Key**: Forwarded agent (optional)
- **Same User**: Can use same or different credentials

## Configuration Options

### Jump Server Selection

When adding/editing server:

- **Jump Server**: Dropdown of available servers
- **None**: Direct connection (default)
- **Server Name**: Use as jump host

### Alternative URL

Fallback connection method:

**Setting**: `alterUrl`

If direct connection fails:
1. Try primary URL/host
2. On failure, try alternative URL
3. Useful for:
   - Multiple interfaces
   - DNS fallback
   - Backup connections

## Advanced Scenarios

### Nested Jump Servers

Chain multiple jump servers:

```
Device → Jump1 → Jump2 → Target
```

1. Configure Jump2 with Jump1 as jump server
2. Configure Target with Jump2 as jump server
3. Each hop authenticates independently

### Port Forwarding

Jump servers support local port forwarding:

```
Local Port → Jump Server → Remote Host:Port
```

Useful for:
- Database access
- Web interface access
- Service tunneling

## Troubleshooting

### Connection Refused

- Verify jump server is accessible
- Check jump server SSH service
- Ensure firewall allows connection

### Authentication Failed

- Verify credentials for jump server
- Check jump server has permission to reach target
- Ensure SSH agent forwarding (if using keys)

### Performance Issues

- Jump server adds latency
- Consider direct connection if possible
- Use jump server closer to target

### Connection Timeouts

Increase timeout values:
**Settings > Connection Timeout**

## Security Considerations

### Trust

- Jump server can see all traffic
- Use trusted jump hosts only
- Consider end-to-end encryption for sensitive data

### Key Management

- SSH keys on jump server are risk
- Use agent forwarding cautiously
- Consider certificate-based authentication

### Access Control

- Limit jump server access to authorized users
- Monitor jump server logs
- Use separate credentials for jump vs target

## Best Practices

1. **Dedicated Jump Host**: Use separate server as jump host
2. **SSH Keys**: Prefer key-based authentication
3. **Monitoring**: Log and monitor jump server access
4. **Minimal Access**: Jump server should only route traffic
5. **Keep Updated**: Regular security updates
