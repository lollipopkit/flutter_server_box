---
title: Jump Server
description: Route connections through intermediate servers
---

Connect to servers behind firewalls or in private networks by routing through an intermediate jump server.

## What is Jump Server?

A jump server acts as a gateway to access other servers that:
- Are behind firewalls
- Don't have direct SSH access
- Are in private networks
- Require multi-hop connections

## Setup

### Step 1: Configure Jump Server

Add the jump server as a normal server first:
1. Add server with SSH credentials
2. Test connection to ensure it works
3. This server will be your jump host

### Step 2: Configure Target Servers

For each server you want to access via jump:
1. Add target server (credentials for target, not jump)
2. Server settings → Jump Server
3. Select your jump server from list
4. Save

### Step 3: Connect

Connect to target server normally. The app automatically:
1. Connects to jump server
2. Tunnels through to target server
3. Maintains connection

## Use Cases

### Private Network Access

```
Your Device → Jump Server (public IP) → Private Server (10.0.0.x)
```

### Behind Firewall

```
Your Device → Bastion Host → Internal Server
```

### Multi-Hop

You can chain multiple jump servers for complex networks.

## Requirements

- Jump server must be accessible from your device
- Jump server must be able to reach target servers
- SSH keys recommended for jump server (faster authentication)

## Tips

- **Use SSH keys** on jump server for faster connections
- **Test direct access** to jump server first
- **Check firewall rules** on both ends
- **Monitor connection** - issues could be on jump or target

## Troubleshooting

### Connection Times Out

- Verify jump server is accessible
- Check jump server can reach target
- Test manually: `ssh -J jump@jump-server user@target-server`

### Authentication Fails

- Verify credentials for target server (not jump)
- Check SSH keys if using key authentication

### Slow Connection

- Normal for jump connections (extra hop)
- Consider using SSH keys for faster auth
- Check network latency to jump server
