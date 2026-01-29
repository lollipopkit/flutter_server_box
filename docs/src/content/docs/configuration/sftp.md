---
title: SFTP File Browser
description: File transfer and management via SFTP
---

Browse, edit, and transfer files on your servers with a built-in SFTP client.

## Basic Usage

### Opening SFTP

1. Connect to server
2. Tap **Files** button on server page
3. Or from terminal: Tap **SFTP** button

### Navigation

- **Tap folder**: Enter directory
- **Tap file**: View/Edit/Download options
- **Back button**: Previous directory
- **Home button**: User's home directory
- **Goto button**: Jump to path with autocomplete

## File Operations

### Common Actions

| Action | How |
|--------|-----|
| **Download** | Long-press file → Download |
| **Upload** | Folder icon → Select file |
| **Rename** | Long-press → Rename |
| **Delete** | Long-press → Delete |
| **Copy/Move** | Long-press → Select → Choose destination |
| **Permissions** | Tap file info → Edit permissions |

### Permission Editor

Unix permissions editor:

- **3x3 Grid**: User/Group/Other × Read/Write/Execute
- **Numeric**: Direct input (755, 644, etc.)
- **Symbolic**: rwxr-xr-x format

### Edit Files

1. Tap file → Edit
2. Edit in built-in editor
3. Save → Upload back to server

**Size limit:** ~1 MB for large files, use terminal instead.

**Editor settings:** Settings → SFTP Editor
- Preferred editor (vim, nano, etc.)
- Close after save
- Soft wrap
- Syntax highlighting

## Display Settings

### Sort Order

Settings → Sort By:
- Name (alphabetical)
- Size (largest first)
- Time (newest first)

### Folders First

Show directories before files:
Settings → Folders First

### Hidden Files

Show dotfiles (`.git`, `.bashrc`, etc.):
Settings → Show Hidden Files

## Archive Support

Extract 30+ formats directly on server:

| Format | Command Required |
|--------|------------------|
| .tar.gz | tar |
| .zip | unzip |
| .7z | 7z |
| .rar | unrar |

Must be installed on server.

## Quick Access

### From Terminal

Tap **SFTP** button to open current terminal directory in file browser.

### Remember Last Path

Automatically return to last visited directory:
Settings → SFTP Open Last Path

## Troubleshooting

### Permission Denied

- Check user has read access to directory
- Verify directory permissions: `ls -la`
- Ensure SFTP is enabled in sshd_config

### Slow Listing

Large directories (1000+ items) use pagination for performance.

### Can't Edit File

File too large (>1 MB)? Use terminal with vim/nano instead.
