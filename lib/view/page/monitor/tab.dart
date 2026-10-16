import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/monitor_overview.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/monitor/apps.dart';
import 'package:server_box/view/page/monitor/audit.dart';
import 'package:server_box/view/page/monitor/common.dart';
import 'package:server_box/view/page/monitor/live.dart';
import 'package:server_box/view/page/monitor/notices.dart';
import 'package:server_box/view/page/monitor/overview.dart';
import 'package:server_box/view/widget/pane_settings.dart';
import 'package:server_box/view/widget/swap_switcher.dart';

/// What the Monitor tab shows, one at a time.
enum MonitorSection {
  overview,
  apps,
  notices,
  audit,
  live;

  IconData get icon => switch (this) {
    overview => Icons.dashboard_outlined,
    apps => Icons.apps,
    notices => Icons.notifications_none,
    audit => Icons.receipt_long_outlined,
    live => Icons.devices_outlined,
  };

  String get label => switch (this) {
    overview => l10n.monitorOverview,
    apps => l10n.webApps,
    notices => l10n.monitorNotices,
    audit => l10n.monitorAudit,
    live => l10n.monitorLive,
  };

  /// Read from one server at a time: a log or a list of sessions is about one
  /// machine, and several interleaved would hide which.
  bool get scoped => this == audit || this == live;

  /// The agent's `features` entry this needs; null for the overview, which
  /// says what each agent offers.
  String? get feature => switch (this) {
    overview => null,
    apps => 'stacks',
    notices => 'desk',
    audit => 'audit',
    live => 'live',
  };
}

/// The bar a section's page carries, made by the tab for the layout it is
/// in: [actions] are the section's own.
typedef MonitorBar =
    PreferredSizeWidget Function(List<BarAction> actions, {InlineSearchController? search, String? searchHint});

/// Every server reached through a `monitor` agent, from the agents' side: how
/// each agent is and what it says is wrong now, the web apps they deployed,
/// their notifications, and, one server at a time, the audit log and what is
/// signed in and open.
///
/// Two columns: the sections and the servers, and the section under a head
/// saying which servers it is for. One column is the section, with the
/// section and the server behind the bar's switcher and its server button.
class MonitorTabPage extends ConsumerStatefulWidget {
  const MonitorTabPage({super.key});

  @override
  ConsumerState<MonitorTabPage> createState() => _MonitorTabPageState();
}

class _MonitorTabPageState extends ConsumerState<MonitorTabPage> {
  var _section = MonitorSection.overview;

  /// The server chosen; null for every one. A scoped section with none
  /// chosen shows the first that offers it, and says so.
  String? _serverId;

  // Not kept alive: the home page disposes a tab off screen, and with it the
  // agents it polled.

  @override
  Widget build(BuildContext context) {
    // Watched here, on this page's element: the pane builders run on theirs.
    final all = ref.watch(serversProvider);
    final servers = <Spi>[
      for (final id in all.serverOrder)
        if (all.servers[id] case final spi? when spi.monitorOn != null) spi,
    ];
    if (_serverId != null && !servers.any((s) => s.id == _serverId)) _serverId = null;
    final offered = {
      for (final spi in servers)
        // Joined, so it compares by value: see `MonitorOverviewNotifier.build`.
        spi.id: ref
            .watch(serverProvider(spi.id).select((s) => ([...?s.agentCapabilities?.features]..sort()).join(',')))
            .split(',')
            .toSet(),
    };
    final scope = _scope(servers, offered);

    return PaneSettings.listenAll((paneWidth, paneCollapsed) {
      return AdaptivePanes.detail(
        listWidth: paneWidth,
        onListWidthChanged: PaneSettings.saveWidth,
        collapsed: paneCollapsed,
        onCollapsedChanged: PaneSettings.saveCollapsed,
        collapseTooltip: libL10n.fold,
        expandTooltip: libL10n.open,
        // Never a detail of its own to open: the section is the column beside
        // the rail, and the whole tab with one column.
        detailId: null,
        onCloseDetail: () {},
        detailBuilder: (_) => _buildSection(
          servers,
          scope,
          (actions, {search, searchHint}) => MonitorPaneHeader(
            title: _section.label,
            subtitle: _subtitle(servers, scope),
            actions: actions,
            search: search,
            searchHint: searchHint,
          ),
        ),
        listBuilder: (_, split) => split
            ? _buildRail(servers, scope)
            : _buildSection(
                servers,
                scope,
                (actions, {search, searchHint}) => _narrowBar(servers, scope, actions, search, searchHint),
              ),
      );
    });
  }

  /// The servers the section shows: every one, the one chosen, or for a
  /// scoped section the one it reads (null when none offers it).
  List<Spi> _scope(List<Spi> servers, Map<String, Set<String>> offered) {
    final chosen = _serverId == null ? servers : servers.where((s) => s.id == _serverId).toList();
    if (!_section.scoped) return chosen;
    final feature = _section.feature!;
    final first = chosen.firstWhereOrNull((s) => offered[s.id]?.contains(feature) ?? false);
    return [?first];
  }

  String _subtitle(List<Spi> servers, List<Spi> scope) {
    if (_section.scoped || _serverId != null) return scope.firstOrNull?.name ?? '';
    return l10n.monitorAgentsCount(servers.length);
  }

  /// The section on screen, crossing to the next when another section or
  /// server is chosen.
  Widget _buildSection(List<Spi> servers, List<Spi> scope, MonitorBar bar) => SwapSwitcher(
    child: KeyedSubtree(
      key: ValueKey((_section, _serverId, servers.isEmpty)),
      child: _buildSectionBody(servers, scope, bar),
    ),
  );

