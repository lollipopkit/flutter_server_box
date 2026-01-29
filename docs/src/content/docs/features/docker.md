---
title: Docker Management
description: Monitor and manage Docker containers
---

Server Box provides an intuitive interface for managing Docker containers on your servers.

## Features

### Container List

- View all containers (running and stopped)
- Container ID and name display
- Image information
- Status indicators
- Creation time

### Container Actions

- **Start**: Launch stopped containers
- **Stop**: Gracefully stop running containers
- **Restart**: Restart containers
- **Remove**: Delete containers
- **View Logs**: Check container logs
- **Inspect**: View container details

### Container Details

- Environment variables
- Port mappings
- Volume mounts
- Network configuration
- Resource usage

## Requirements

- Docker must be installed on your server
- SSH user must have Docker permissions
- For non-root users, add to docker group:
  ```bash
  sudo usermod -aG docker your_username
  ```

## Quick Actions

- Single tap: View container details
- Long press: Quick action menu
- Swipe: Quick start/stop
- Bulk select: Multiple container operations

## Tips

- Use **auto-refresh** to monitor container status changes
- Filter by running/stopped containers
- Search containers by name or ID
