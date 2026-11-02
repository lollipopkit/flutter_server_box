import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor_overview.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/monitor_overview.dart';
import 'package:server_box/view/page/monitor/common.dart';
import 'package:server_box/view/page/monitor/notice_text.dart';
import 'package:server_box/view/page/monitor/tab.dart';

/// The agents' notifications, a group per server, newest first: a rule that
/// started firing, an app that went down or has an update, a disk or array in
/// trouble. Read state is the agent's, shared with the panel.
class MonitorNoticesView extends ConsumerWidget {
  const MonitorNoticesView({super.key, required this.servers, required this.bar});

  final List<Spi> servers;
  final MonitorBar bar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final groups = [
      for (final spi in servers)
        if (ref.watch(monitorOverviewProvider(spi.id)) case final state when state.offers('desk'))
          (spi: spi, state: state),
    ];
    final unread = groups.any((g) => (g.state.notices?.unread ?? 0) > 0);

    Future<void> refresh() => Future.wait([
      for (final g in groups) ref.read(monitorOverviewProvider(g.spi.id).notifier).refresh(),
    ]);

    final Widget body;
    if (groups.isEmpty) {
      body = EmptyPane(icon: Icons.notifications_none, label: l10n.monitorNotOffered);
    } else if (groups.every((g) => g.state.notices == null && g.state.error == null)) {
      body = UIs.centerLoading;
    } else if (groups.every((g) => g.state.notices?.notices.isEmpty ?? g.state.error == null)) {
      body = EmptyPane(icon: Icons.notifications_none, label: l10n.monitorNoticesEmpty);
    } else {
      final scheme = Theme.of(context).colorScheme;
      body = MonitorList(
        onRefresh: refresh,
        children: [
          for (final (:spi, :state) in groups)
            if (state.notices?.notices.isNotEmpty ?? state.error != null)
              MonitorGroup(
                title: spi.name,
                right: switch (state.notices?.unread) {
                  final n? when n > 0 => l10n.monitorUnread(n),
                  _ => null,
                },
                children: [
                  if (state.notices == null)
                    MonitorRow(
                      leading: Icon(Icons.error_outline, color: scheme.error),
                      title: libL10n.fail,
                      subtitle: state.error,
                    )
                  else
                    for (final notice in state.notices!.notices)
                      _NoticeRow(
                        key: ValueKey('${spi.id}/${notice.id}'),
                        notice: notice,
                        locale: locale,
                        onRead: () => _markRead(ref, spi.id, ids: [notice.id]),
                      ),
                ],
              ),
        ],
      );
    }

    return Scaffold(
      appBar: bar([
        BarAction(
          icon: Icons.done_all,
          label: l10n.monitorMarkAllRead,
          onTap: unread
              ? () {
                  for (final g in groups) {
                    if ((g.state.notices?.unread ?? 0) > 0) unawaited(_markRead(ref, g.spi.id, all: true));
                  }
                }
              : null,
        ),
        BarAction(icon: Icons.refresh, label: libL10n.refresh, onTap: () => unawaited(refresh())),
      ]),
      body: body,
    );
  }

  Future<void> _markRead(WidgetRef ref, String serverId, {List<int> ids = const [], bool all = false}) async {
    try {
      await ref.read(monitorOverviewProvider(serverId).notifier).markRead(ids: ids, all: all);
    } catch (e) {
      Toast.show(libL10n.fail, body: '$e');
    }
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({super.key, required this.notice, required this.locale, required this.onRead});

  final MonitorNotice notice;
  final String locale;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (subject, body) = noticeText(notice, locale);
    final (icon, color) = switch (notice.level) {
      'error' => (Icons.error_outline, scheme.error),
      'warning' => (Icons.warning_amber_rounded, Colors.orange),
      _ => (Icons.info_outline, scheme.primary),
    };
    return MonitorRow(
      leading: Icon(icon, color: color, size: 21),
      title: subject,
      subtitle: body,
      bold: !notice.read,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (notice.createdAt case final at?) Text(at.toAgoStr(), style: UIs.text11Grey),
          if (!notice.read) ...[const SizedBox(height: 5), MonitorDot(scheme.primary, size: 8)],
        ],
      ),
      onTap: notice.read ? null : onRead,
    );
  }
}
