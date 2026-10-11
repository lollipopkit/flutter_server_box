import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/server/card/compact.dart';
import 'package:server_box/view/page/server/card/metric.dart';

/// A server's line from the list — up or not, its name, the reading it is
/// watched by — above a narrow terminal, which has no column beside it for
/// the status panel to stay open in.
///
/// Tapping it opens that panel: the line is the summary, and the panel what
/// it summarises.
class CompanionStatusLine extends ConsumerWidget {
  const CompanionStatusLine({super.key, required this.spi, required this.onTap});

  final Spi spi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final srv = ref.watch(serverProvider(spi.id));
    // The same readings, and the same one watched, as the server's line in
    // the list — see `ServerCard._compact`.
    final readings = serverCardHasBody(srv) ? serverCardReadings(srv) : null;
    final promoted = ServerPromoted.of(spi.id);
    final focus = readings == null
        ? null
        : readings.all.firstWhereOrNull((m) => m.kind == promoted) ??
              readings.all.firstOrNull;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: ServerCardLine(
          srv: srv,
          readings: readings,
          focus: focus,
          stale: readings == null ? null : serverStaleSince(srv),
        ),
      ),
    );
  }
}
