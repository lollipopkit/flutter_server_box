---
title: Proxmox (PVE)
description: Proxmox Virtual Environment management
---

Flutter Server Box includes support for managing Proxmox VE virtualization platform.

## Features

### VM Management

- **List VMs**: View all virtual machines
- **VM Status**: Check running/stopped states
- **VM Actions**: Start, stop, restart VMs
- **VM Details**: View configuration and resources

### Container (LXC) Management

- **List Containers**: View all LXC containers
- **Container Status**: Monitor container states
- **Container Actions**: Start, stop, restart containers
- **Console Access**: Terminal access to containers

### Node Monitoring

- **Resource Usage**: CPU, memory, disk, network
- **Node Status**: Check node health
- **Cluster View**: Multi-node cluster overview

## Setup

### Adding PVE Server

1. Add server as normal SSH connection
2. Ensure user has PVE permissions
3. Access PVE features from server detail page

### Permissions Required

PVE user needs:

- **VM.Audit**: View VM status
- **VM.PowerMgmt**: Start/stop VMs
- **VM.Console**: Console access

Example permissions setup:

```bash
pveum useradd myuser -password mypass
pveum aclmod /vms -user myuser@pve -role VMAdmin
```

## Usage

### VM Management

1. Open server with PVE
2. Tap **PVE** button
3. View VM list
4. Tap VM for details
5. Use action buttons for management

### Container Management

1. Open server with PVE
2. Tap **PVE** button
3. Switch to Containers tab
4. View and manage LXC containers

### Monitoring

- Real-time resource usage
- Historical data charts
- Multiple node support

## Features by Status

### Implemented

- VM listing and status
- Container listing and status
- Basic VM operations (start/stop/restart)
- Resource monitoring

### Planned

- VM creation from templates
- Snapshot management
- Console access
- Storage management
- Network configuration

## Requirements

- **PVE Version**: 6.x or 7.x
- **Access**: SSH access to PVE host
- **Permissions**: Appropriate PVE user roles
- **Network**: Connectivity to PVE API (via SSH)

## Tips

- Use **dedicated PVE user** with limited permissions
- Monitor **resource usage** for optimal performance
- Check **VM status** before maintenance
- Use **snapshots** before major changes
