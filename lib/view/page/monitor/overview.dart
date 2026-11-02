import 'dart:async';
import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_overview.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/monitor_release.dart';
import 'package:server_box/data/provider/server/monitor_overview.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/server/web_apps.dart';
import 'package:server_box/view/page/monitor/common.dart';
import 'package:server_box/view/page/monitor/tab.dart';
import 'package:server_box/view/page/monitor/update_agent.dart';

/// The agents at a glance: a line of counts over them all, then a card per
/// agent saying whether it answers, how old it is, what fires on it now, and
/// what waits in the other sections.
class MonitorOverviewView extends ConsumerWidget {
  const MonitorOverviewView({super.key, required this.servers, required this.bar, required this.onOpen});

  final List<Spi> servers;
  final MonitorBar bar;

  /// Opens [section] narrowed to one server.
  final void Function(MonitorSection section, String serverId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    var online = 0;
    var firing = 0;
    var unread = 0;
    var updates = 0;
    // Whether an agent cannot say its newest release itself: too old to sign
    // in to, or to have `/update`.
    var unsaid = false;
    for (final spi in servers) {
      if (_answers(ref.watch(serverProvider(spi.id).select((s) => s.conn)))) online++;
      unsaid |= ref.watch(
        serverProvider(spi.id).select((s) {
          final err = s.status.err;
          if (err is MonitorHttpErr && err.type == MonitorHttpErrType.agentTooOld) return true;
          return s.agentCapabilities?.features.contains('update') == false;
        }),
      );
      final overview = ref.watch(monitorOverviewProvider(spi.id));
      firing += overview.alerts?.alerts.length ?? 0;
      unread += overview.notices?.unread ?? 0;
      updates += ref.watch(webAppsProvider(spi.id)).apps?.where((a) => a.updatable).length ?? 0;
    }

    // Read from GitHub only for such an agent. A failed lookup is no newer
    // release: nothing to say, rather than an error on every card.
    final latest = unsaid ? ref.watch(monitorLatestReleaseProvider).value : null;

    Future<void> refresh() => Future.wait([
      for (final spi in servers) ref.read(monitorOverviewProvider(spi.id).notifier).refresh(),
    ]);

    return Scaffold(
      appBar: bar([
        BarAction(icon: Icons.refresh, label: libL10n.refresh, onTap: () => unawaited(refresh())),
      ]),
      body: MonitorList(
        onRefresh: refresh,
        children: [
          UIs.height7,
          _Stats(
            stats: [
              (Icons.dns_outlined, '$online/${servers.length}', l10n.monitorStatOnline, null),
              (
                Icons.warning_amber_rounded,
                '$firing',
                l10n.monitorStatFiring,
                firing > 0 ? scheme.error : null,
              ),
              (Icons.notifications_none, '$unread', l10n.monitorStatUnread, unread > 0 ? scheme.primary : null),
              (Icons.system_update_alt, '$updates', l10n.monitorStatUpdates, updates > 0 ? scheme.primary : null),
            ],
          ),
          UIs.height13,
          _Grid(
            children: [
              for (final spi in servers)
                _AgentCard(key: ValueKey(spi.id), spi: spi, latest: latest, onOpen: onOpen),
            ],
          ),
        ],
      ),
    );
  }

  static bool _answers(ServerConn conn) =>
      conn == ServerConn.connected || conn == ServerConn.loading || conn == ServerConn.finished;
}

/// The counts over every agent shown, side by side.
class _Stats extends StatelessWidget {
  const _Stats({required this.stats});

  final List<(IconData, String, String, Color?)> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        // Four across where they fit, two by two on a phone.
        final across = cons.maxWidth >= 560 ? stats.length : 2;
        const gap = 9.0;
        final width = (cons.maxWidth - gap * (across - 1)) / across;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (icon, value, label, color) in stats)
              SizedBox(
                width: width,
                child: CardX(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                value,
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: color),
                              ),
                              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: UIs.text12Grey),
                            ],
                          ),
                        ),
                        Icon(icon, size: 22, color: color ?? UIs.textGrey.color),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Equal columns, as many as fit at a card's width.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        const gap = 9.0;
        final across = math.max(1, ((cons.maxWidth + gap) / (UIs.columnWidth + gap)).floor());
        final width = (cons.maxWidth - gap * (across - 1)) / across;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

class _AgentCard extends ConsumerWidget {
  const _AgentCard({super.key, required this.spi, required this.latest, required this.onOpen});

