import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/provider/uptimer/client.dart';
import 'package:server_box/data/provider/uptimer/detail.dart';
import 'package:server_box/data/provider/uptimer/uptimer.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/detail/focus_parts.dart';
import 'package:server_box/view/page/server/tab/element_flight.dart';
import 'package:server_box/view/page/uptimer/common.dart';
import 'package:server_box/view/page/uptimer/edit.dart';

/// Full detail view for an Uptimer monitor.
///
/// Supports both pushed single-pane navigation (`bare: false`) and embedded
/// two-pane hosting in the Status tab (`bare: true`).
final class UptimerDetailPage extends ConsumerStatefulWidget {
  final UptimerDetailArgs args;
  final bool bare;
  final FlightAnchorBinding? stripAnchor;
  final bool hideStrip;

  const UptimerDetailPage({
    super.key,
    required this.args,
    this.bare = false,
    this.stripAnchor,
    this.hideStrip = false,
  });

  static const route = AppRouteArg<void, UptimerDetailArgs>(
    page: UptimerDetailPage.new,
    path: '/uptimer/detail',
  );

  @override
  ConsumerState<UptimerDetailPage> createState() => _UptimerDetailPageState();
}

final class _UptimerDetailPageState extends ConsumerState<UptimerDetailPage> {
  static const _circularLoading = SizedLoading(
    16,
    padding: 1,
    builder: SizedLoading.circularBuilder,
  );

  var _everPresent = false;
  var _popScheduled = false;
  int? _inspectedCheckedAt;

