import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor_stack.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/web_apps.dart';
import 'package:server_box/view/page/monitor/common.dart';
import 'package:server_box/view/page/monitor/tab.dart';
import 'package:server_box/view/page/web_apps/detail.dart';
import 'package:server_box/view/page/web_apps/status.dart';

/// The web apps the agents deployed, a group per server, an app with an
/// update first.
///
/// A tap opens the app in the device's browser, which is what it is listed
/// for; the info button its page. Deploying, updating and removing stay in
/// the panel: this is where the apps are used, not run.
class MonitorAppsView extends ConsumerStatefulWidget {
  const MonitorAppsView({super.key, required this.servers, required this.bar});

  final List<Spi> servers;
  final MonitorBar bar;

  @override
  ConsumerState<MonitorAppsView> createState() => _MonitorAppsViewState();
}

class _MonitorAppsViewState extends ConsumerState<MonitorAppsView> {
  final _search = InlineSearchController();

  /// Only the apps the catalog has a newer version of.
  var _updatesOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh(List<Spi> servers) => Future.wait([
    for (final spi in servers) ref.read(webAppsProvider(spi.id).notifier).refresh(),
  ]);

  @override
  Widget build(BuildContext context) {
    final servers = [
      for (final spi in widget.servers)
        if (ref.watch(webAppsProvider(spi.id)) case final state when state.offered) (spi: spi, state: state),
    ];
    final scheme = Theme.of(context).colorScheme;
    return ListenBuilder(
      listenable: _search,
      builder: () => Scaffold(
        appBar: widget.bar(
          [
            BarAction(
              icon: Icons.system_update_alt,
              label: l10n.monitorUpdatesOnly,
              color: _updatesOnly ? scheme.primary : null,
              onTap: () => setState(() => _updatesOnly = !_updatesOnly),
            ),
            BarAction(
              icon: Icons.refresh,
              label: libL10n.refresh,
              onTap: () => unawaited(_refresh([for (final s in servers) s.spi])),
            ),
          ],
          search: _search,
          searchHint: l10n.webApps,
        ),
        body: _buildList(servers),
      ),
    );
  }

  Widget _buildList(List<({Spi spi, WebAppsState state})> servers) {
    final needle = _search.needle;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final groups = <({Spi spi, String? error, List<MonitorWebApp> apps})>[];
    var waiting = false;
    for (final (:spi, :state) in servers) {
      final apps = state.apps;
      if (apps == null) {
        if (state.error == null) {
          waiting = true;
        } else {
          groups.add((spi: spi, error: state.error, apps: const []));
        }
        continue;
      }
      final matched = [
        for (final app in apps)
          if ((!_updatesOnly || app.updatable) &&
              (needle.isEmpty ||
                  app.titleIn(locale).toLowerCase().contains(needle) ||
                  spi.name.toLowerCase().contains(needle)))
            app,
      ];
      // Stable: the agent's order within each half.
      final ordered = [...matched.where((a) => a.updatable), ...matched.where((a) => !a.updatable)];
      if (ordered.isNotEmpty) groups.add((spi: spi, error: null, apps: ordered));
    }
    if (groups.isEmpty) {
      if (waiting) return UIs.centerLoading;
      return EmptyPane(
        icon: needle.isEmpty ? Icons.apps : Icons.search_off,
        label: needle.isNotEmpty
            ? _search.needle
            : _updatesOnly
            ? l10n.monitorNoUpdates
            : l10n.webAppsEmpty,
      );
    }
    return MonitorList(
      onRefresh: () => _refresh([for (final s in servers) s.spi]),
      children: [
        for (final group in groups)
          MonitorGroup(
            title: group.spi.name,
            right: group.error == null ? '${group.apps.length}' : null,
            children: [
              if (group.error case final error?)
                MonitorRow(
                  leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                  title: libL10n.fail,
                  subtitle: error,
                )
              else
                for (final app in group.apps) _buildRow(group.spi, app, locale),
            ],
          ),
      ],
    );
  }

  Widget _buildRow(Spi spi, MonitorWebApp app, String locale) {
    final scheme = Theme.of(context).colorScheme;
    final (status, verdict) = webAppStatus(app);
    final args = WebAppPageArgs(serverId: spi.id, appId: app.id);
    return MonitorRow(
      key: ValueKey('${spi.id}/${app.id}'),
      leading: MonitorDot(verdict.color(scheme), tooltip: status),
      title: app.titleIn(locale),
      subtitle: [status, if (app.failing.isNotEmpty) app.failing.join(', ')].join(' · '),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (app.updatable)
            MonitorTag('${app.version} → ${app.latest}', icon: Icons.arrow_upward, color: scheme.primary),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            tooltip: libL10n.about,
            onPressed: () => WebAppPage.route.go(context, args: args),
          ),
        ],
      ),
      // An app the proxy is not in front of (being deployed, failed) cannot
      // be opened: its page says why.
      onTap: app.proxy ? () => openWebApp(ref, spi.id, app.id) : () => WebAppPage.route.go(context, args: args),
    );
  }
}
