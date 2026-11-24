import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/provider/uptimer/detail.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/uptimer/common.dart';
import 'package:server_box/view/page/uptimer/detail_sections.dart';

/// 24-hour latency line chart card with avg/p95 summary and gap breaking across
/// outages.
final class UptimerLatencyCard extends StatelessWidget {
  final UptimerMonitorCard monitor;
  final UptimerDetailState detail;
  final double chartHeight;
  final VoidCallback onRetry;

  const UptimerLatencyCard({
    super.key,
    required this.monitor,
    required this.detail,
    this.chartHeight = 150,
    required this.onRetry,
  });

  static bool shouldShow(
    UptimerMonitorCard monitor,
    UptimerDetailState detail,
  ) {
    if (monitor.type != UptimerMonitorType.heartbeat) return true;
    final points = detail.latency?.points ?? const [];
    return points.any((p) => p.latencyMs != null);
  }

  @override
  Widget build(BuildContext context) {
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
      return const SizedBox.shrink();
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
                      child:
                          latency?.avgLatencyMs != null ||
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
              UptimerInlineError(error: detail.latencyError!, onRetry: onRetry),
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
                            ? UptimerInlineError(
                                error: detail.latencyError!,
                                onRetry: onRetry,
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
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.35,
                                ),
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
                                    if (value == meta.max) {
                                      return const SizedBox();
                                    }
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
                                getTooltipColor: (_) =>
                                    scheme.surfaceContainerHigh,
                                getTooltipItems: (items) => [
                                  for (final item in items)
                                    () {
                                      final idx = item.x.round();
                                      final ts = idx >= 0 && idx < points.length
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
}
