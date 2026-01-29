---
title: Terminal Settings
description: Configure SSH terminal behavior and appearance
---

The SSH terminal offers extensive customization options for optimal user experience.

## Virtual Keyboard

### Auto Show/Hide

The virtual keyboard can automatically show or hide based on context:

- **Enabled**: Keyboard appears when terminal is focused
- **Disabled**: Manual toggle only via keyboard button

Set in: **Settings > SSH > Virtual Keyboard Auto Off**

### Virtual Keyboard Buttons

The mobile virtual keyboard provides quick-access buttons:

| Button | Function |
|--------|----------|
| **Toggle Keyboard** | Show/hide system keyboard |
| **SFTP** | Open current directory in file browser |
| **Clipboard** | Copy selection OR paste clipboard (context-aware) |
| **Snippets** | Execute saved command snippets |

## Font Settings

### Font Size

- **Global Setting**: `termFontSize` in Settings
- Affects all new terminal sessions
- Recalculates terminal dimensions (rows/columns)
- Range: 8-24 pixels typical

### Per-Session Zoom

- **Pinch Gesture**: Zoom in/out for individual session
- Does not persist across session recreation
- Temporary adjustment only

## Terminal Appearance

### Colors

- **Text Color**: Default text color
- **Background Color**: Terminal background
- **Background Opacity**: Transparency level
- **Blur Effect**: Background blur (iOS/macOS)
- **Cursor Color**: Cursor appearance
- **Selection Color**: Text selection highlight

### Session Management

- **Multi-tab**: Independent SSH sessions per tab
- **Tab Names**: Auto-generated (servername, servername(1), etc.)
- **Session Persistence**: Maintained across navigation
- **Keep-alive**: Connections maintained in background

## Connection Settings

### Timeout

- **Connection Timeout**: How long to wait for connection
- **Read Timeout**: How long to wait for data
- Default: 30 seconds (configurable)

### Host Key Verification

- **Fingerprint Display**: MD5 (aa:bb:cc:...) and Base64 formats
- **Storage**: `{spi.id}::{keyType}` format
- **MITM Detection**: Warns on changed host keys
- **Cache**: Known hosts stored securely

## Advanced Settings

### Environment Variables

Set custom environment variables for SSH sessions:

```bash
EDITOR=vim
LANG=en_US.UTF-8
```

### Initial Directory

Set starting directory for new sessions:
- Default: User's home directory
- Custom: Any absolute path

### Jump Server

Route connections through intermediate servers:

1. Configure jump server first
2. In target server, select jump server from list
3. Connection routes through jump server automatically

## Keyboard Shortcuts

### Desktop

- **Ctrl+T**: New tab
- **Ctrl+W**: Close tab
- **Ctrl+Tab**: Next tab
- **Ctrl+Shift+Tab**: Previous tab

### Virtual Keys

- **Ctrl, Alt, Shift**: Modifier keys
- **Arrow Keys**: Navigation
- **F1-F12**: Function keys
- **Esc, Tab**: Special keys
- **Home, End, Insert, Delete**: Editing keys

## Clipboard Integration

- **Copy**: Drag to select text → auto-copy
- **Paste**: Tap clipboard button
- **Copy Selection**: Special button for copying selection
- **Paste Clipboard**: Special button for pasting
