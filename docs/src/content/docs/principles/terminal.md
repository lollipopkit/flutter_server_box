---
title: Terminal Implementation
description: How the SSH terminal works internally
---

The terminal is one of the most complex features, built on a custom xterm.dart fork.

## Where the bytes come from

Everything above the byte stream is one implementation — the same emulator, the
same virtual keyboard, the same tabs. Below it, `ShellBackend` has four:

| Backend | Bytes from |
|---|---|
| `SshShellBackend` | An SSH channel; the rest of this page |
| `LocalShellBackend` | A shell on this device, or inside the Alpine container on Android |
| `IshShellBackend` | The Linux interpreter on iOS |
| `MonitorShellBackend` | A monitor agent's `/terminal/ws` |

A caller opens a session and writes to it; which of the four answered is not
something the UI above asks. See
[Terminal on This Device](/docs/advanced/local-terminal/) for the two local ones
and [Monitor Agent](/docs/advanced/monitor-agent/) for the last.

The rest of this page follows the SSH path, which is the oldest and the one the
others were shaped to match.

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

The virtual keyboard is a Flutter widget rendered above the terminal on all
platforms (`lib/data/model/ssh/virtual_key.dart` defines the available keys),
shown together with the system keyboard on mobile.

### Keyboard Buttons

| Button | Action |
|--------|--------|
| **Esc / Tab / Home / End / PgUp / PgDn / arrows** | Send the corresponding key |
| **Ctrl / Alt / Shift** | Toggle modifier for the next key |
| **IME** | Show/hide system keyboard |
| **Clipboard** | Copy selection / paste, context-aware |
| **SFTP** | Open the current directory in the SFTP browser |
| **Snippet** | Pick and execute a snippet |
| **Symbols** | `/ \ _ + = - ( ) [ ] { } < >` and more |

The key set and order are customizable in settings.

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

## Performance

The xterm.dart fork renders with a custom painter and only repaints on terminal
updates; output writes are buffered and coalesced before being fed to the
emulator.

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

Connections are kept alive at the SSH protocol layer (see the
[SSH Connection](/docs/principles/ssh/) page), not by injecting bytes into the
terminal.
