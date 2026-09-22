import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/metric.dart';

/// One section's heading: what these machines have in common, how many of
/// them there are, and how many are over the line.
///
/// The count is what a heading is for at this size — a section of eight is
/// eight tiles nobody counts — and the alert count beside it is the one
/// thing that would otherwise need the section read to find. A section with
/// nothing wrong in it says nothing about alerts rather than saying zero.
///
/// The alert count is watched here, per machine, rather than read by the grid:
/// the grid is not rebuilt by a poll — each card watches its own server — so a
/// count taken there stayed at whatever it was when the list was last
/// arranged. Watched as whether each machine is over the line, so a poll that
/// changes nothing about that does not rebuild the heading either.
class ServerGroupHeading extends ConsumerWidget {
  const ServerGroupHeading({
    super.key,
    required this.label,
    required this.ids,
    required this.first,
  });

  /// What the section's machines have in common — the label `groupByTag`
  /// gave it. Null is drawn as the section of machines that carry no tag.
  final String? label;

  /// The machines the section holds. Their number is drawn, and how many of
  /// them are over the line beside it — nothing for that at 0.
  final List<String> ids;

  /// Whether this is the topmost section, which has no section above it to
  /// be kept apart from.
  final bool first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var over = 0;
    for (final id in ids) {
      final isOver = ref.watch(
        serverProvider(id).select(
          (srv) =>
              srv.conn == ServerConn.finished &&
              serverCardReadings(srv).all.any((m) => m.over),
        ),
      );
      if (isOver) over++;
    }

    return Padding(
      // Lined up with the cards under it, which carry their own margin.
      padding: EdgeInsets.fromLTRB(4, first ? 3 : 17, 4, 7),
      child: Row(
        children: [
          Text(
            label ?? l10n.ungrouped,
            style: const TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Divider(
              height: Hairline.thickness,
              thickness: Hairline.thickness,
              color: Hairline.color(context),
            ),
          ),
          const SizedBox(width: 9),
          Text('${ids.length}', style: UIs.text11Grey),
          if (over > 0) ...[
            const SizedBox(width: 7),
            const Icon(Icons.warning_amber, size: 13, color: StatePalette.warn),
            const SizedBox(width: 3),
            Text(
              '$over',
              style: const TextStyle(
                fontSize: 11,
                height: 1,
                color: StatePalette.warn,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
