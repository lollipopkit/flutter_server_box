part of 'page.dart';

extension _Keyboard on SSHPageState {
  void _handleEscKeyOrBackButton() {
    _terminal.keyInput(TerminalKey.escape);
    HapticFeedback.lightImpact();
  }

  /// Whether this looks like "copy" on this platform — see [isClipboardChord],
  /// which holds the rule and the reason Ctrl+C is not one of them.
  bool _isClipboardChord(KeyEvent event, LogicalKeyboardKey key) {
    final keys = HardwareKeyboard.instance;
    return isClipboardChord(
      pressed: event.logicalKey,
      key: key,
      onMacOS: isMacOS,
      meta: keys.isMetaPressed,
      control: keys.isControlPressed,
      shift: keys.isShiftPressed,
    );
  }

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
