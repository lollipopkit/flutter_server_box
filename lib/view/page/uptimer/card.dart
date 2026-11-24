import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/provider/uptimer/uptimer.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/card/status_shell.dart';
import 'package:server_box/view/page/server/metric_row.dart';
import 'package:server_box/view/page/server/tab/element_flight.dart';
import 'package:server_box/view/page/uptimer/common.dart';

/// Status-tab card for an Uptimer monitor, matching [ServerCard] and [BmcCard]
/// across all three density modes (`cards`, `rows`, `grid`).
final class UptimerCard extends ConsumerWidget {
  final UptimerMonitorCard monitor;
  final ServerListDensity density;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool? selected;
  final bool highlighted;
  final FlightAnchorBinding? stripAnchor;
  final bool hideStrip;
  final bool opensInPlace;

  const UptimerCard({
    super.key,
    required this.monitor,
    required this.density,
    required this.onTap,
    this.onLongPress,
    this.selected,
    this.highlighted = false,
    this.stripAnchor,
    this.hideStrip = false,
    this.opensInPlace = false,
  });

  /// Heartbeat strip dimensions for each [ServerListDensity], shared between
  /// [UptimerCard] and the in-place overlay flight proxy so departing strips
  /// never overflow narrow row/grid slots.
  static ({int count, double height, double gap, double radius}) stripSpecFor(
    ServerListDensity density,
  ) => switch (density) {
    ServerListDensity.rows => (count: 24, height: 8, gap: 2, radius: 1.5),
    ServerListDensity.grid => (
      count: 16,
      height: ServerCardSizes.bar,
      gap: 1.5,
      radius: 1.5,
    ),
    ServerListDensity.cards || ServerListDensity.auto => (
      count: 30,
      height: 14,
      gap: 2,
      radius: 2,
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(
      uptimerProvider.select(
        (s) => s.busyIds.contains(monitor.id) || s.isLoading,
      ),
    );
    final incidents = ref.watch(
      uptimerProvider.select((s) => s.incidentsFor(monitor.id)),
    );
    final maintenance = ref.watch(
      uptimerProvider.select((s) => s.activeMaintenanceFor(monitor.id)),
    );

    final body = switch (density) {
      ServerListDensity.rows => _buildRow(context, ref, busy: busy),
      ServerListDensity.grid => _buildGridTile(context),
      ServerListDensity.cards || ServerListDensity.auto => _buildCard(
        context,
        ref,
        busy: busy,
        incidents: incidents,
        maintenance: maintenance,
      ),
    };
    return StatusDensityCard(
      density: density,
      highlighted: highlighted,
      onTap: onTap,
      onLongPress: onLongPress,
      child: body,
    );
  }

  Color get _dotColor => uptimerStatusColor(monitor.status);

  String _headerRightText() {
    if (monitor.status == UptimerMonitorStatus.up &&
        monitor.uptime30d.uptimePct != null) {
      return formatUptimePct(monitor.uptime30d.uptimePct);
    }
    return uptimerStatusText(monitor.status);
  }

  Color _headerRightColor(ColorScheme scheme) => switch (monitor.status) {
    UptimerMonitorStatus.down => StatePalette.failed,
    UptimerMonitorStatus.maintenance => StatePalette.warn,
    UptimerMonitorStatus.paused || UptimerMonitorStatus.unknown => Colors.grey,
    UptimerMonitorStatus.up => scheme.onSurfaceVariant,
  };

  Widget _buildMark(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StatusMarkBadge(
      icon: uptimerTypeIcon(monitor.type),
      dotColor: _dotColor,
      cutoutBg: highlighted ? scheme.secondaryContainer : cardColorOf(context),
    );
  }

  Widget _buildAction(BuildContext context, WidgetRef ref, {required bool busy}) {
    final Widget child = busy
        ? const SizedBox.square(dimension: 19, child: SizedLoading(19, padding: 2))
        : const Icon(Icons.refresh, size: 19, color: Colors.grey);
    return StatusCardActionSlot(
      onPressed: busy
          ? null
          : () => unawaited(
              ref.read(uptimerProvider.notifier).refresh(force: true),
            ),
      semanticLabel: libL10n.refresh,
      selected: selected,
      child: child,
    );
  }

  Widget _buildStrip(ServerListDensity density) {
    final spec = stripSpecFor(density);
    final strip = UptimerHeartbeatStrip(
      heartbeats: monitor.heartbeats,
      count: spec.count,
      height: spec.height,
      gap: spec.gap,
      radius: spec.radius,
    );
    return IgnorePointer(
      ignoring: hideStrip,
      child: Opacity(
        opacity: hideStrip ? 0 : 1,
        child: FlightAnchor(
          binding: stripAnchor,
          child: UptimerStripHero(
            monitorId: monitor.id,
            enabled: !opensInPlace,
            child: strip,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref, {
    required bool busy,
    required List<UptimerIncident> incidents,
    required List<UptimerMaintenanceWindow> maintenance,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final metaLeft = _metaLeftText();
    final metaRight = _metaRightText();
    final alertBanner = _buildAlertBanner(incidents, maintenance);

    return StatusCardShell(
      name: monitor.name,
      mark: _buildMark(context),
      selected: selected,
      rightText: _headerRightText(),
      rightMaxWidthFraction: 0.42,
      rightStyle: TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: monitor.status == UptimerMonitorStatus.down
            ? FontWeight.w600
            : FontWeight.w400,
        color: _headerRightColor(scheme),
        fontFeatures: kTabularFigures,
      ),
      action: _buildAction(context, ref, busy: busy),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStrip(ServerListDensity.cards),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  metaLeft,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: scheme.onSurfaceVariant,
                    fontFeatures: kTabularFigures,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (metaRight != null) ...[
                const SizedBox(width: 8),
                Text(
                  metaRight,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: monitor.status == UptimerMonitorStatus.down
                        ? StatePalette.failed
                        : scheme.onSurface,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ],
            ],
          ),
          if (alertBanner != null) ...[
            const SizedBox(height: 7),
            alertBanner,
          ],
        ],
      ),
    );
  }

  String _metaLeftText() {
    if (monitor.type == UptimerMonitorType.heartbeat) {
      final ping = formatRelativeUnix(monitor.lastPingAt);
      return '${monitor.type.shortLabel} · $ping';
    }
    final addr = monitor.displayAddr;
    if (addr == monitor.type.shortLabel) {
      return '${monitor.type.shortLabel} · ${formatRelativeUnix(monitor.lastCheckedAt)}';
    }
    return '${monitor.type.shortLabel} · $addr';
  }

  String? _metaRightText() {
    if (monitor.lastLatencyMs case final ms?) return formatLatencyMs(ms);
    if (monitor.uptime30d.uptimePct case final pct?
        when monitor.status != UptimerMonitorStatus.up) {
      return formatUptimePct(pct);
    }
    return null;
  }

  Widget? _buildAlertBanner(
    List<UptimerIncident> incidents,
    List<UptimerMaintenanceWindow> maintenance,
  ) {
    final (IconData icon, Color tone, String title)? alert = incidents.isNotEmpty
        ? (Icons.error_outline, StatePalette.failed, incidents.first.title)
        : maintenance.isNotEmpty
        ? (Icons.build_outlined, StatePalette.warn, maintenance.first.title)
        : null;
    if (alert == null) return null;

    return StatusNoticeBanner(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      child: Row(
        children: [
          Icon(alert.$1, size: 14, color: alert.$2),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              alert.$3,
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w500,
                color: alert.$2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    WidgetRef ref, {
    required bool busy,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final uptimeStr = monitor.uptime30d.uptimePct != null
        ? formatUptimePct(monitor.uptime30d.uptimePct)
        : '—';
    final detailStr = monitor.lastLatencyMs != null
        ? formatLatencyMs(monitor.lastLatencyMs)
        : monitor.type.shortLabel;

    return StatusRowShell(
      name: monitor.name,
      dotColor: _dotColor,
      selected: selected,
      rightWord: uptimerStatusText(monitor.status),
      rightColor: _headerRightColor(scheme),
      middleBuilder: (wide) => Row(
        children: [
          Expanded(child: _buildStrip(ServerListDensity.rows)),
          if (wide >= 440) ...[
            const SizedBox(width: 13),
            SizedBox(
              width: 56,
              child: Text(
                uptimeStr,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1,
                  fontFeatures: kTabularFigures,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      extraWideColumnsBuilder: (wide) => [
        if (wide >= 700) ...[
          const SizedBox(width: 13),
          SizedBox(
            width: 96,
            child: Text(
              detailStr,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 11,
                height: 1,
                color: Colors.grey,
                fontFeatures: kTabularFigures,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
      action: _buildAction(context, ref, busy: busy),
    );
  }

  Widget _buildGridTile(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shortVal = monitor.status == UptimerMonitorStatus.up
        ? (monitor.lastLatencyMs != null
              ? formatLatencyMs(monitor.lastLatencyMs)
              : formatUptimePct(monitor.uptime30d.uptimePct))
        : uptimerStatusText(monitor.status);

    return StatusGridTileShell(
      selected: selected,
      dotColor: _dotColor,
      title: StatusGridTileShell.defaultTitle(monitor.name),
      valueText: shortVal,
      valueColor: _headerRightColor(scheme),
      bottom: _buildStrip(ServerListDensity.grid),
    );
  }
}
