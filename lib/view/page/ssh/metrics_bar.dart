import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/reading_text.dart';

/// The server's CPU, memory, network and disk under its terminal (#1653).
///
/// The numbers the server card shows, written the same way, at the foot of
/// the terminal: above the virtual keys on a phone, at the bottom of the
/// window on a desktop. Shown while `termMetricsBar` is on, and nothing for a
/// server that is gone — a tab restored after its server was deleted has no
/// provider to ask (see `PresentServerX`).
final class TerminalMetricsBar extends StatelessWidget {
  final String serverId;

  /// Space to keep under the bar when nothing else does: the keys' own
  /// `SafeArea` does while they are shown, and a desktop needs none.
  final double bottomInset;

  const TerminalMetricsBar({
    super.key,
    required this.serverId,
    this.bottomInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Stores.setting.termMetricsBar.listenable(),
      builder: (context, on, _) {
        if (!on) return const SizedBox.shrink();
        return Consumer(
          builder: (context, ref, _) {
            final present = ref.watch(
              serversProvider.select((s) => s.servers.containsKey(serverId)),
            );
            if (!present) return const SizedBox.shrink();
            final srv = ref.watch(serverProvider(serverId));
            return TerminalMetricsBarView(srv: srv, bottomInset: bottomInset);
          },
        );
      },
    );
  }
}

/// What [TerminalMetricsBar] draws once it has a server to draw.
///
/// Four slots in a fixed order, a dash in one the machine has not reported:
/// a bar that gained and lost slots as polls came in would move the other
/// three under the eye.
final class TerminalMetricsBarView extends StatelessWidget {
  final ServerState srv;
  final double bottomInset;

  const TerminalMetricsBarView({
    super.key,
    required this.srv,
    this.bottomInset = 0,
  });

  static const _slots = [
    (ServerMetricKind.cpu, ServerDetailCards.cpu),
    (ServerMetricKind.mem, ServerDetailCards.mem),
    (ServerMetricKind.netSpeed, ServerDetailCards.net),
    (ServerMetricKind.disk, ServerDetailCards.disk),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = serverCardReadings(srv).all;
    final style = TextStyle(
      fontSize: 11.5,
      color: scheme.onSurfaceVariant,
      fontFeatures: kTabularFigures,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 4, 10, 4 + bottomInset),
      // Scaled down rather than wrapped or clipped when a phone is too narrow
      // for all four: a bar that is one line is the point of it.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, (kind, card)) in _slots.indexed) ...[
              if (i > 0) const SizedBox(width: 16),
              _Reading(
                icon: card.icon,
                metric: all.firstWhereOrNull((m) => m.kind == kind),
                style: style,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _Reading extends StatelessWidget {
  final IconData icon;
  final ServerMetric? metric;
  final TextStyle style;

  const _Reading({
    required this.icon,
    required this.metric,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final m = metric;
    // The network's figure is both directions; the card's `value` is the one
    // it charts, and its `note` is the pair.
    final text = switch (m) {
      null => '--',
      ServerMetric(kind: ServerMetricKind.netSpeed, :final note) => note,
      ServerMetric(:final value) => value,
    };
    final over = m?.over ?? false;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: over ? StatePalette.warn : style.color),
        const SizedBox(width: 4),
        Text(
          text,
          style: over ? style.copyWith(color: StatePalette.warn) : style,
        ),
      ],
    );
  }
}
