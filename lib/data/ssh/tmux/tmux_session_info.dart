/// Represents a tmux session discovered on the remote server.
final class TmuxSessionInfo {
  final String name;
  final int windows;
  final bool attached;
  final String? createdAt;
  final String? lastAttached;
  final String? activity;

  const TmuxSessionInfo({
    required this.name,
    required this.windows,
    required this.attached,
    this.createdAt,
    this.lastAttached,
    this.activity,
  });
  /// Parse a line from `tmux list-sessions -F "#{session_name}|#{session_windows}|#{session_attached}|#{session_created_string}|#{session_last_attached_string}|#{session_activity_string}"`
  static TmuxSessionInfo? tryParse(String line) {
    final parts = line.split('|');
    if (parts.isEmpty || parts[0].isEmpty) return null;
    return TmuxSessionInfo(
      name: parts[0],
      windows: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
      attached: parts.length > 2 && (int.tryParse(parts[2]) ?? 0) > 0,
      createdAt: parts.length > 3 ? parts[3] : null,
      lastAttached: parts.length > 4 ? parts[4] : null,
      activity: parts.length > 5 ? parts[5] : null,
    );
  }

  @override
  String toString() => 'TmuxSession($name, $windows windows, attached=$attached)';
}