  int get _monitorId => widget.args.monitor.id;

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(
      uptimerProvider.select((s) => s.monitors[_monitorId]),
    );
    if (stored != null) {
      _everPresent = true;
    } else if (_everPresent) {
      if (!widget.bare && !_popScheduled) {
        _popScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final route = ModalRoute.of(context);
          if (route == null || !route.isActive) return;
          if (route.isCurrent) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).removeRoute(route);
          }
        });
      }
      return widget.bare ? UIs.placeholder : const Scaffold();
    }

    final monitor = stored ?? widget.args.monitor;
    final config = ref.watch(
      uptimerProvider.select((s) => s.configs[_monitorId]),
    );
    final busy = ref.watch(
      uptimerProvider.select((s) => s.busyIds.contains(_monitorId)),
    );
    final incidents = ref.watch(
      uptimerProvider.select((s) => s.incidentsFor(_monitorId)),
    );
    final activeMaint = ref.watch(
      uptimerProvider.select((s) => s.activeMaintenanceFor(_monitorId)),
    );
    final upcomingMaint = ref.watch(
      uptimerProvider.select((s) => s.upcomingMaintenanceFor(_monitorId)),
    );
    final detail = ref.watch(uptimerDetailProvider(_monitorId));

    final body = _buildBody(
      context,
      monitor: monitor,
      config: config,
      detail: detail,
      busy: busy,
      incidents: incidents,
      activeMaint: activeMaint,
      upcomingMaint: upcomingMaint,
    );

    if (widget.bare) return body;

    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: monitor.name, down: monitor.displayAddr),
        actions: [
          Btn.icon(
            text: libL10n.refresh,
            icon: const Icon(Icons.refresh),
            onTap: detail.isLoading
                ? null
                : () => unawaited(
                    ref.read(uptimerDetailProvider(_monitorId).notifier).refresh(),
                  ),
          ),
          Btn.icon(
            text: libL10n.edit,
            icon: const Icon(Icons.edit_outlined),
            onTap: () => unawaited(_openEdit(monitor, config)),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required UptimerMonitorCard monitor,
    required UptimerMonitorConfig? config,
    required UptimerDetailState detail,
    required bool busy,
    required List<UptimerIncident> incidents,
    required List<UptimerMaintenanceWindow> activeMaint,
    required List<UptimerMaintenanceWindow> upcomingMaint,
  }) {
    final configCard = config == null ? null : _buildConfigCard(context, config);
    final statusCard = _buildStatusCard(
      context,
      monitor: monitor,
      config: config,
      detail: detail,
      busy: busy,
      incidents: incidents,
      activeMaint: activeMaint,
      upcomingMaint: upcomingMaint,
    );
    final uptimeCard = _buildUptimeCard(context, monitor, detail);
    final outagesCard = _buildOutagesCard(context, detail);
    final configSlot = ServerDetailSwap(
      child: configCard == null
          ? const SizedBox.shrink(key: ValueKey('no_config'))
          : Padding(
              key: const ValueKey('config'),
              padding: const EdgeInsets.only(top: 13),
              child: configCard,
            ),
    );

    return LayoutBuilder(
      builder: (context, cons) {
        // Mirror `ServerDetailPage`'s two-column layout (`ServerCardSizes`):
        // wide primary charts & history on the left, compact status + config
        // aside column on the right.
        final wide = cons.maxWidth >= ServerCardSizes.columnsWidth;
        final latencyCard = _buildLatencyCard(
          context,
          monitor,
          detail,
          chartHeight: wide ? 196 : 150,
        );

        final Widget content;
        if (wide) {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    uptimeCard,
                    if (latencyCard != null) ...[
                      UIs.height13,
                      latencyCard,
                    ],
                    UIs.height13,
                    outagesCard,
                  ],
                ),
              ),
              const SizedBox(width: ServerCardSizes.asideGap),
              SizedBox(
                width: ServerCardSizes.aside,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [statusCard, configSlot],
                ),
              ),
            ],
          );
        } else {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              statusCard,
              UIs.height13,
              uptimeCard,
              if (latencyCard != null) ...[
                UIs.height13,
                latencyCard,
              ],
              UIs.height13,
              outagesCard,
              configSlot,
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: () =>
              ref.read(uptimerDetailProvider(_monitorId).notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              ServerCardSizes.pageSide,
              13,
              ServerCardSizes.pageSide,
              28 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: wide
                        ? ServerCardSizes.contentMax
                        : ServerCardSizes.readingsMax,
                  ),
                  child: content,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required UptimerMonitorCard monitor,
    required UptimerMonitorConfig? config,
    required UptimerDetailState detail,
    required bool busy,
    required List<UptimerIncident> incidents,
    required List<UptimerMaintenanceWindow> activeMaint,
    required List<UptimerMaintenanceWindow> upcomingMaint,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final tone = uptimerStatusColor(monitor.status);
    final isPaused = monitor.status == UptimerMonitorStatus.paused;
    final subtitle = config != null && config.target.isNotEmpty
        ? config.target
        : monitor.displayAddr;

    return CardX(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    uptimerTypeIcon(monitor.type),
                    size: 20,
                    color: tone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uptimerStatusText(monitor.status),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: monitor.status == UptimerMonitorStatus.down
                              ? StatePalette.failed
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatUptimePct(monitor.uptime30d.uptimePct),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                    if (monitor.lastLatencyMs case final ms?)
                      Text(
                        formatLatencyMs(ms),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          fontFeatures: kTabularFigures,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: busy ? null : _onTest,
                  icon: busy
                      ? _circularLoading
                      : const Icon(Icons.play_arrow, size: 17),
                  label: Text(l10n.uptimerTest),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : () => _onTogglePause(isPaused),
                  icon: Icon(
                    isPaused ? Icons.play_circle_outline : Icons.pause_circle_outline,
                    size: 17,
                  ),
                  label: Text(isPaused ? l10n.uptimerResume : l10n.uptimerPause),
                ),
                if (monitor.type == UptimerMonitorType.heartbeat)
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : () => _onRotatePushToken(monitor),
                    icon: const Icon(Icons.key_outlined, size: 17),
                    label: Text(l10n.uptimerRotatePushUrl),
                  ),
              ],
            ),
            if (detail.lastTest case final test?) ...[
              const SizedBox(height: 11),
              _buildTestResultBanner(context, test),
            ],
            if (incidents.isNotEmpty ||
                activeMaint.isNotEmpty ||
                upcomingMaint.isNotEmpty) ...[
              const SizedBox(height: 11),
              for (final inc in incidents)
                _buildNoticeRow(
                  context,
                  icon: Icons.error_outline,
                  color: StatePalette.failed,
                  title: inc.title,
                  detail: inc.message ?? '${inc.status} · ${inc.impact}',
                ),
              for (final w in activeMaint)
                _buildNoticeRow(
                  context,
                  icon: Icons.build_outlined,
                  color: StatePalette.warn,
                  title: w.title,
                  detail:
                      '${formatTimestampUnix(w.startsAt)} – ${formatTimestampUnix(w.endsAt)}',
                ),
              for (final w in upcomingMaint)
                _buildNoticeRow(
                  context,
                  icon: Icons.schedule,
                  color: scheme.onSurfaceVariant,
                  title: '${l10n.uptimerUpcoming}: ${w.title}',
                  detail:
                      '${formatTimestampUnix(w.startsAt)} – ${formatTimestampUnix(w.endsAt)}',
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultBanner(BuildContext context, UptimerTestResult test) {
    final scheme = Theme.of(context).colorScheme;
    final tone = uptimerTestStatusColor(test);
    final parts = <String>[
      uptimerTestStatusText(test),
      if (test.latencyMs case final ms?) formatLatencyMs(ms),
      if (test.httpStatus case final code?) 'HTTP $code',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                test.isUp
                    ? Icons.check_circle_outline
                    : test.status == 'down'
                    ? Icons.cancel_outlined
                    : Icons.help_outline,
                size: 16,
                color: tone,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  parts.join(' · '),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: tone,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
            ],
          ),
          if (test.error case final err?) ...[
            const SizedBox(height: 3),
            Text(
              err,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.grey,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoticeRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String detail,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: kTabularFigures,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUptimeCard(
    BuildContext context,
    UptimerMonitorCard monitor,
    UptimerDetailState detail,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final totals = detail.currentUptime ??
        (detail.range == UptimerRange.d30 ? monitor.uptime30d : null);
    // Resolve the inspected heartbeat using the same newest-45 oldest-to-newest
    // slot mapping as [UptimerHeartbeatStrip] so 60s polls relocate the same
    // check cleanly.
    const stripCount = 45;
    final inspectedSlot = _inspectedCheckedAt == null
        ? null
        : UptimerHeartbeatStrip.slotOf(
            monitor.heartbeats,
            stripCount,
            _inspectedCheckedAt!,
          );
    final inspectedIndex = inspectedSlot?.index;
    final inspected = inspectedSlot?.beat;

    return CardX(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedTabs<UptimerRange>(
              expand: true,
              trackColor: scheme.surfaceContainerHigh,
              segments: [
                for (final r in UptimerRange.values)
                  SegmentedTab(value: r, label: r.wire),
              ],
              selected: detail.range,
              onSelected: (range) => unawaited(
                ref
                    .read(uptimerDetailProvider(_monitorId).notifier)
                    .setRange(range),
              ),
            ),
            const SizedBox(height: 13),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AnimatedSwitcher(
                  duration: context.motion(Durations.short4),
                  child: Text(
                    formatUptimePct(totals?.uptimePct),
                    key: ValueKey(
                      '${detail.range.wire}:${totals?.uptimePct}',
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: AnimatedSwitcher(
                      duration: context.motion(Durations.short4),
                      child: detail.isLoading
                          ? const KeyedSubtree(
                              key: ValueKey('uptime_loading'),
                              child: _circularLoading,
                            )
                          : totals != null && totals.downtimeSec > 0
                          ? Text(
                              '${l10n.uptimerDowntime} ${formatDurationSec(totals.downtimeSec)}',
                              key: ValueKey(
                                'downtime:${detail.range.wire}:${totals.downtimeSec}',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: StatePalette.failed,
                                fontFeatures: kTabularFigures,
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('uptime_idle'),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            if (detail.uptimeError case final err?) ...[
              const SizedBox(height: 8),
              _buildInlineError(
                context,
                err,
                onRetry: () => unawaited(
                  ref.read(uptimerDetailProvider(_monitorId).notifier).refresh(),
                ),
              ),
            ],
            if (monitor.heartbeats.isNotEmpty) ...[
              const SizedBox(height: 11),
              IgnorePointer(
                ignoring: widget.hideStrip,
                child: Opacity(
                  opacity: widget.hideStrip ? 0 : 1,
                  child: FlightAnchor(
                    binding: widget.stripAnchor,
                    child: UptimerStripHero(
                      monitorId: _monitorId,
                      enabled: !widget.bare,
                      child: UptimerHeartbeatStrip(
                        heartbeats: monitor.heartbeats,
                        count: stripCount,
                        height: 22,
                        gap: 2,
                        radius: 2.5,
                        selectedIndex: inspectedIndex,
                        onSelect: (_, beat) => setState(() {
                          if (beat == null ||
                              _inspectedCheckedAt == beat.checkedAt) {
                            _inspectedCheckedAt = null;
                          } else {
                            _inspectedCheckedAt = beat.checkedAt;
                          }
                        }),
                      ),
                    ),
                  ),
                ),
              ),
              ServerDetailSwap(
                duration: Durations.short4,
                child: inspected == null
                    ? const SizedBox.shrink(key: ValueKey('no_inspected'))
                    : Padding(
                        key: ValueKey('inspected:${inspected.checkedAt}'),
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: inspected.isUp
                                    ? StatePalette.running
                                    : inspected.isDown
                                    ? StatePalette.failed
                                    : StatePalette.idle,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatTimestampUnix(inspected.checkedAt),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant,
                                fontFeatures: kTabularFigures,
                              ),
                            ),
                            const Spacer(),
                            if (inspected.latencyMs case final ms?)
                              Text(
                                formatLatencyMs(ms),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: kTabularFigures,
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
            if (monitor.uptimeDays.isNotEmpty) ...[
              const SizedBox(height: 11),
              _buildDailyRollupBar(context, monitor.uptimeDays),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDailyRollupBar(BuildContext context, List<UptimerDay> days) {
    final scheme = Theme.of(context).colorScheme;
    final emptyColor = scheme.outlineVariant.withValues(alpha: 0.45);
    final recent = days.length > 60 ? days.sublist(days.length - 60) : days;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 10,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < recent.length; i++) ...[
                if (i > 0) const SizedBox(width: 1.5),
                Expanded(
                  child: Tooltip(
                    message:
                        '${formatShortDateUnix(recent[i].dayStartAt)} · '
                        '${formatUptimePct(recent[i].totals.uptimePct)}',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _dayColor(recent[i].totals, emptyColor),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              formatShortDateUnix(recent.first.dayStartAt),
              style: TextStyle(
                fontSize: 10.5,
                color: scheme.onSurfaceVariant,
                fontFeatures: kTabularFigures,
              ),
            ),
            const Spacer(),
            Text(
              formatShortDateUnix(recent.last.dayStartAt),
              style: TextStyle(
                fontSize: 10.5,
                color: scheme.onSurfaceVariant,
                fontFeatures: kTabularFigures,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Color _dayColor(UptimerTotals t, Color emptyColor) {
    final pct = t.uptimePct;
    if (pct == null) return emptyColor;
    if (t.downtimeSec == 0 || pct >= 99.95) return StatePalette.running;
    if (pct >= 98.0) return StatePalette.warn;
    return StatePalette.failed;
  }

  Widget? _buildLatencyCard(
    BuildContext context,
    UptimerMonitorCard monitor,
    UptimerDetailState detail, {
    double chartHeight = 150,
  }) {
    final latency = detail.latency;
    final points = latency?.points ?? const [];
    // Insert [FlSpot.nullSpot] for null latency measurements so fl_chart breaks
    // the line across outages while keeping a single series (preventing
    // duplicate tooltips/indicators near gaps).
    final spots = <FlSpot>[];
    final nullIndices = <int>[];
    final shortRunIndices = <int>{};
    var hasMeasured = false;
    var maxMeasuredY = 0.0;
    var runStart = -1;
    void finishRun(int endExclusive) {
      if (runStart < 0) return;
      if (endExclusive - runStart <= 2) {
        for (var j = runStart; j < endExclusive; j++) {
          shortRunIndices.add(j);
        }
      }
      runStart = -1;
    }

    for (var i = 0; i < points.length; i++) {
      final ms = points[i].latencyMs;
      if (ms != null) {
        final y = ms.toDouble();
        spots.add(FlSpot(i.toDouble(), y));
        hasMeasured = true;
        if (y > maxMeasuredY) maxMeasuredY = y;
        if (runStart < 0) runStart = i;
      } else {
        finishRun(i);
        nullIndices.add(i);
        spots.add(FlSpot.nullSpot);
      }
    }
    finishRun(points.length);
    // fl_chart's FlSpot.lerp returns the old measured spot for nullSpot targets
    // during implicit animation; key the inner LineChart by gap layout so any
    // gap change renders immediately on frame 1 without crossfading the outer
    // AnimatedSwitcher, while preserving animations when gaps are unchanged.
    final gapSig = nullIndices.isEmpty
        ? ''
        : '${points.length}:${nullIndices.join(',')}';

    if (monitor.type == UptimerMonitorType.heartbeat && !hasMeasured) {
      return null;
    }

    final scheme = Theme.of(context).colorScheme;
    final accent = ChartPalette.accent;
    final maxY = !hasMeasured ? 100.0 : math.max(10.0, maxMeasuredY * 1.15);

    return CardX(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    '${l10n.uptimerLatency} (24h)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: AnimatedSwitcher(
                      duration: context.motion(Durations.short4),
                      child: latency?.avgLatencyMs != null ||
                              latency?.p95LatencyMs != null
                          ? Text(
                              [
                                if (latency?.avgLatencyMs case final avg?)
                                  'avg ${formatLatencyMs(avg)}',
                                if (latency?.p95LatencyMs case final p95?)
                                  'p95 ${formatLatencyMs(p95)}',
                              ].join(' · '),
                              key: ValueKey(
                                'lat_stats:${latency?.avgLatencyMs}:${latency?.p95LatencyMs}',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant,
                                fontFeatures: kTabularFigures,
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('lat_stats_empty'),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            if (hasMeasured && detail.latencyError != null) ...[
              const SizedBox(height: 11),
              _buildInlineError(
                context,
                detail.latencyError!,
                onRetry: () => unawaited(
                  ref
                      .read(uptimerDetailProvider(_monitorId).notifier)
                      .refresh(),
                ),
              ),
            ],
            const SizedBox(height: 13),
            SizedBox(
              height: chartHeight,
              child: AnimatedSwitcher(
                duration: context.motion(Durations.medium1),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: !hasMeasured
                    ? Center(
                        key: ValueKey(
                          detail.isLoading
                              ? 'lat_loading'
                              : detail.latencyError != null
                              ? 'lat_error'
                              : 'lat_empty',
                        ),
                        child: detail.isLoading
                            ? const SizedLoading(
                                24,
                                padding: 2,
                                builder: SizedLoading.circularBuilder,
                              )
                            : detail.latencyError != null
                            ? _buildInlineError(
                                context,
                                detail.latencyError!,
                                onRetry: () => unawaited(
                                  ref
                                      .read(
                                        uptimerDetailProvider(
                                          _monitorId,
                                        ).notifier,
                                      )
                                      .refresh(),
                                ),
                              )
                            : Text(
                                libL10n.empty,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('lat_chart'),
                        child: LineChart(
                          key: ValueKey('lat_chart:$gapSig'),
                          duration: context.motion(Durations.medium1),
                          curve: Curves.easeOutCubic,
                          LineChartData(
                        minY: 0,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY / 3,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: scheme.outlineVariant.withValues(alpha: 0.35),
                            strokeWidth: 0.7,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              interval: maxY / 3,
                              getTitlesWidget: (value, meta) {
                                if (value == meta.max) return const SizedBox();
                                return Text(
                                  formatLatencyMs(value.round()),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: scheme.onSurfaceVariant,
                                    fontFeatures: kTabularFigures,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => scheme.surfaceContainerHigh,
                            getTooltipItems: (items) => [
                              for (final item in items)
                                () {
                                  final idx = item.x.round();
                                  final ts =
                                      idx >= 0 && idx < points.length
                                          ? '\n${formatTimestampUnix(points[idx].checkedAt)}'
                                          : '';
                                  return LineTooltipItem(
                                    '${formatLatencyMs(item.y.round())}$ts',
                                    TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurface,
                                      fontFeatures: kTabularFigures,
                                    ),
                                  );
                                }(),
                            ],
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            curveSmoothness: 0.2,
                            color: accent,
                            barWidth: 2,
                            dotData: FlDotData(
                              show: shortRunIndices.isNotEmpty,
                              checkToShowDot: (spot, _) =>
                                  shortRunIndices.contains(spot.x.round()),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  accent.withValues(alpha: 0.24),
                                  accent.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutagesCard(BuildContext context, UptimerDetailState detail) {
    final scheme = Theme.of(context).colorScheme;
    final outages = detail.outages;

    final Widget body = switch ((
      outages.isEmpty,
      detail.outagesError,
      detail.isLoading,
    )) {
      (true, final err?, _) => Padding(
        key: const ValueKey('outages_error'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _buildInlineError(
          context,
          err,
          onRetry: () => unawaited(
            ref.read(uptimerDetailProvider(_monitorId).notifier).refresh(),
          ),
        ),
      ),
      (true, null, true) => Padding(
        key: const ValueKey('outages_loading'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          libL10n.loadingEllipsis,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
      ),
      (true, null, false) => Padding(
        key: ValueKey('outages_empty:${detail.range.wire}'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          l10n.uptimerNoOutages,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
      ),
      _ => Column(
        key: ValueKey('outages_list:${detail.range.wire}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (detail.outagesError case final err?) ...[
            _buildInlineError(
              context,
              err,
              onRetry: () => unawaited(
                ref.read(uptimerDetailProvider(_monitorId).notifier).refresh(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (var i = 0; i < outages.length; i++) ...[
            if (i > 0)
              Divider(
                height: 14,
                thickness: 0.6,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            _buildOutageRow(context, outages[i]),
          ],
          if (detail.nextOutageCursor != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: detail.loadingMoreOutages || detail.isLoading
                    ? null
                    : () => unawaited(_onLoadMoreOutages()),
                child: detail.loadingMoreOutages
                    ? _circularLoading
                    : Text(l10n.uptimerLoadMore),
              ),
            ),
          ],
        ],
      ),
    };

    return CardX(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${l10n.uptimerOutages} (${detail.range.wire})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: context.motion(Durations.short4),
                  child: detail.isLoading
                      ? const KeyedSubtree(
                          key: ValueKey('outages_hdr_loading'),
                          child: _circularLoading,
                        )
                      : outages.isNotEmpty
                      ? Text(
                          '${outages.length}${detail.nextOutageCursor != null ? '+' : ''}',
                          key: ValueKey(
                            'outages_cnt:${detail.range.wire}:${outages.length}:${detail.nextOutageCursor != null}',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            fontFeatures: kTabularFigures,
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('outages_hdr_idle'),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ServerDetailSwap(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildOutageRow(BuildContext context, UptimerOutage outage) {
    final scheme = Theme.of(context).colorScheme;
    final dur = outage.endedAt == null
        ? l10n.uptimerOngoing
        : formatDurationSec(outage.endedAt! - outage.startedAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: StatePalette.failed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                formatTimestampUnix(outage.startedAt),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ),
            Text(
              dur,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: outage.ongoing
                    ? StatePalette.failed
                    : scheme.onSurfaceVariant,
                fontFeatures: kTabularFigures,
              ),
            ),
          ],
        ),
        if (outage.errorSummary case final err?) ...[
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Text(
              err,
              style: TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConfigCard(BuildContext context, UptimerMonitorConfig cfg) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <(String, String)>[
      (l10n.uptimerType, cfg.type.shortLabel),
      if (cfg.target.isNotEmpty) (l10n.uptimerTarget, cfg.target),
      if (cfg.displayUrl case final u?) (l10n.uptimerDisplayUrl, u),
      (l10n.uptimerInterval, formatDurationSec(cfg.intervalSec)),
      if (cfg.type == UptimerMonitorType.heartbeat)
        (l10n.uptimerGracePeriod, formatDurationSec(cfg.graceSec ?? 60))
      else
        (l10n.uptimerTimeout, formatLatencyMs(cfg.timeoutMs)),
      if (cfg.groupName case final g?) (l10n.uptimerGroup, g),
      (
        l10n.uptimerPublic,
        cfg.showOnStatusPage ? libL10n.ok : '—',
      ),
      if (cfg.type == UptimerMonitorType.http) ...[
        if (cfg.httpMethod case final m?) (l10n.uptimerMethod, m),
        if (cfg.expectedStatus case final s?)
          (l10n.uptimerExpectedStatus, UptimerStatusRule.formatList(s)),
        if (cfg.forbiddenStatus case final s?)
          (l10n.uptimerForbiddenStatus, UptimerStatusRule.formatList(s)),
        if (cfg.responseKeyword case final k?)
          (l10n.uptimerKeyword, k),
        if (cfg.responseForbiddenKeyword case final k?)
          (l10n.uptimerForbiddenKeyword, k),
      ],
    ];

    return CardX(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 14,
                  thickness: 0.5,
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      rows[i].$1,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontFeatures: kTabularFigures,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInlineError(
    BuildContext context,
    Object error, {
    required VoidCallback onRetry,
  }) {
    return Row(
      children: [
        Icon(Icons.error_outline, size: 16, color: StatePalette.failed),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            uptimerErrorMessage(error),
            style: TextStyle(fontSize: 12, color: StatePalette.failed),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(onPressed: onRetry, child: Text(libL10n.retry)),
      ],
    );
  }

  Future<void> _onLoadMoreOutages() async {
    try {
      await ref
          .read(uptimerDetailProvider(_monitorId).notifier)
          .loadMoreOutages();
    } catch (e) {
      if (mounted) Toast.show(uptimerErrorMessage(e));
    }
  }

  Future<void> _onTest() async {
    try {
      await ref.read(uptimerDetailProvider(_monitorId).notifier).runTest();
    } catch (e) {
      if (mounted) Toast.show(uptimerErrorMessage(e));
    }
  }

  Future<void> _onTogglePause(bool isPaused) async {
    try {
      final notifier = ref.read(uptimerProvider.notifier);
      if (isPaused) {
        await notifier.resumeMonitor(_monitorId);
      } else {
        await notifier.pauseMonitor(_monitorId);
      }
    } catch (e) {
      if (mounted) Toast.show(uptimerErrorMessage(e));
    }
  }

  Future<void> _onRotatePushToken(UptimerMonitorCard monitor) async {
    final confirmed = await context.showSheet<bool>(
      title: l10n.uptimerRotatePushUrl,
      child: Text(l10n.uptimerRotatePushUrlConfirm(monitor.name)),
      actions: Btnx.cancelRedOk,
    );
    if (confirmed != true || !mounted) return;
    try {
      final mutation = await ref
          .read(uptimerProvider.notifier)
          .rotatePushToken(_monitorId);
      if (!mounted) return;
      if (mutation.pushToken case final token?) {
        final api = ref.read(uptimerApiProvider);
        await showUptimerPushUrlSheet(
          context,
          name: monitor.name,
          url: api.pushUrl(token),
        );
      }
    } catch (e) {
      if (mounted) Toast.show(uptimerErrorMessage(e));
    }
  }

  Future<void> _openEdit(
    UptimerMonitorCard monitor,
    UptimerMonitorConfig? config,
  ) async {
    final result = await UptimerEditPage.route.go(
      context,
      args: UptimerEditArgs(config: config, card: monitor),
    );
    if (result == UptimerEditResult.saved &&
        mounted &&
        ref.read(uptimerProvider).monitors.containsKey(_monitorId)) {
      unawaited(ref.read(uptimerDetailProvider(_monitorId).notifier).refresh());
    }
  }
}
