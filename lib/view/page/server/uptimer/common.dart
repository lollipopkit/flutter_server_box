import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/shared_hero.dart';

/// Outcome returned by [UptimerEditPage] so callers avoid refreshing a deleted
/// monitor.
enum UptimerEditResult { saved, deleted }

/// Route arguments for [UptimerDetailPage].
final class UptimerDetailArgs {
  final UptimerMonitorCard monitor;
  const UptimerDetailArgs({required this.monitor});
}

/// Route arguments for [UptimerEditPage].
final class UptimerEditArgs {
  final UptimerMonitorConfig? config;
  final UptimerMonitorCard? card;
  const UptimerEditArgs({this.config, this.card});
}

Color uptimerStatusColor(UptimerMonitorStatus status) => switch (status) {
  UptimerMonitorStatus.up => StatePalette.running,
  UptimerMonitorStatus.down => StatePalette.failed,
  UptimerMonitorStatus.maintenance => StatePalette.warn,
  UptimerMonitorStatus.paused || UptimerMonitorStatus.unknown => StatePalette.idle,
};

String uptimerStatusText(UptimerMonitorStatus status) => switch (status) {
  UptimerMonitorStatus.up => l10n.uptimerStatusUp,
  UptimerMonitorStatus.down => l10n.uptimerStatusDown,
  UptimerMonitorStatus.maintenance => l10n.uptimerStatusMaintenance,
  UptimerMonitorStatus.paused => l10n.uptimerStatusPaused,
  UptimerMonitorStatus.unknown => l10n.uptimerStatusUnknown,
};

String uptimerTestStatusText(UptimerTestResult res) => switch (res.status) {
  'up' => l10n.uptimerStatusUp,
  'down' => l10n.uptimerStatusDown,
  _ => l10n.uptimerStatusUnknown,
};

Color uptimerTestStatusColor(UptimerTestResult res) => switch (res.status) {
  'up' => StatePalette.running,
  'down' => StatePalette.failed,
  _ => StatePalette.idle,
};

IconData uptimerTypeIcon(UptimerMonitorType type) => switch (type) {
  UptimerMonitorType.http => Icons.language,
  UptimerMonitorType.tcp => Icons.lan_outlined,
  UptimerMonitorType.heartbeat => Icons.monitor_heart_outlined,
};

String formatUptimePct(double? pct) {
  if (pct == null) return '—';
  if (pct >= 99.995) return '100%';
  if (pct <= 0) return '0%';
  final fixed = pct.toStringAsFixed(2);
  if (fixed.endsWith('.00')) return '${fixed.substring(0, fixed.length - 3)}%';
  if (fixed.endsWith('0')) return '${fixed.substring(0, fixed.length - 1)}%';
  return '$fixed%';
}

String formatLatencyMs(int? ms) {
  if (ms == null) return '—';
  if (ms >= 1000) return '${(ms / 1000).toStringAsFixed(2)} s';
  return '$ms ms';
}

String formatDurationSec(int sec) {
  final s = sec < 0 ? 0 : sec;
  if (s < 60) return '${s}s';
  final m = s ~/ 60;
  final remS = s % 60;
  if (m < 60) return remS == 0 ? '${m}m' : '${m}m ${remS}s';
  final h = m ~/ 60;
  final remM = m % 60;
  if (h < 24) return remM == 0 ? '${h}h' : '${h}h ${remM}m';
  final d = h ~/ 24;
  final remH = h % 24;
  return remH == 0 ? '${d}d' : '${d}d ${remH}h';
}

String formatRelativeUnix(int? unixSec, {DateTime? now}) {
  if (unixSec == null || unixSec <= 0) return '—';
  final refNow = now ?? DateTime.now();
  final diff = refNow.millisecondsSinceEpoch ~/ 1000 - unixSec;
  if (diff < 5) return 'now';
  if (diff < 60) return '${diff}s';
  if (diff < 3600) return '${diff ~/ 60}m';
  if (diff < 86400) return '${diff ~/ 3600}h';
  return '${diff ~/ 86400}d';
}

