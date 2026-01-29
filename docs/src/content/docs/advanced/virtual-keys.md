---
title: SSH Virtual Keys
description: Customize SSH terminal virtual keyboard
---

Customize the virtual keyboard that appears when using SSH terminal on mobile devices.

## Accessing Virtual Key Settings

1. Go to **Settings**
2. Find **SSH Virtual Keys** option
3. Tap to open virtual key editor

## What You Can Do

- **Enable/disable keys** - Toggle visibility
- **Reorder keys** - Change layout
- **View key descriptions** - Understand icon meanings

## Default Virtual Keys

| Key | Function |
|-----|----------|
| **Toggle Keyboard** | Show/hide system keyboard |
| **Ctrl** | Control modifier |
| **Alt** | Alt modifier |
| **Shift** | Shift modifier |
| **Tab** | Tab character |
| **Esc** | Escape character |
| **Arrow Keys** | Up/Down/Left/Right |
| **Home/End** | Line navigation |
| **F1-F12** | Function keys |
| **SFTP** | Open current directory in file browser |
| **Clipboard** | Copy/Paste (context-aware) |
| **Snippets** | Execute saved snippet |

## Customizing Layout

### Reordering Keys

1. Long press on key
2. Drag to new position
3. Release to place

### Disabling Keys

1. Find key in list
2. Toggle off
3. Key no longer appears

### Enabling Keys

1. Find disabled key
2. Toggle on
3. Key appears in keyboard

## Key Descriptions

### Modifier Keys

- **Ctrl**: Send Control modifier with next key
- **Alt**: Send Alt modifier (Meta on some systems)
- **Shift**: Send Shift modifier

### Navigation Keys

- **Tab**: Tab character (or autocomplete)
- **Esc**: Escape character
- **Home**: Start of line
- **End**: End of line
- **PgUp/Page Down**: Scroll up/down

### Special Keys

- **SFTP**: Opens current directory in SFTP browser
- **Clipboard**: Smart copy/paste
  - Has text selection: Copy
  - Has clipboard content: Paste
- **Snippets**: Opens snippet list for execution

## Use Cases

### Vim Users

Enable and prioritize:
- Esc
- Colon (:)
- w, q, a, i, o keys

### Systemd Management

Enable:
- F1-F12 (for virtual terminals)
- Ctrl, Alt (for key combinations)

### File Editing

Enable:
- Arrow keys
- Home/End
- Tab
- Esc

## Tips

- **Customize per use case** - Different layouts for different tasks
- **Keep essentials** - Don't disable Ctrl, Esc
- **Test layout** - Try after customizing
- **Reset if needed** - Can restore defaults

## Key Combinations

### Common Shortcuts

- **Ctrl+C**: Cancel/Interrupt
- **Ctrl+D**: EOF/Exit
- **Ctrl+L**: Clear screen
- **Ctrl+A**: Start of line
- **Ctrl+E**: End of line
- **Ctrl+R**: Search history

### Sending Combinations

1. Tap modifier key (Ctrl)
2. Tap other key (C)
3. Both sent together

## Troubleshooting

### Key Not Working

- Check key is enabled
- Verify SSH session is active
- Try system keyboard instead

### Key in Wrong Place

- Reorder keys in settings
- Test new layout
- Adjust as needed

### Can't Find Key

- Check if disabled
- Scroll through full list
- Enable if needed
