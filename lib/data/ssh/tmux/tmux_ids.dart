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

  const TmuxSessionId._(this.value);

  /// Same as [TmuxSessionId.parse]: an id is interpolated into tmux commands, so
  /// there is no way to make one that has not been checked.
  factory TmuxSessionId(String value) = TmuxSessionId.parse;

  factory TmuxSessionId.parse(String value) {
    if (!_isValidTmuxId(value, r'$')) {
      throw ArgumentError.value(
        value,
        'value',
        'tmux session IDs are \$ followed by digits',
      );
    }
    return TmuxSessionId._(value);
  }

  static TmuxSessionId? tryParse(String value) =>
      _isValidTmuxId(value, r'$') ? TmuxSessionId._(value) : null;

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

  const TmuxWindowId._(this.value);

  /// Same as [TmuxWindowId.parse]: an id is interpolated into tmux commands, so
  /// there is no way to make one that has not been checked.
  factory TmuxWindowId(String value) = TmuxWindowId.parse;

  factory TmuxWindowId.parse(String value) {
    if (!_isValidTmuxId(value, '@')) {
      throw ArgumentError.value(
        value,
        'value',
        'tmux window IDs are @ followed by digits',
      );
    }
    return TmuxWindowId._(value);
  }

  static TmuxWindowId? tryParse(String value) =>
      _isValidTmuxId(value, '@') ? TmuxWindowId._(value) : null;

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

  const TmuxPaneId._(this.value);

  /// Same as [TmuxPaneId.parse]: an id is interpolated into tmux commands, so
  /// there is no way to make one that has not been checked.
  factory TmuxPaneId(String value) = TmuxPaneId.parse;

  factory TmuxPaneId.parse(String value) {
    if (!_isValidTmuxId(value, '%')) {
      throw ArgumentError.value(
        value,
        'value',
        'tmux pane IDs are % followed by digits',
      );
    }
    return TmuxPaneId._(value);
  }

  static TmuxPaneId? tryParse(String value) =>
      _isValidTmuxId(value, '%') ? TmuxPaneId._(value) : null;

  @override
  bool operator ==(Object other) => other is TmuxPaneId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