  final Spi spi;
  /// The newest release as this app read it, for an agent too old to say.
  final String? latest;
  final void Function(MonitorSection section, String serverId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final conn = ref.watch(serverProvider(spi.id).select((s) => s.conn));
    // Its parts: the capabilities are a new object on every status read.
    final reached = ref.watch(serverProvider(spi.id).select((s) => s.agentCapabilities != null));
    final version = ref.watch(serverProvider(spi.id).select((s) => s.agentCapabilities?.version));
    final overview = ref.watch(monitorOverviewProvider(spi.id));
    final apps = ref.watch(webAppsProvider(spi.id)).apps ?? const [];
    // The agent's own answer where it gives one; this app's read otherwise.
    final update = overview.update;
    final (outdated, newest) = update?.latest != null
        ? (update!.outdated, update.latest)
        : (monitorOutdated(version, latest), latest);

    final updates = apps.where((a) => a.updatable).length;
    final unwell = apps.where((a) => const {'unhealthy', 'down'}.contains(a.health)).length;
    final unread = overview.notices?.unread ?? 0;

    final alerts = overview.alerts;
    final err = ref.watch(serverProvider(spi.id).select((s) => s.status.err));
    final tooOld = err is MonitorHttpErr && err.type == MonitorHttpErrType.agentTooOld;
    final Widget rules;
    if (!reached) {
      // Not reached: why, rather than an answer that never comes.
      rules = switch (conn) {
        ServerConn.failed => _line(
          Icons.error_outline,
          // The solution of a too-old agent points here; the button below is it.
          [err?.message ?? libL10n.fail, if (!tooOld) ?err?.solution].join('\n'),
          scheme.error,
        ),
        ServerConn.connecting => _line(Icons.hourglass_empty, libL10n.loadingEllipsis, null),
        _ => _line(Icons.link_off, libL10n.disconnected, null),
      };
    } else if (!overview.offers('alerts')) {
      rules = _line(Icons.info_outline, l10n.monitorAlertsNotOffered, null);
    } else if (alerts == null) {
      rules = overview.error == null
          ? _line(Icons.hourglass_empty, libL10n.loadingEllipsis, null)
          : _line(Icons.error_outline, '${libL10n.fail}: ${overview.error}', scheme.error);
    } else if (alerts.alerts.isEmpty) {
      rules = _line(Icons.check_circle_outline, l10n.monitorAlertsNone, Colors.green);
    } else {
      rules = Column(children: [for (final alert in alerts.alerts) _AlertLine(alert: alert)]);
    }

    return CardX(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => onOpen(MonitorSection.overview, spi.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 13, 13, 9),
              child: Row(
                children: [
                  MonitorDot(monitorConnColor(conn, scheme)),
                  UIs.width7,
                  Expanded(
                    child: Text(
                      spi.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (version != null) MonitorTag(version),
                  if (outdated) ...[
                    const SizedBox(width: 5),
                    MonitorTag(
                      l10n.monitorAgentUpdate(newest!),
                      icon: Icons.arrow_upward,
                      color: scheme.primary,
                      onTap: () => unawaited(
                        showMonitorUpdate(
                          context,
                          spi,
                          MonitorOutdated(running: version!, latest: newest, update: update),
                          access: ref.read(serverProvider(spi.id)).agentCapabilities?.access,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.fromLTRB(15, 9, 15, 9), child: rules),
          if (tooOld)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 13),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.system_update_alt, size: 18),
                  label: Text(l10n.monitorHowToUpdate),
                  onPressed: () => unawaited(showMonitorUpdate(context, spi, const MonitorTooOld())),
                ),
              ),
            ),
          if (unread > 0 || updates > 0 || unwell > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (unwell > 0)
                    MonitorTag(
                      l10n.monitorAppsUnwell(unwell),
                      icon: Icons.error_outline,
                      color: scheme.error,
                      onTap: () => onOpen(MonitorSection.apps, spi.id),
                    ),
                  if (unread > 0)
                    MonitorTag(
                      l10n.monitorUnread(unread),
                      icon: Icons.notifications_none,
                      color: scheme.primary,
                      onTap: () => onOpen(MonitorSection.notices, spi.id),
                    ),
                  if (updates > 0)
                    MonitorTag(
                      l10n.monitorAppsUpdates(updates),
                      icon: Icons.system_update_alt,
                      onTap: () => onOpen(MonitorSection.apps, spi.id),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text, Color? color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: color ?? UIs.textGrey.color),
        UIs.width7,
        Expanded(
          child: Tooltip(
            message: text,
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: color == null ? UIs.text12Grey : TextStyle(fontSize: 12, color: color),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AlertLine extends StatelessWidget {
  const _AlertLine({required this.alert});

  final MonitorAlert alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final since = alert.since;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.warning_amber_rounded, size: 16, color: scheme.error),
          ),
          UIs.width7,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.rule, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  [
                    '${alert.value} ${alert.matcher} ${alert.threshold}',
                    if (since != null) l10n.monitorFiringFor(DateTime.now().difference(since).toAgoStr),
                  ].join(' · '),
                  style: UIs.text12Grey,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
