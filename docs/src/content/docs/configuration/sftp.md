---
title: SFTP Settings
description: Configure SFTP file browser behavior
---

Customize the SFTP file browser for your workflow.

## Display Options

### Folders First

Display directories before files in listings:

**Setting**: `sftpShowFoldersFirst`

- **Enabled**: Folders appear at top
- **Disabled**: Mixed sorting

### Sorting Options

Sort files by:

- **Name**: Alphabetical (case-insensitive)
- **Size**: File size in bytes
- **Time**: Modification time (Unix timestamp)

### Hidden Files

Toggle visibility of dotfiles (files starting with `.`):

**Setting**: Show Hidden Files

## Path Management

### Remember Last Path

Automatically return to last visited directory:

**Setting**: `sftpOpenLastPath`

- **Enabled**: Saves last path per server
- **Disabled**: Always start at home directory

### Navigation Options

- **Back**: Navigate to previous directory
- **Home**: Go to user's home (`/home/$user` or `/root`)
- **Goto**: Jump to specific path with autocomplete history

## File Operations

### Permission Editing

Built-in Unix permission editor:

- **3x3 Grid**: User/Group/Other × Read/Write/Execute
- **Numeric Mode**: Direct octal input (755, 644, etc.)
- **Symbolic Mode**: rwxr-xr-x format

### Decompression

Support for 30+ archive formats via SSH:

| Format | Command |
|--------|---------|
| tar.gz | `tar -xzf` |
| zip | `unzip` |
| 7z | `7z x` |
| rar | `unrar x` |

Requires corresponding utilities installed on server.

## Transfer Settings

### Transfer Queue

- **Concurrent Transfers**: Multiple simultaneous operations
- **Progress Display**: Percentage and time elapsed
- **Cancel**: Stop pending/in-progress transfers
- **Auto-retry**: Resume interrupted transfers

### Local Storage Pattern

Downloaded files stored at:

```
Paths.file/{serverId}/{normalizedRemotePath}
```

## Editor Integration

### External Editor

Set preferred editor for remote file editing:

**Setting**: `sftpEditor`

Options:
- `vim`
- `nano`
- `emacs`
- Any editor available on server

### Edit Workflow

1. Download file to local cache
2. Open in editor
3. Save uploads back to server
4. Size limit: ~1 MB (`Miscs.editorMaxSize`)

### Editor Settings

- **Close After Save**: `closeAfterSave`
- **Soft Wrap**: `editorSoftWrap`
- **Syntax Highlighting**: `editorHighlight`

## Quick Access

From terminal, tap **SFTP** button to open current directory in file browser.

## Performance

### Large Directories

- Pagination for directories with 1000+ items
- Lazy loading for better performance
- Cache for recently accessed directories

### Cache Settings

- Directory listing cache
- File metadata cache
- Configurable cache duration

## Troubleshooting

### Permission Denied

- Check user has read access
- Verify directory permissions
- Ensure SFTP subsystem enabled in sshd_config

### Slow Listing

- Reduce cache duration
- Check network latency
- Consider using jump server for remote locations
