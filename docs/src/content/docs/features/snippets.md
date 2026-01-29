---
title: Snippets
description: Save and execute custom shell commands
---

Snippets allow you to save frequently used shell commands for quick execution.

## Creating Snippets

1. Go to the **Snippets** tab
2. Tap the **+** button
3. Fill in snippet details:
   - **Name**: Friendly name for the snippet
   - **Command**: The shell command to execute
   - **Description**: Optional notes
4. Save the snippet

## Using Snippets

1. Open a server
2. Tap the **Snippet** button
3. Select a snippet to execute
4. View output in the terminal

## Snippet Features

- **Quick Execute**: One-tap command execution
- **Variables**: Use server-specific variables
- **Organization**: Group related snippets
- **Import/Export**: Share snippets between devices
- **Sync**: Optional cloud sync

## Example Snippets

### System Update
```bash
sudo apt update && sudo apt upgrade -y
```

### Disk Cleanup
```bash
sudo apt autoremove -y && sudo apt clean
```

### Docker Cleanup
```bash
docker system prune -a
```

### View System Logs
```bash
journalctl -n 50 -f
```

## Tips

- Use **descriptive names** for easy identification
- Add **comments** for complex commands
- Test commands before saving as snippets
- Organize snippets by category or server type
