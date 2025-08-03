part of 'page.dart';

extension _Keyboard on SSHPageState {
  void _handleEscKeyOrBackButton() {
    _terminal.keyInput(TerminalKey.escape);
    HapticFeedback.lightImpact();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
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
