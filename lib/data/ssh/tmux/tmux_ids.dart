bool _isValidTmuxId(String value, String prefix) {
  if (value.length <= 1 || !value.startsWith(prefix)) return false;
  for (var i = 1; i < value.length; i++) {
    final code = value.codeUnitAt(i);
    if (code < 0x30 || code > 0x39) return false;
  }
  return true;
}

/// A tmux session ID, prefixed with `$`.
final class TmuxSessionId {
  final String value;

  const TmuxSessionId(this.value);

  factory TmuxSessionId.parse(String value) {
    if (!_isValidTmuxId(value, r'$')) {
      throw ArgumentError.value(
        value,
        'value',
        'tmux session IDs are \$ followed by digits',
      );
    }
    return TmuxSessionId(value);
  }

  static TmuxSessionId? tryParse(String value) =>
      _isValidTmuxId(value, r'$') ? TmuxSessionId(value) : null;

  @override
  bool operator ==(Object other) =>
      other is TmuxSessionId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// A tmux window ID, prefixed with `@`.
final class TmuxWindowId {
  final String value;

  const TmuxWindowId(this.value);

  factory TmuxWindowId.parse(String value) {
    if (!_isValidTmuxId(value, '@')) {
      throw ArgumentError.value(
        value,
        'value',
        'tmux window IDs are @ followed by digits',
      );
    }
    return TmuxWindowId(value);
  }

  static TmuxWindowId? tryParse(String value) =>
      _isValidTmuxId(value, '@') ? TmuxWindowId(value) : null;

  @override
  bool operator ==(Object other) =>
      other is TmuxWindowId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// A tmux pane ID, prefixed with `%`.
final class TmuxPaneId {
  final String value;

  const TmuxPaneId(this.value);

  factory TmuxPaneId.parse(String value) {
    if (!_isValidTmuxId(value, '%')) {
      throw ArgumentError.value(
        value,
        'value',
        'tmux pane IDs are % followed by digits',
      );
    }
    return TmuxPaneId(value);
  }

  static TmuxPaneId? tryParse(String value) =>
      _isValidTmuxId(value, '%') ? TmuxPaneId(value) : null;

  @override
  bool operator ==(Object other) => other is TmuxPaneId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
