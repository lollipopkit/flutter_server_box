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
import 'package:server_box/view/page/server/card/title.dart';
import 'package:server_box/view/page/server/metric_row.dart';
import 'package:server_box/view/page/server/tab/element_flight.dart';
import 'package:server_box/view/page/server/uptimer/common.dart';
import 'package:server_box/view/page/server/widget/server_side_tile.dart';

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

  static const _compactRadius = BorderRadius.all(Radius.circular(9));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(
      uptimerProvider.select((s) => s.busyIds.contains(monitor.id) || s.isLoading),
    );
    final incidents = ref.watch(
      uptimerProvider.select((s) => s.incidentsFor(monitor.id)),
    );
    final maintenance = ref.watch(
      uptimerProvider.select((s) => s.activeMaintenanceFor(monitor.id)),
    );
    final color = highlighted
        ? Theme.of(context).colorScheme.secondaryContainer
        : null;

    final (radius, margin, body) = switch (density) {
      ServerListDensity.rows => (
        _compactRadius,
        const EdgeInsets.symmetric(vertical: 1),
        _buildRow(context, ref, busy: busy),
      ),
      ServerListDensity.grid => (
        _compactRadius,
        EdgeInsets.zero,
        _buildGridTile(context),
      ),
      ServerListDensity.cards || ServerListDensity.auto => (
        null,
        const EdgeInsets.all(4),
        _buildCard(
          context,
          ref,
          busy: busy,
          incidents: incidents,
          maintenance: maintenance,
        ),
      ),
    };

    return FadingCard(
      outline: 1,
      color: color,
      radius: radius,
      margin: margin,
      child: InkWell(onTap: onTap, onLongPress: onLongPress, child: body),
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
    final bg = highlighted ? scheme.secondaryContainer : cardColorOf(context);
    return SizedBox(
      width: kSideMarkSize,
      height: kSideMarkSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Icon(
              uptimerTypeIcon(monitor.type),
              size: kSideMarkSize,
              color: scheme.onSurfaceVariant,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: DecoratedBox(
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: Container(
                  width: SideMarkDot.size,
                  height: SideMarkDot.size,
                  decoration: BoxDecoration(
                    color: _dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context, WidgetRef ref, {required bool busy}) {
    final Widget child = busy
        ? const SizedBox.square(dimension: 19, child: SizedLoading(19, padding: 2))
        : const Icon(Icons.refresh, size: 19, color: Colors.grey);
    final slot = SizedBox(
      height: 23,
      width: ServerCardSizes.action,
      child: Center(child: child),
    );
    if (busy || selected != null) return slot;
    return Semantics(
      container: true,
      button: true,
      label: libL10n.refresh,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () => unawaited(
          ref.read(uptimerProvider.notifier).refresh(force: true),
        ),
        child: slot,
      ),
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
    return Opacity(
      opacity: hideStrip ? 0 : 1,
      child: FlightAnchor(
        binding: stripAnchor,
        child: UptimerStripHero(
          monitorId: monitor.id,
          enabled: !opensInPlace,
          child: strip,
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
    final rightText = _headerRightText();
    final metaLeft = _metaLeftText();
    final metaRight = _metaRightText();
    final alertBanner = _buildAlertBanner(context, incidents, maintenance);

    return Padding(
      padding: const EdgeInsets.all(ServerCardSizes.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (_, cons) => Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected case final sel?)
                        ServerCardCheck(selected: sel),
                      _buildMark(context),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          monitor.name,
                          style: const TextStyle(
                            fontSize: ServerCardSizes.name,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 17,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: cons.maxWidth.isFinite
                        ? cons.maxWidth * 0.42
                        : double.infinity,
                  ),
                  child: Text(
                    rightText,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: monitor.status == UptimerMonitorStatus.down
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: _headerRightColor(scheme),
                      fontFeatures: kTabularFigures,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 7),
                _buildAction(context, ref, busy: busy),
              ],
            ),
          ),
          const SizedBox(height: ServerCardSizes.gap),
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
    BuildContext context,
    List<UptimerIncident> incidents,
    List<UptimerMaintenanceWindow> maintenance,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color tone, String title)? alert = incidents.isNotEmpty
        ? (Icons.error_outline, StatePalette.failed, incidents.first.title)
        : maintenance.isNotEmpty
        ? (Icons.build_outlined, StatePalette.warn, maintenance.first.title)
        : null;
    if (alert == null) return null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: _compactRadius,
      ),
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
    final statusWord = uptimerStatusText(monitor.status);
    final statusColor = _headerRightColor(scheme);
    final uptimeStr = monitor.uptime30d.uptimePct != null
        ? formatUptimePct(monitor.uptime30d.uptimePct)
        : '—';
    final detailStr = monitor.lastLatencyMs != null
        ? formatLatencyMs(monitor.lastLatencyMs)
        : monitor.type.shortLabel;

    return SizedBox(
      height: isMobile ? ServerCardSizes.rowTouch : ServerCardSizes.row,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: LayoutBuilder(
          builder: (_, cons) {
            final wide = cons.maxWidth;
            return Row(
              children: [
                if (selected case final sel?) ServerCardCheck(selected: sel),
                Container(
                  width: ServerCardSizes.dot,
                  height: ServerCardSizes.dot,
                  decoration: BoxDecoration(
                    color: _dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 11),
                SizedBox(
                  width: 96,
                  child: Text(
                    monitor.name,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Row(
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
                ),
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
                if (wide >= 560) ...[
                  const SizedBox(width: 13),
                  SizedBox(
                    width: 88,
                    child: Text(
                      statusWord,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1,
                        color: statusColor,
                        fontFeatures: kTabularFigures,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(width: 3),
                _buildAction(context, ref, busy: busy),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGridTile(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shortVal = monitor.status == UptimerMonitorStatus.up
        ? (monitor.lastLatencyMs != null
              ? formatLatencyMs(monitor.lastLatencyMs)
              : formatUptimePct(monitor.uptime30d.uptimePct))
        : uptimerStatusText(monitor.status);
    final valColor = switch (monitor.status) {
      UptimerMonitorStatus.down => StatePalette.failed,
      UptimerMonitorStatus.maintenance => StatePalette.warn,
      UptimerMonitorStatus.paused || UptimerMonitorStatus.unknown => Colors.grey,
      UptimerMonitorStatus.up => scheme.onSurfaceVariant,
    };

    return SizedBox(
      height: isMobile ? ServerCardSizes.tileTouch : ServerCardSizes.tile,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (selected case final sel?) ServerCardCheck(selected: sel),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    monitor.name,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 64),
                  child: Text(
                    shortVal,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      color: valColor,
                      fontFeatures: kTabularFigures,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            _buildStrip(ServerListDensity.grid),
          ],
        ),
      ),
    );
  }
}
