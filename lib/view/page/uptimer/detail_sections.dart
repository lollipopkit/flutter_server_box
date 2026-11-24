import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/provider/uptimer/detail.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/status_shell.dart';
import 'package:server_box/view/page/server/detail/focus_parts.dart';
import 'package:server_box/view/page/uptimer/common.dart';

/// Shared compact circular loading indicator for Uptimer detail widgets.
const kUptimerCircularLoading = SizedLoading(
  16,
  padding: 1,
  builder: SizedLoading.circularBuilder,
);

/// Compact inline error row with a retry action used across Uptimer detail
/// cards.
final class UptimerInlineError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const UptimerInlineError({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
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
}

/// Banner displaying the result of an on-demand Uptimer monitor test.
final class UptimerTestResultBanner extends StatelessWidget {
  final UptimerTestResult test;

  const UptimerTestResultBanner({super.key, required this.test});

  @override
  Widget build(BuildContext context) {
    final tone = uptimerTestStatusColor(test);
    final parts = <String>[
      uptimerTestStatusText(test),
      if (test.latencyMs case final ms?) formatLatencyMs(ms),
      if (test.httpStatus case final code?) 'HTTP $code',
    ];
    return StatusNoticeBanner(
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
}

/// Outage history card with pagination and inline error recovery.
final class UptimerOutagesCard extends StatelessWidget {
  final UptimerDetailState detail;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  const UptimerOutagesCard({
    super.key,
    required this.detail,
    required this.onRetry,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
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
        child: UptimerInlineError(error: err, onRetry: onRetry),
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
            UptimerInlineError(error: err, onRetry: onRetry),
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
                    : onLoadMore,
                child: detail.loadingMoreOutages
                    ? kUptimerCircularLoading
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
                          child: kUptimerCircularLoading,
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
}

/// Read-only configuration summary card for an Uptimer monitor.
final class UptimerConfigCard extends StatelessWidget {
  final UptimerMonitorConfig cfg;

  const UptimerConfigCard({super.key, required this.cfg});

  @override
  Widget build(BuildContext context) {
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
      (l10n.uptimerPublic, cfg.showOnStatusPage ? libL10n.ok : '—'),
      if (cfg.type == UptimerMonitorType.http) ...[
        if (cfg.httpMethod case final m?) (l10n.uptimerMethod, m),
        if (cfg.expectedStatus case final s?)
          (l10n.uptimerExpectedStatus, UptimerStatusRule.formatList(s)),
        if (cfg.forbiddenStatus case final s?)
          (l10n.uptimerForbiddenStatus, UptimerStatusRule.formatList(s)),
        if (cfg.responseKeyword case final k?) (l10n.uptimerKeyword, k),
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
}
