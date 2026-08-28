---
title: Terminal Implementation
description: How the Server Box terminal works
---

The terminal is built on a custom `xterm.dart` fork. Its UI is shared across SSH, local, Alpine, and Monitor agent sessions.

## Where the bytes come from

Everything above the byte stream uses one implementation: the same emulator, virtual keyboard, and tabs. `ShellBackend` has these implementations:

| Backend | Byte source |
|---|---|
| `SshShellBackend` | An SSH channel; this page focuses on this path |
| `LocalShellBackend` | A shell on this device, or an Alpine environment on Android |
| `IshShellBackend` | The Linux interpreter on iOS |
| `MonitorShellBackend` | Monitor agent's `/api/v1/terminal/ws` endpoint |

The caller opens a session and reads or writes bytes without knowing which backend supplies them. See [Terminal on This Device](/docs/advanced/local-terminal/) for local backends and [Monitor Agent](/docs/advanced/monitor-agent/) for the Monitor backend.

The sections below describe the SSH path. Other backends expose the same upper-level interface.

## Architecture overview

```text
┌─────────────────────────────────────────────┐
│ Terminal UI layer                            │
│ Tabs, virtual keyboard, text selection       │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ xterm.dart emulator                          │
│ PTY, VT100/ANSI emulation, rendering         │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ SSH client layer                             │
│ Sessions, channels, and byte streams          │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ Remote server                                │
│ Shell process, PTY, and command execution    │
└─────────────────────────────────────────────┘
```

## Terminal session lifecycle

### Session creation

```dart
Future<TerminalSession> createSession(Spi spi) async {
  final session = TerminalSession(source: ServerSource(spi));
  await session.connect();
  final shell = await session.openShell();
  if (shell == null) throw StateError('No shell backend');
  session.bindForeground(shell);
  return session;
}
```

The SSH backend creates a PTY with `SSHPtyConfig` and owns the shell lifecycle. `TerminalSession` is also used by local and Monitor agent backends.

### Terminal emulation

The xterm.dart fork provides:

**VT100/ANSI emulation:**

- Cursor movement
- 256 colors
- Text attributes such as bold and underline
- Scrolling regions
- Alternate screen buffer

**Rendering:**

- Line-based rendering
- Bidirectional text
- Unicode and Emoji
- Redraws limited to changed terminal content

### Data flow

```text
User input
    ↓
Virtual or physical keyboard
    ↓
Terminal emulator (key → escape sequence)
    ↓
SSH channel (send)
    ↓
Remote PTY
    ↓
Remote shell
    ↓
Command output
    ↓
SSH channel (receive)
    ↓
Terminal emulator (parse ANSI sequences)
    ↓
Render to screen
```

## Multiple tabs

Each tab owns an independent terminal session. When you navigate away, the session and terminal state remain available:

- The SSH connection stays alive until it closes or the session is disposed.
- Terminal state is preserved.
- The scrollback buffer is preserved.
- Input history is preserved.

When multiple tabs use one server, tab names include a number to distinguish them.

## Virtual keyboard

The virtual keyboard is a cross-platform Flutter Widget rendered above the terminal. Available keys are defined in `lib/data/model/ssh/virtual_key.dart`. On mobile, it can appear alongside the system keyboard.

| Key | Action |
|---|---|
| **Esc / Tab / Home / End / PgUp / PgDn / arrows** | Send the corresponding key |
| **Ctrl / Alt / Shift** | Apply a modifier to the next key |
| **IME** | Show or hide the system keyboard |
| **Clipboard** | Copy or paste according to the current context |
| **SFTP** | Open the current directory in the SFTP browser |
| **Snippet** | Select and execute a saved command snippet |
| **Symbols** | Enter `/ \\ _ + = - ( ) [ ] { } < >` and other symbols |

The key set and order are customizable in settings.

## Text selection

1. Long-press terminal text to enter selection mode.
2. Drag to extend the selection.
3. Release to copy it to the clipboard.

## Font and dimensions

The terminal calculates its rows and columns from the font size and available space:

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

On mobile, pinch-to-zoom changes the terminal font size and recalculates the PTY dimensions.

## Color schemes

- **Light**: Light background and dark text
- **Dark**: Dark background and light text
- **AMOLED**: Pure black background

## Performance

The xterm.dart fork uses a custom painter and repaints only when terminal content changes. Remote output is buffered and coalesced before it reaches the emulator, reducing the cost of many small updates.

## Special features

- **Snippet execution** inserts a saved command into the terminal and executes it.
- **SFTP quick access** opens the SFTP browser at the terminal's current working directory.
- **Shared backends** let local shells, Alpine environments, and Monitor terminals use the same upper-level terminal UI as SSH.

## Keep-alive

SSH keep-alive messages operate at the protocol layer. They are separate from bytes typed into or displayed by the terminal; see [SSH Connection](/docs/principles/ssh/).
