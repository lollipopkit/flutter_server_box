/// Represents a tmux window within a session.
final class TmuxWindowInfo {
  final int index;
  final String name;
  final bool active;
  final int panes;
  final String? activity;

  const TmuxWindowInfo({
    required this.index,
    required this.name,
    required this.active,
    required this.panes,
    this.activity,
  });

  /// Parse a line from `tmux list-windows -t <session> -F "#{window_index}|#{window_name}|#{window_active}|#{window_panes}|#{window_activity_string}"`
  static TmuxWindowInfo? tryParse(String line) {
    final parts = line.split('|');
    if (parts.isEmpty) return null;
    final index = int.tryParse(parts[0]);
    if (index == null) return null;
    return TmuxWindowInfo(
      index: index,
      name: parts.length > 1 ? parts[1] : '',
      active: parts.length > 2 && parts[2] == '1',
      panes: parts.length > 3 ? (int.tryParse(parts[3]) ?? 1) : 1,
      activity: parts.length > 4 ? parts[4] : null,
    );
  }

  String get displayName {
    final parts = <String>['$index: $name'];
    if (active) parts.add('(active)');
    if (panes > 1) parts.add('$panes panes');
    return parts.join(' · ');
  }

  @override
  String toString() => 'TmuxWindow($index: $name, active=$active, panes=$panes)';
}
