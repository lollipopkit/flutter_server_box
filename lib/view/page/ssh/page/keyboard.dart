part of 'page.dart';

extension _Keyboard on SSHPageState {
  void _handleEscKeyOrBackButton() {
    _terminal.keyInput(TerminalKey.escape);
    HapticFeedback.lightImpact();
  }

  /// Whether the keyboard in front of this terminal follows Apple's
  /// conventions: Command for the app's own chords, Option for composing.
  ///
  /// iPadOS as well as macOS. An iPad with a hardware keyboard has the same
  /// keys and the same habits, and this is the same question
  /// [hostTerminalPlatform] answers for the keytab — Option+Left is `\Eb`
  /// there too.
  bool get _appleKeyboard => isMacOS || isIOS;

  /// Whether this looks like "copy" on this platform — see [isClipboardChord],
  /// which holds the rule and the reason Ctrl+C is not one of them.
  bool _isClipboardChord(KeyEvent event, LogicalKeyboardKey key) {
    final keys = HardwareKeyboard.instance;
    return isClipboardChord(
      pressed: event.logicalKey,
      key: key,
      onMacOS: _appleKeyboard,
      meta: keys.isMetaPressed,
      control: keys.isControlPressed,
      shift: keys.isShiftPressed,
    );
  }

  /// The line editing Command does on a Mac, as the control characters a shell
  /// already understands.
  ///
  /// These cannot go through the terminal the way Option+Left does. `keyInput`
  /// takes shift, alt and ctrl and **no meta**, and the keytab has no Command
  /// entry to match — so a Command chord reaches the terminal as nothing at
  /// all. Intercepted here for the same reason the clipboard chords are.
  ///
  /// Sent as `Ctrl+letter` rather than as an escape sequence, because that is
  /// what readline and every shell's own line editor bind: `^U` kills to the
  /// start of the line, `^A` and `^E` go to its ends. A terminal application
  /// that rebinds them gets its own binding, which is correct.
  /// Not `const`: `LogicalKeyboardKey` overrides `==`, which a constant map's
  /// keys may not.
  static final _commandChords = {
    LogicalKeyboardKey.backspace: 0x55, // U — kill to line start
    LogicalKeyboardKey.arrowLeft: 0x41, // A — line start
    LogicalKeyboardKey.arrowRight: 0x45, // E — line end
  };

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Before the rest: a chord is not the key it is built on.
      if (_isClipboardChord(event, LogicalKeyboardKey.keyC)) {
        // Only with something selected. Otherwise it is not a copy, and
        // swallowing it would take the chord away from whatever else wants it.
        if (_terminalController.selection == null) return false;
        unawaited(_onClipboardAction());
        return true;
      }
      if (_isClipboardChord(event, LogicalKeyboardKey.keyV)) {
        unawaited(_onTerminalPaste());
        return true;
      }
      // After the clipboard chords, which are also Command and are named
      // keys this does not carry.
      if (_appleKeyboard && HardwareKeyboard.instance.isMetaPressed) {
        final letter = _commandChords[event.logicalKey];
        if (letter != null) {
          _terminal.charInput(letter, ctrl: true);
          return true;
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        // Prevent default behavior and send to terminal
        _handleEscKeyOrBackButton();
        return true; // Mark as handled so it doesn't propagate
      }
      if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
          event.logicalKey == LogicalKeyboardKey.shiftRight) {
        // Handle shift key press
        _terminal.keyInput(TerminalKey.shift);
        HapticFeedback.lightImpact();
        return true;
      }
    }
    return false; // Let other handlers process this event
  }
}