String formatTimestampUnix(int unixSec) {
  final dt = DateTime.fromMillisecondsSinceEpoch(unixSec * 1000).toLocal();
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

String formatShortDateUnix(int unixSec) {
  final dt = DateTime.fromMillisecondsSinceEpoch(unixSec * 1000, isUtc: true);
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${two(dt.month)}-${two(dt.day)}';
}

String uptimerErrorMessage(Object error) {
  if (error is LkcException) {
    final msg = error.message?.trim();
    if (msg != null && msg.isNotEmpty) return msg;
    final reason = error.reason?.trim();
    if (reason != null && reason.isNotEmpty) return reason;
    if (error.status != null) return 'HTTP ${error.status}';
  }
  return '$error';
}

/// Hero wrapper for [UptimerHeartbeatStrip] when opening a monitor pushes a new
/// route (narrow/mobile layout).
final class UptimerStripHero extends StatelessWidget {
  final int monitorId;
  final bool enabled;
  final Widget child;

  const UptimerStripHero({
    super.key,
    required this.monitorId,
    required this.enabled,
    required this.child,
  });

  static Object tagOf(int id) => 'uptimer_strip_$id';

  @override
  Widget build(BuildContext context) => SharedElementHero(
    tag: tagOf(monitorId),
    enabled: enabled,
    child: child,
  );
}

/// Compact horizontal strip of recent check bars, oldest -> newest left-to-right.
final class UptimerHeartbeatStrip extends StatelessWidget {
  /// Heartbeats in API order (newest first).
  final List<UptimerHeartbeat> heartbeats;
  final int count;
  final double height;
  final double gap;
  final double radius;
  final int? selectedIndex;
  final void Function(int index, UptimerHeartbeat? beat)? onSelect;

  const UptimerHeartbeatStrip({
    super.key,
    required this.heartbeats,
    this.count = 30,
    this.height = 14,
    this.gap = 2,
    this.radius = 2,
    this.selectedIndex,
    this.onSelect,
  });

  /// Resolves the displayed slot index (`0..count-1`, oldest -> newest left to
  /// right) and matching [UptimerHeartbeat] for [checkedAt] within the newest
  /// [count] entries of newest-first [heartbeats].
  static ({int index, UptimerHeartbeat beat})? slotOf(
    List<UptimerHeartbeat> heartbeats,
    int count,
    int checkedAt,
  ) {
    final take = heartbeats.length < count ? heartbeats.length : count;
    for (var i = 0; i < take; i++) {
      final beat = heartbeats[i];
      if (beat.checkedAt == checkedAt) {
        return (index: count - 1 - i, beat: beat);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final emptyColor = scheme.outlineVariant.withValues(alpha: 0.45);
    final take = heartbeats.length < count ? heartbeats.length : count;
    final pad = count - take;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              child: _buildBar(
                index: i,
                beat: i < pad ? null : heartbeats[count - 1 - i],
                emptyColor: emptyColor,
                selected: selectedIndex == i,
                ringColor: scheme.onSurface,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBar({
    required int index,
    required UptimerHeartbeat? beat,
    required Color emptyColor,
    required bool selected,
    required Color ringColor,
  }) {
    final color = switch (beat?.status) {
      'up' => StatePalette.running,
      'down' => StatePalette.failed,
      null => emptyColor,
      _ => StatePalette.idle,
    };
    final hasSelection = selectedIndex != null;
    final alpha = beat == null
        ? 1.0
        : selected
        ? 1.0
        : hasSelection
        ? 0.45
        : 0.85;
    final decoration = BoxDecoration(
      color: beat == null ? color : color.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(radius),
      border: selected ? Border.all(color: ringColor, width: 1.2) : null,
    );
    if (onSelect == null) {
      return SizedBox(
        height: height,
        child: DecoratedBox(decoration: decoration),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect!(index, beat),
      child: SizedBox(
        height: height,
        child: DecoratedBox(decoration: decoration),
      ),
    );
  }
}

/// Compact error strip shown on the Status tab when Uptimer sync fails while
/// signed in.
final class UptimerSyncErrorBanner extends StatelessWidget {
  final Object error;
  final bool loading;
  final VoidCallback onRetry;

  const UptimerSyncErrorBanner({
    super.key,
    required this.error,
    required this.loading,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 6, 11, 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(
              Icons.monitor_heart_outlined,
              size: 16,
              color: StatePalette.failed,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${l10n.uptimer}: ${uptimerErrorMessage(error)}',
                style: TextStyle(fontSize: 12, color: StatePalette.failed),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: SizedLoading(18, padding: 2),
                  )
                : TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(libL10n.retry),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Presents a newly issued heartbeat push URL once with one-tap copy actions.
Future<void> showUptimerPushUrlSheet(
  BuildContext context, {
  required String name,
  required Uri url,
}) async {
  final urlStr = url.toString();
  final curlCmd = 'curl -fsS "$urlStr"';
  await context.showSheet<void>(
    title: l10n.uptimerPushUrl,
    dismissible: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.uptimerPushUrlOnce,
          style: TextStyle(
            fontSize: 13,
            color: StatePalette.warn,
            fontWeight: FontWeight.w500,
          ),
        ),
        UIs.height13,
        _CopyableCodeBox(label: name, text: urlStr),
        const SizedBox(height: 9),
        _CopyableCodeBox(label: 'curl', text: curlCmd),
      ],
    ),
    actions: [
      Btn.text(
        text: libL10n.copy,
        onTap: () {
          Pfs.copy(urlStr);
          Toast.show(libL10n.success);
        },
      ),
      Btn.ok(onTap: () => context.popSheet()),
    ],
  );
}

final class _CopyableCodeBox extends StatelessWidget {
  final String label;
  final String text;

  const _CopyableCodeBox({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () {
        Pfs.copy(text);
        Toast.show(libL10n.success);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontFeatures: kTabularFigures,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.copy, size: 17, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
