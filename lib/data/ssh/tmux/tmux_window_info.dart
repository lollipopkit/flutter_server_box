import 'package:server_box/src/rust/api/tmux.dart' as ffi;

/// Represents a tmux window within a session.
final class TmuxWindowInfo {
  final int index;
  final String name;
  final bool active;
  final int panes;
  /// Seconds since the epoch; null for a window that never saw output.
  final int? activity;

  const TmuxWindowInfo({
    required this.index,
    required this.name,
    required this.active,
    required this.panes,
    this.activity,
  });

  /// One window `sbm_parser::tmux` read off `list-windows`.
  factory TmuxWindowInfo.fromFfi(ffi.TmuxWindowItem item) => TmuxWindowInfo(
    index: item.index,
    name: item.name,
    active: item.active,
    panes: item.panes,
    activity: item.activity,
  );

  @override
  String toString() => 'TmuxWindow($index: $name, active=$active, panes=$panes)';
}
