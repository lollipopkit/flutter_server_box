---
title: Terminal Implementation
description: How the SSH terminal works internally
---

The SSH terminal is one of the most complex features, built on a custom xterm.dart fork.

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│          Terminal UI Layer                  │
│  - Tab management                           │
│  - Virtual keyboard                         │
│  - Text selection                           │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│         xterm.dart Emulator                 │
│  - PTY (Pseudo Terminal)                    │
│  - VT100/ANSI emulation                     │
│  - Rendering engine                         │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│          SSH Client Layer                   │
│  - SSH session                              │
│  - Channel management                       │
│  - Data streaming                           │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│          Remote Server                      │
│  - Shell process                            │
│  - Command execution                        │
└─────────────────────────────────────────────┘
```

## Terminal Session Lifecycle

### 1. Session Creation

```dart
Future<TerminalSession> createSession(Spi spi) async {
  // 1. Get SSH client
  final client = await genClient(spi);

  // 2. Create PTY
  final pty = await client.openPty(
    term: 'xterm-256color',
    cols: 80,
    rows: 24,
  );

  // 3. Initialize terminal emulator
  final terminal = Terminal(
    backend: PtyBackend(pty),
  );

  // 4. Setup resize handler
  terminal.onResize.listen((size) {
    pty.resize(size.cols, size.rows);
  });

  return TerminalSession(
    terminal: terminal,
    pty: pty,
    client: client,
  );
}
```

### 2. Terminal Emulation

The xterm.dart fork provides:

**VT100/ANSI Emulation:**
- Cursor movement
- Colors (256-color support)
- Text attributes (bold, underline, etc.)
- Scrolling regions
- Alternate screen buffer

**Rendering:**
- Line-based rendering
- Bidirectional text support
- Unicode/emoji support
- Optimized redraws

### 3. Data Flow

```
User Input
    ↓
Virtual Keyboard / Physical Keyboard
    ↓
Terminal Emulator (key → escape sequence)
    ↓
SSH Channel (send)
    ↓
Remote PTY
    ↓
Remote Shell
    ↓
Command Output
    ↓
SSH Channel (receive)
    ↓
Terminal Emulator (parse ANSI codes)
    ↓
Render to Screen
```

## Multi-Tab System

### Tab Management

```dart
class TerminalTabs {
  final Map<String, TabData> _tabs = {};
  String? _activeTabId;

  void createTab(Server server) {
    final id = _generateTabId(server);
    _tabs[id] = TabData(
      id: id,
      name: _generateTabName(server),
      session: createSession(server),
    );
    _activeTabId = id;
  }

  String _generateTabName(Server server) {
    final count = _tabs.values
        .where((t) => t.name.startsWith(server.name))
        .length;
    return count == 0 ? server.name : '${server.name}($count)';
  }
}
```

### Session Persistence

Tabs maintain state across navigation:

- SSH connection kept alive
- Terminal state preserved
- Scroll buffer maintained
- Input history retained

## Virtual Keyboard

### Platform-Specific Implementation

**iOS:**
- UIView-based custom keyboard
- Toggleable with keyboard button
- Auto-show/hide based on focus

**Android:**
- Custom input method
- Integrated with system keyboard
- Quick action buttons

### Keyboard Buttons

| Button | Action |
|--------|--------|
| **Toggle** | Show/hide system keyboard |
| **Ctrl** | Send Ctrl modifier |
| **Alt** | Send Alt modifier |
| **SFTP** | Open current directory |
| **Clipboard** | Copy/Paste context-aware |
| **Snippets** | Execute snippet |

### Key Encoding

```dart
String encodeKey(Key key) {
  switch (key) {
    case Key.enter:
      return '\r';
    case Key.tab:
      return '\t';
    case Key.escape:
      return '\x1b';
    case Key.ctrlC:
      return '\x03';
    // ... more keys
  }
}
```

## Text Selection

### Selection Mode

1. **Long press**: Enter selection mode
2. **Drag**: Extend selection
3. **Release**: Copy to clipboard

### Selection Storage

```dart
class TextSelection {
  final BufferRange range;
  final String text;

  void copyToClipboard() {
    Clipboard.setData(ClipboardData(text: text));
  }
}
```

## Font and Dimensions

### Size Calculation

```dart
class TerminalDimensions {
  static Size calculate(double fontSize, Size screenSize) {
    final charWidth = fontSize * 0.6;  // Monospace aspect ratio
    final charHeight = fontSize * 1.2;

    final cols = (screenSize.width / charWidth).floor();
    final rows = (screenSize.height / charHeight).floor();

    return Size(cols.toDouble(), rows.toDouble());
  }
}
```

### Pinch-to-Zoom

```dart
GestureDetector(
  onScaleStart: () => _baseFontSize = currentFontSize,
  onScaleUpdate: (details) {
    final newFontSize = _baseFontSize * details.scale;
    resize(newFontSize);
  },
)
```

## Color Scheme

### ANSI Color Mapping

```dart
const colorMap = {
  0: Color(0x000000),  // Black
  1: Color(0x800000),  // Red
  2: Color(0x008000),  // Green
  3: Color(0x808000),  // Yellow
  4: Color(0x000080),  // Blue
  5: Color(0x800080),  // Magenta
  6: Color(0x008080),  // Cyan
  7: Color(0xC0C0C0),  // White
  // ... 256-color palette
};
```

### Theme Support

- **Light**: Light background, dark text
- **Dark**: Dark background, light text
- **AMOLED**: Pure black background

## Performance Optimizations

### Rendering Optimizations

- **Dirty rectangle**: Only redraw changed regions
- **Line caching**: Cache rendered lines
- **Lazy scrolling**: Virtual scrolling for long buffers

### Data Optimizations

- **Batch updates**: Coalesce multiple writes
- **Compression**: Compress scroll buffer
- **Debouncing**: Debounce rapid inputs

## Clipboard Integration

### Copy Selection

```dart
void copySelection() {
  final selected = terminal.getSelection();
  Clipboard.setData(ClipboardData(text: selected));
}
```

### Paste Clipboard

```dart
Future<void> pasteClipboard() async {
  final data = await Clipboard.getData('text/plain');
  if (data?.text != null) {
    terminal.paste(data!.text!);
  }
}
```

### Context-Aware Button

- **Has selection**: Show "Copy"
- **Has clipboard**: Show "Paste"
- **Both**: Show primary action

## Special Features

### Snippet Execution

```dart
void executeSnippet(Snippet snippet) {
  final formatted = formatSnippet(snippet);
  terminal.paste(formatted);
  terminal.paste('\r');  // Execute
}
```

### SFTP Quick Access

```dart
void openSftp() async {
  final cwd = await terminal.getCurrentWorkingDirectory();
  Navigator.push(
    context,
    SftpPage(initialPath: cwd),
  );
}
```

### Keep-Alive

```dart
Timer.periodic(Duration(seconds: 30), (_) {
  if (terminal.isActive) {
    terminal.send('\x00');  // NUL - no-op keep-alive
  }
});
```
