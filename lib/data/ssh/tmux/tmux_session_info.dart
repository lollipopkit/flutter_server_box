import 'package:server_box/data/ssh/tmux/tmux_format.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';

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

  /// Parses tab-separated output from `list-sessions`.
  ///
  /// The stable session id is first and the name uses tmux's `q:` escaping, so
  /// `|` and `:` are valid parts of a name rather than protocol delimiters.
  static TmuxSessionInfo? tryParse(String line) {
    final fields = splitTmuxFields(line);
    if (fields.length < 4) return null;

    final id = TmuxSessionId.tryParse(unescapeTmuxField(fields[0]));
    final name = unescapeTmuxField(fields[1]);
    final windows = int.tryParse(unescapeTmuxField(fields[2]));
    final attached = int.tryParse(unescapeTmuxField(fields[3]));
    if (id == null || name.isEmpty || windows == null || attached == null) {
      return null;
    }

    return TmuxSessionInfo(
      id: id,
      name: name,
      windows: windows,
      attached: attached > 0,
      createdAt: fields.length > 4 ? unescapeTmuxField(fields[4]) : null,
      lastAttached: fields.length > 5 ? unescapeTmuxField(fields[5]) : null,
      activity: fields.length > 6 ? unescapeTmuxField(fields[6]) : null,
    );
  }

  @override
  String toString() => '$id:$name ($windows windows)';
}