  Widget _buildSectionBody(List<Spi> servers, List<Spi> scope, MonitorBar bar) {
    if (servers.isEmpty) {
      return Scaffold(
        appBar: bar(const []),
        body: EmptyPane(icon: Icons.monitor_heart_outlined, label: l10n.monitorNoAgents),
      );
    }
    void open(MonitorSection section, String serverId) => setState(() {
      _section = section;
      _serverId = serverId;
    });
    if (_section.scoped) {
      final spi = scope.firstOrNull;
      if (spi == null) {
        return Scaffold(
          appBar: bar(const []),
          body: EmptyPane(icon: _section.icon, label: l10n.monitorNotOffered),
        );
      }
      return switch (_section) {
        MonitorSection.audit => MonitorAuditView(key: ValueKey('audit/${spi.id}'), spi: spi, bar: bar),
        _ => MonitorLiveView(key: ValueKey('live/${spi.id}'), spi: spi, bar: bar),
      };
    }
    return switch (_section) {
      MonitorSection.overview => MonitorOverviewView(servers: scope, bar: bar, onOpen: open),
      MonitorSection.apps => MonitorAppsView(servers: scope, bar: bar),
      _ => MonitorNoticesView(servers: scope, bar: bar),
    };
  }

  /// One column: the section on the left, opening the rest; which server
  /// beside the section's own actions.
  PreferredSizeWidget _narrowBar(
    List<Spi> servers,
    List<Spi> scope,
    List<BarAction> actions,
    InlineSearchController? search,
    String? searchHint,
  ) {
    final server = _section.scoped || _serverId != null ? scope.firstOrNull?.name : null;
    return SwitcherBar(
      search: search,
      searchHint: searchHint,
      switcher: SessionSwitcherLabel(name: _section.label, icon: _section.icon, onTap: _pickSection),
      actions: [
        if (search != null) BarAction(icon: Icons.search, label: libL10n.search, onTap: search.start),
        if (servers.length > 1)
          BarAction(
            icon: Icons.dns_outlined,
            label: server ?? libL10n.all,
            color: server == null ? null : Theme.of(context).colorScheme.primary,
            onTap: () => _pickServer(servers, scope),
          ),
        ...actions,
      ],
    );
  }

  Widget _buildRail(List<Spi> servers, List<Spi> scope) {
    final scheme = Theme.of(context).colorScheme;
    var alerts = 0;
    var unread = 0;
    final firing = <String, int>{};
    for (final spi in servers) {
      final state = ref.watch(monitorOverviewProvider(spi.id));
      firing[spi.id] = state.alerts?.alerts.length ?? 0;
      if (_serverId != null && spi.id != _serverId) continue;
      alerts += firing[spi.id]!;
      unread += state.notices?.unread ?? 0;
    }
    Widget? count(int n, {Color? color}) => n <= 0
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: (color ?? scheme.primary).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '$n',
              style: TextStyle(color: color ?? scheme.primary, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          );
    final shown = _section.scoped ? scope.firstOrNull?.id : _serverId;
    return WindowControlsInset(
      safeArea: true,
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 13),
        children: [
          for (final section in MonitorSection.values)
            SideBarTile(
              key: ValueKey(section),
              title: section.label,
              icon: section.icon,
              trailing: switch (section) {
                MonitorSection.overview => count(alerts, color: scheme.error),
                MonitorSection.notices => count(unread),
                _ => null,
              },
              selected: _section == section,
              onTap: () => setState(() => _section = section),
            ),
          if (servers.length > 1) ...[
            SideBarSection(libL10n.servers),
            // A scoped section reads one server: "all" would only pick one.
            if (!_section.scoped)
              SideBarTile(
                title: libL10n.all,
                icon: Icons.dns_outlined,
                selected: _serverId == null,
                onTap: () => setState(() => _serverId = null),
              ),
            for (final spi in servers)
              SideBarTile(
                key: ValueKey(spi.id),
                title: spi.name,
                leading: Center(
                  child: MonitorDot(
                    monitorConnColor(ref.watch(serverProvider(spi.id).select((s) => s.conn)), scheme),
                  ),
                ),
                trailing: count(firing[spi.id] ?? 0, color: scheme.error),
                selected: shown == spi.id,
                onTap: () => setState(() => _serverId = spi.id),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickSection() => showRowsSheet<void>(
    context,
    rows: (ctx) => [
      for (final section in MonitorSection.values)
        SheetChoiceTile(
          icon: section.icon,
          title: section.label,
          selected: _section == section,
          onTap: () {
            Navigator.of(ctx).pop();
            setState(() => _section = section);
          },
        ),
    ],
  );

  Future<void> _pickServer(List<Spi> servers, List<Spi> scope) => showRowsSheet<void>(
    context,
    rows: (ctx) {
      void pick(String? id) {
        Navigator.of(ctx).pop();
        setState(() => _serverId = id);
      }

      return [
        // A section read from one server at a time has no "all".
        if (!_section.scoped) ...[
          SheetChoiceTile(
            icon: Icons.dns_outlined,
            title: libL10n.all,
            selected: _serverId == null,
            onTap: () => pick(null),
          ),
          const Divider(height: 1),
        ],
        for (final spi in servers)
          SheetChoiceTile(
            icon: Icons.dns_outlined,
            title: spi.name,
            selected: (_section.scoped ? scope.firstOrNull?.id : _serverId) == spi.id,
            onTap: () => pick(spi.id),
          ),
      ];
    },
  );
}
