import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:server_box/src/rust/api/tmux.dart' as ffi;

/// Represents a tmux session discovered on the remote server.
final class TmuxSessionInfo {
  final TmuxSessionId id;
  final String name;
  final int windows;
  final bool attached;
  final String? createdAt;
  final String? lastAttached;
  final String? activity;

  const TmuxSessionInfo({
    required this.id,
    required this.name,
    required this.windows,
    required this.attached,
    this.createdAt,
    this.lastAttached,
    this.activity,
  });

  /// One session `sbm_parser::tmux` read off `list-sessions`.
  factory TmuxSessionInfo.fromFfi(ffi.TmuxSessionItem item) => TmuxSessionInfo(
    // Checked on the Rust side, which reads nothing else as an id.
    id: TmuxSessionId(item.id),
    name: item.name,
    windows: item.windows,
    attached: item.attached,
    createdAt: item.created,
    lastAttached: item.lastAttached,
    activity: item.activity,
  );

  @override
  String toString() => '$id:$name ($windows windows)';
}
