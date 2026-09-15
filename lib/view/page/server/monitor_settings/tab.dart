// ignore_for_file: invalid_use_of_protected_member

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/server/monitor_settings/view.dart';
import 'package:server_box/view/widget/pane_settings.dart';

/// Every `monitor` agent's own configuration, in one place.
///
/// A tab as well as an entry on each server's page, because these settings
/// belong to the agent rather than to the machine: someone changing a
/// collection interval or an alert rule is usually doing it to several agents
/// in a row, and reaching each one through its server's page turns that into a
/// walk back and forth through the server list.
///
/// Only servers with an agent are listed. Asked of `spi.monitorHttp` rather
/// than of `ServerCapabilities`, which for a both-transports server answers the
/// union of what SSH and the agent can do — a capability question would put
/// SSH-only servers in a list of agents.
class MonitorSettingsTabPage extends ConsumerStatefulWidget {
  const MonitorSettingsTabPage({super.key});

  @override
  ConsumerState<MonitorSettingsTabPage> createState() =>
      _MonitorSettingsTabPageState();
}

class _MonitorSettingsTabPageState
    extends ConsumerState<MonitorSettingsTabPage> {
  /// The agent the surface is editing.
  String? _selectedId;

  /// One per server, kept for as long as the tab is: the bar's save button
  /// reads it, and rebuilding it on every layout change would lose what the
  /// view had told it.
  final _ctrls = <String, MonitorSettingsController>{};

  @override
  void dispose() {
    for (final ctrl in _ctrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  /// Servers with an agent, in the order the server tab shows them.
  List<Spi> get _servers {
    final order = ref.watch(serversProvider.select((s) => s.serverOrder));
    final byId = {for (final spi in Stores.server.fetch()) spi.id: spi};
    return [
      for (final id in order)
        if (byId[id] case final spi? when spi.monitorHttp != null) spi,
    ];
  }

  MonitorSettingsController _ctrlOf(String id) =>
      _ctrls.putIfAbsent(id, MonitorSettingsController.new);

  @override
  Widget build(BuildContext context) {
    final servers = _servers;
    // Keeps pointing at something real: a server can lose its agent, or be
    // deleted, while this tab is alive behind another.
    if (_selectedId != null && !servers.any((s) => s.id == _selectedId)) {
      _selectedId = null;
    }
    _selectedId ??= servers.firstOrNull?.id;

    return SbPaneList(
      // Nothing to sit beside when no server has an agent, and the surface is
      // then the sentence explaining that.
      hasContent: servers.isNotEmpty,
      sideBuilder: (_) => _buildList(servers),
      builder: (_, split) => _buildSurface(servers, split),
    );
  }
}

// --- Widget build ---

extension on _MonitorSettingsTabPageState {
  Widget _buildList(List<Spi> servers) {
    return Scaffold(
      appBar: CustomAppBar(
        // No back button: this is the tab's own list, not something opened
        // into the pane, so the one `CustomAppBar` supplies would have nowhere
        // to go.
        leading: const SizedBox.shrink(),
        title: Text(l10n.monitorSettings),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        itemCount: servers.length,
        itemBuilder: (_, idx) {
          final spi = servers[idx];
          final selected = spi.id == _selectedId;
          return CardX(
            child: ListTile(
              selected: selected,
              leading: const Icon(Icons.dns_outlined),
              title: Text(spi.name),
              subtitle: Text(
                spi.monitorHttp?.addr ?? '',
                style: UIs.textGrey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _select(spi.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSurface(List<Spi> servers, bool split) {
    if (servers.isEmpty) {
      return Scaffold(
        appBar: CustomAppBar(
          leading: const SizedBox.shrink(),
          title: Text(l10n.monitorSettings),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 27),
            child: Text(
              l10n.monitorNoAgent,
              style: UIs.textGrey,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final spi = servers.firstWhereOrNull((s) => s.id == _selectedId);
    if (spi == null) return UIs.centerLoading;
    final monitor = spi.monitorHttp;
    if (monitor == null) return UIs.centerLoading;

    final ctrl = _ctrlOf(spi.id);
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) => Scaffold(
        appBar: _buildBar(spi, ctrl, split),
        // Keyed on the server: the view holds a session, a form and unsaved
        // edits, so choosing another agent has to build a new one rather than
        // hand the old one a different address.
        body: MonitorSettingsView(
          key: ValueKey(spi.id),
          monitor: monitor,
          controller: ctrl,
        ),
      ),
    );
  }

  /// With the list beside it, an ordinary bar. Without, the terminal tab's:
  /// the switcher on the left saying which of the set is on screen and opening
  /// the rest, and the actions on the right. The chevron is what makes "one of
  /// several" readable at all — a plain title says "this page".
  PreferredSizeWidget _buildBar(
    Spi spi,
    MonitorSettingsController ctrl,
    bool split,
  ) {
    final save = _buildSaveAction(ctrl);

    if (split) {
      return CustomAppBar(
        leading: const SizedBox.shrink(),
        title: TwoLineText(up: l10n.monitorSettings, down: spi.name),
        actions: [?save],
      );
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(SessionTabBar.height),
      child: SizedBox(
        height: SessionTabBar.height,
        child: Row(
          children: [
            Expanded(
              child: SessionSwitcherLabel(
                name: spi.name,
                icon: Icons.dns_outlined,
                onTap: _showServerSheet,
              ),
            ),
            ?save,
            const SizedBox(width: 7),
          ],
        ),
      ),
    );
  }

  Widget? _buildSaveAction(MonitorSettingsController ctrl) {
    if (!ctrl.ready) return null;
    if (ctrl.saving) {
      return const Padding(
        padding: EdgeInsets.all(13),
        child: SizedBox.square(
          dimension: 17,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Btn.icon(
      text: libL10n.save,
      icon: const Icon(Icons.save, size: 18),
      onTap: ctrl.save,
    );
  }
}

// --- Actions ---

extension on _MonitorSettingsTabPageState {
  /// Choosing another agent replaces the column, and the view in it holds the
  /// edits — so this is the tab's version of the page's `PopScope`, and the
  /// only thing standing between an unsaved form and a tap on the list.
  Future<void> _select(String id) async {
    if (id == _selectedId) return;
    final current = _selectedId;
    if (current != null && (_ctrls[current]?.dirty ?? false)) {
      final ok = await context.showRoundDialog<bool>(
        title: libL10n.attention,
        child: Text(libL10n.askContinue(libL10n.delete)),
        actions: Btnx.cancelRedOk,
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _selectedId = id);
  }

  /// The list, raised as a sheet, for the single column where it has nowhere
  /// else to be.
  Future<void> _showServerSheet() async {
    final servers = _servers;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final spi in servers)
              ListTile(
                selected: spi.id == _selectedId,
                leading: const Icon(Icons.dns_outlined),
                title: Text(spi.name),
                subtitle: Text(
                  spi.monitorHttp?.addr ?? '',
                  style: UIs.textGrey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => ctx.pop(spi.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _select(picked);
  }
}
