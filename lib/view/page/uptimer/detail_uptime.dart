import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/provider/uptimer/detail.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/detail/focus_parts.dart';
import 'package:server_box/view/page/server/tab/element_flight.dart';
import 'package:server_box/view/page/uptimer/common.dart';
import 'package:server_box/view/page/uptimer/detail_sections.dart';

/// Uptime percentage, interactive heartbeat strip, and 60-day rollup bar card.
final class UptimerUptimeCard extends StatefulWidget {
  final UptimerMonitorCard monitor;
  final UptimerDetailState detail;
  final bool bare;
  final FlightAnchorBinding? stripAnchor;
  final bool hideStrip;
  final ValueChanged<UptimerRange> onRangeSelected;
  final VoidCallback onRetry;

  const UptimerUptimeCard({
    super.key,
    required this.monitor,
    required this.detail,
    required this.bare,
    this.stripAnchor,
    this.hideStrip = false,
    required this.onRangeSelected,
    required this.onRetry,
  });

  @override
  State<UptimerUptimeCard> createState() => _UptimerUptimeCardState();
}

final class _UptimerUptimeCardState extends State<UptimerUptimeCard> {
  int? _inspectedCheckedAt;

  @override
  void didUpdateWidget(covariant UptimerUptimeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.monitor.id != widget.monitor.id) {
      _inspectedCheckedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final monitor = widget.monitor;
    final detail = widget.detail;
    final scheme = Theme.of(context).colorScheme;
    final totals =
        detail.currentUptime ??
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
              onSelected: widget.onRangeSelected,
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
                    key: ValueKey('${detail.range.wire}:${totals?.uptimePct}'),
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
                              child: kUptimerCircularLoading,
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
              UptimerInlineError(error: err, onRetry: widget.onRetry),
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
                      monitorId: monitor.id,
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
}
