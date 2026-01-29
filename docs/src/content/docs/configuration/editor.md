---
title: Editor Settings
description: Configure the built-in code editor
---

Flutter Server Box includes a built-in code editor for editing remote files directly.

## Editor Preferences

### Close After Save

Automatically close editor after saving changes:

**Setting**: `closeAfterSave`

- **Enabled**: Quick edit workflow
- **Disabled**: Keep editor open for multiple changes

### Soft Wrap

Wrap long lines to fit screen width:

**Setting**: `editorSoftWrap`

- **Enabled**: No horizontal scrolling
- **Disabled**: Horizontal scroll for long lines

### Syntax Highlighting

Enable code syntax highlighting:

**Setting**: `editorHighlight`

Supports:
- Shell scripts
- Configuration files
- JSON/YAML
- And many more

## File Size Limit

Maximum file size for editing:

**Setting**: `Miscs.editorMaxSize` (~1 MB)

Files exceeding this limit:
- Show warning message
- Suggest external editor
- Can still be viewed (read-only)

## External Editor

For larger files or prefered editors, use external editor via SSH:

**Setting**: `sftpEditor`

### Supported Editors

```bash
vim        # Vi IMproved
nano       # Simple text editor
emacs      # GNU Emacs
code       # VS Code (remote)
```

### Using External Editor

1. Set `sftpEditor` to preferred editor
2. Open terminal
3. Edit file: `vim /path/to/file`
4. Save and exit
5. Changes reflected in SFTP browser

## File Encoding

### Default Encoding

UTF-8 encoding by default for compatibility.

### Detection

Automatic encoding detection for:
- UTF-8
- ASCII
- Latin-1
- Common encodings

## Edit Workflow

### Quick Edit

1. Tap file in SFTP browser
2. File opens in editor
3. Make changes
4. Tap save
5. File uploaded to server

### Large Files

1. Tap file in SFTP browser
2. Warning shows file size
3. Choose "Open in Terminal"
4. Edit with external editor
5. Refresh SFTP browser to see changes

## Keyboard Shortcuts

### Mobile

- **Save**: Tap save icon
- **Close**: Tap close icon
- **Undo**: Tap undo icon
- **Redo**: Tap redo icon

### Desktop

- **Cmd/Ctrl+S**: Save
- **Cmd/Ctrl+W**: Close
- **Cmd/Ctrl+Z**: Undo
- **Cmd/Ctrl+Shift+Z**: Redo
- **Cmd/Ctrl+F**: Find

## Editor UI

### Line Numbers

Display line numbers for reference:

**Setting**: Show Line Numbers

### Font Size

Adjust editor font size independently:

**Setting**: Editor Font Size

### Theme

Editor theme follows app theme:
- Light
- Dark
- AMOLED

## Tips

- Use **Close After Save** for quick config edits
- Use **Soft Wrap** for viewing log files
- Use **External Editor** for complex files
- **Line Numbers** helpful for debugging
