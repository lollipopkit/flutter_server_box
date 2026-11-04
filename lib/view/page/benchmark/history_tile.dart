import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/view/page/benchmark/status_mark.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, label) = run.status.mark(scheme);
    // A selected row is the secondary container, as every list column beside
    // a detail pane marks one: a tone of the card rather than an alpha of the
    // accent laid over it.
    return CardX(
      color: selected ? scheme.secondaryContainer : null,
      child: ListTile(
        selected: selected,
        selectedColor: scheme.onSecondaryContainer,
        leading: Icon(icon, color: color, semanticLabel: label),
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
        // A toolbar-sized glyph: the row's own action, not its subject.
        trailing: Btn.icon(
          icon: const Icon(Icons.delete_outline, size: 18),
          text: libL10n.delete,
          onTap: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}
