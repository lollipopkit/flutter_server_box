import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/provider/uptimer/detail.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/status_shell.dart';
import 'package:server_box/view/page/uptimer/common.dart';
import 'package:server_box/view/page/uptimer/detail_sections.dart';

/// Primary status summary, quick action buttons, last test result, and
/// incident/maintenance notices card for [UptimerDetailPage].
final class UptimerStatusCard extends StatelessWidget {
  final UptimerMonitorCard monitor;
  final UptimerMonitorConfig? config;
  final UptimerDetailState detail;
  final bool busy;
  final List<UptimerIncident> incidents;
  final List<UptimerMaintenanceWindow> activeMaint;
  final List<UptimerMaintenanceWindow> upcomingMaint;
  final VoidCallback onTest;
  final VoidCallback onTogglePause;
  final VoidCallback onRotatePushToken;

  const UptimerStatusCard({
    super.key,
    required this.monitor,
    required this.config,
    required this.detail,
    required this.busy,
    required this.incidents,
    required this.activeMaint,
    required this.upcomingMaint,
    required this.onTest,
    required this.onTogglePause,
    required this.onRotatePushToken,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = uptimerStatusColor(monitor.status);
    final isPaused = monitor.status == UptimerMonitorStatus.paused;
    final subtitle = config != null && config!.target.isNotEmpty
        ? config!.target
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
                  onPressed: busy ? null : onTest,
                  icon: busy
                      ? kUptimerCircularLoading
                      : const Icon(Icons.play_arrow, size: 17),
                  label: Text(l10n.uptimerTest),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onTogglePause,
                  icon: Icon(
                    isPaused
                        ? Icons.play_circle_outline
                        : Icons.pause_circle_outline,
                    size: 17,
                  ),
                  label: Text(
                    isPaused ? l10n.uptimerResume : l10n.uptimerPause,
                  ),
                ),
                if (monitor.type == UptimerMonitorType.heartbeat)
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onRotatePushToken,
                    icon: const Icon(Icons.key_outlined, size: 17),
                    label: Text(l10n.uptimerRotatePushUrl),
                  ),
              ],
            ),
            if (detail.lastTest case final test?) ...[
              const SizedBox(height: 11),
              UptimerTestResultBanner(test: test),
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
      child: StatusNoticeBanner(
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
}
