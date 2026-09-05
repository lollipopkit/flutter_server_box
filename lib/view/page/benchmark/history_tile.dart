import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';

/// One past run, in the list of every past run.
class BenchmarkHistoryTile extends StatelessWidget {
  const BenchmarkHistoryTile({
    super.key,
    required this.run,
    required this.onTap,
    required this.onDelete,
    this.serverName,
    this.selected = false,
  });

  final BenchmarkRun run;

  /// Which machine this was, since the list spans all of them.
  ///
  /// Null when the server has since been deleted. The row stays — the result is
  /// still a measurement, and losing it because the machine was retired would
  /// throw away the half of the comparison that is history.
  final String? serverName;

  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Whether the column beside this one is showing it.
  ///
  /// Only ever true in the two-column layout: with one column the detail is a
  /// page on top of the list, so there is nothing left on screen to mark.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (run.status) {
      BenchmarkStatus.completed => (Icons.check_circle, Colors.green),
      BenchmarkStatus.failed => (Icons.error_outline, Colors.red),
      BenchmarkStatus.cancelled => (Icons.cancel_outlined, Colors.orange),
      BenchmarkStatus.running => (Icons.timelapse, Colors.blue),
    };
    return CardX(
      child: ListTile(
        selected: selected,
        selectedTileColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.1),
        leading: Icon(icon, color: color),
        title: Text(
          serverName ?? libL10n.unknown,
          style: UIs.text15,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // How long ago, and nothing else. The row is one of a list read at a
        // glance: the machine's name says which, the mark says how it ended,
        // and this says whether it is still current. The CPU model, the error
        // and the duration were three more things to read past, and all three
        // are on the result itself one tap away.
        subtitle: Text(
          run.startedAt.toAgoStr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: UIs.text12Grey,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Minutes and seconds, which is the range a benchmark lives in.
String fmtDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '${m}m ${s.toString().padLeft(2, '0')}s';
}
