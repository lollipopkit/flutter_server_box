import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/status/card_item.dart';
import 'package:server_box/data/provider/bmc/summary.dart';
import 'package:server_box/data/provider/server/metric.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/uptimer/uptimer.dart';
import 'package:server_box/data/res/chart_palette.dart';

/// One section's heading: what these items have in common, how many of them
/// there are, and how many have an active alert.
class ServerGroupHeading extends ConsumerWidget {
  const ServerGroupHeading({
    super.key,
    required this.label,
    required this.items,
    required this.first,
  });

  final String? label;
  final List<StatusCardItem> items;
  final bool first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var over = 0;
    for (final item in items) {
      final isOver = switch (item) {
        ServerCardItem(:final id) => ref.watch(
          serverProvider(id).select(
            (srv) =>
                srv.conn == ServerConn.finished &&
                serverCardReadings(srv).all.any((m) => m.over),
          ),
        ),
        BmcCardItem(:final target) => ref.watch(
          bmcSummaryProvider(target.id).select((s) {
            if (s.failure != null) return true;
            final health = s.topology?.system?.health;
            return health == 'Critical' || health == 'Warning';
          }),
        ),
        UptimerCardItem(:final monitor) => ref.watch(
          uptimerProvider.select((s) => s.hasAlert(monitor.id)),
        ),
      };
      if (isOver) over++;
    }

    return Padding(
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
          Text('${items.length}', style: UIs.text11Grey),
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
