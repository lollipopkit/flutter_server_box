import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/src/rust/api/remote_desktop.dart' as ffi;
import 'package:server_box/view/page/remote_desktop/profiles.dart';
import 'package:server_box/view/page/remote_desktop/viewer.dart';
import 'package:server_box/view/widget/dist_icon.dart';
import 'package:server_box/view/widget/pane_settings.dart';

class RemoteDesktopTabPage extends ConsumerStatefulWidget {
  const RemoteDesktopTabPage({super.key});

  @override
  ConsumerState<RemoteDesktopTabPage> createState() =>
      _RemoteDesktopTabPageState();
}

class _RemoteDesktopTabPageState extends ConsumerState<RemoteDesktopTabPage> {
  String? _shownCertificate;
  String? _selectedServerId;
  final _search = InlineSearchController();
  late final ValueNotifier<_RemoteDesktopSort> _sort = ValueNotifier(
    _RemoteDesktopSort.stored,
  );

  /// Read once and kept, because [dispose] cannot read it.
  ///
  /// `ref` resolves through this element's `BuildContext`, and by the time the
  /// element is unmounted that is gone — `ref.read` there throws
  /// `Using "ref" when a widget is about to or has been unmounted is unsafe`,
  /// which surfaced as an exception every time this tab left the tree. The
  /// provider is `keepAlive`, so the notifier outlives this page whichever way
  /// it is reached.
  late final RemoteDesktopSessions _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = ref.read(remoteDesktopSessionsProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sessions.setSurfaceVisible(
        ref.read(currentHomeTabProvider) == AppTab.remoteDesktop &&
            _selectedServerId == null,
      );
    });
  }

  @override
  void dispose() {
    _sessions.setSurfaceVisible(false);
    _search.dispose();
    _sort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(remoteDesktopSessionsProvider);
    final serverState = ref.watch(serversProvider);
    final servers = [
      for (final id in serverState.serverOrder)
        if (serverState.servers[id] case final spi?
            when spi.sshOn != null || spi.monitorOn != null)
          spi,
    ];
    ref.listen(currentHomeTabProvider, (_, tab) {
      ref
          .read(remoteDesktopSessionsProvider.notifier)
          .setSurfaceVisible(
            tab == AppTab.remoteDesktop && _selectedServerId == null,
          );
    });
    ref.listen(
      remoteDesktopSessionsProvider.select(
        (value) => value.active?.certificate,
      ),
      (_, certificate) {
        if (certificate == null) {
          _shownCertificate = null;
        } else if (_shownCertificate != certificate.sha256) {
          _shownCertificate = certificate.sha256;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_confirmCertificate(certificate));
          });
        }
      },
    );
    final selectedServer = servers
        .where((spi) => spi.id == _selectedServerId)
        .firstOrNull;
    if (_selectedServerId != null && selectedServer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedServerId != null) _selectServer(null);
      });
    }
    return SbPaneList(
      sideBuilder: (_) => _sessionList(state, servers),
      builder: (_, split) => _surface(state, servers, selectedServer, split),
    );
  }

  void _selectServer(String? id) {
    setState(() => _selectedServerId = id);
    _sessions.setSurfaceVisible(
      id == null && ref.read(currentHomeTabProvider) == AppTab.remoteDesktop,
    );
  }

  void _showProfiles(Spi spi) => _selectServer(spi.id);

  void _showViewer(String id) {
    ref.read(remoteDesktopSessionsProvider.notifier).select(id);
    _selectServer(null);
  }

  List<Spi> _visibleServers(List<Spi> servers) {
    final needle = _search.needle;
    return [
      for (final spi in _sort.value.order(servers))
        if (needle.isEmpty ||
            spi.name.toLowerCase().contains(needle) ||
            spi.displayAddr.toLowerCase().contains(needle))
          spi,
    ];
  }

  Widget get _sortButton => Btn.icon(
    text: libL10n.sort,
    icon: Icon(_sort.value.icon, size: 18),
    onTap: _showSortMenu,
  );

  Widget get _searchButton => Btn.icon(
    text: libL10n.search,
    icon: const Icon(Icons.search, size: 18),
    onTap: _search.start,
  );

  Future<void> _showSortMenu() => showRowsSheet<void>(
    context,
    rows: (sheetContext) => [
      for (final order in _RemoteDesktopSort.values)
        SheetChoiceTile(
          icon: order.icon,
          title: order.label,
          selected: order == _sort.value,
          onTap: () {
            Stores.setting.remoteDesktopSort.put(order.index);
            _sort.value = order;
            Navigator.of(sheetContext).pop();
          },
        ),
    ],
  );

  Widget _surface(
    RemoteDesktopSessionsState state,
    List<Spi> servers,
    Spi? selectedServer,
    bool split,
  ) {
    if (selectedServer != null) {
      return RemoteDesktopProfilesPage(
        key: ValueKey(selectedServer.id),
        args: SpiRequiredArgs(selectedServer),
        onClose: () => _selectServer(null),
        onSessionOpened: () => _selectServer(null),
      );
    }

    final active = state.active;
    if (active == null) return split ? _empty() : _serverPicker(servers);
    if (split) return RemoteDesktopViewer(sessionId: active.id);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(SessionTabBar.height),
        child: SizedBox(
          height: SessionTabBar.height,
          child: Row(
            children: [
              Expanded(
                child: SessionSwitcherLabel(
                  name: active.profile.name,
                  position:
                      state.ordered.indexWhere((e) => e.id == active.id) + 1,
                  total: state.sessions.length,
                  icon: Icons.desktop_windows_outlined,
                  onTap: () => _showSessions(state),
                ),
              ),
              IconButton(
                tooltip: libL10n.servers,
                icon: const Icon(Icons.dns_outlined),
                onPressed: servers.isEmpty ? null : () => _showServers(servers),
              ),
              IconButton(
                tooltip: libL10n.close,
                icon: const Icon(Icons.close),
                onPressed: () => ref
                    .read(remoteDesktopSessionsProvider.notifier)
                    .close(active.id),
              ),
              const SizedBox(width: 5),
            ],
          ),
        ),
      ),
      body: RemoteDesktopViewer(sessionId: active.id),
    );
  }

  Widget _serverPicker(List<Spi> servers) => ListenableBuilder(
    listenable: Listenable.merge([_search, _sort]),
    builder: (context, _) {
      final found = _visibleServers(servers);
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(SessionTabBar.height),
          child: SizedBox(
            height: SessionTabBar.height,
            child: InlineSearchBar(
              controller: _search,
              child: CustomAppBar(
                title: Text(context.l10n.remoteDesktop),
                actions: [_sortButton, _searchButton],
              ),
            ),
          ),
        ),
        body: found.isEmpty
            ? _search.needle.isEmpty
                  ? _empty()
                  : EmptyPane(icon: Icons.search_off, label: _search.needle)
            : ListView(
                children: [
                  SideBarSection(libL10n.servers),
                  for (final spi in found)
                    ListTile(
                      key: ValueKey(spi.id),
                      leading: distIcon(spi.id, size: 24),
                      title: Text(spi.name),
                      subtitle: Text(spi.displayAddr),
                      onTap: () => _showProfiles(spi),
                    ),
                ],
              ),
      );
    },
  );

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.desktop_windows_outlined, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No remote desktop sessions', style: UIs.textGrey),
          const SizedBox(height: 8),
          const Text(
            'Select a server to start an RDP or VNC session.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _sessionList(RemoteDesktopSessionsState state, List<Spi> servers) =>
      Material(
        type: MaterialType.transparency,
        child: ListenableBuilder(
          listenable: Listenable.merge([_search, _sort]),
          builder: (_, _) => ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              SideBarActions(
                actions: [_sortButton, _searchButton],
                search: _search,
              ),
              if (state.sessions.isNotEmpty) ...[
                SideBarSection(libL10n.running),
                for (final session in state.ordered)
                  _sessionTile(
                    session,
                    _selectedServerId == null ? state.activeId : null,
                  ),
              ],
              SideBarSection(libL10n.servers),
              for (final spi in _visibleServers(servers))
                SideBarTile(
                  key: ValueKey(spi.id),
                  leading: distIcon(spi.id, size: 22),
                  title: spi.name,
                  selected: _selectedServerId == spi.id,
                  onTap: () => _showProfiles(spi),
                ),
            ],
          ),
        ),
      );

  Widget _sessionTile(RemoteDesktopSessionView session, String? activeId) {
    final active = activeId == session.id;
    final color = switch (session.connectionState) {
      ffi.RemoteDesktopConnectionState.connected => Colors.green,
      ffi.RemoteDesktopConnectionState.connecting ||
      ffi.RemoteDesktopConnectionState.reconnecting => Colors.orange,
      ffi.RemoteDesktopConnectionState.disconnected => Colors.red,
    };
    return ListTile(
      selected: active,
      leading: Semantics(
        label: _connectionStateLabel(session.connectionState),
        excludeSemantics: true,
        child: Tooltip(
          message: _connectionStateLabel(session.connectionState),
          excludeFromSemantics: true,
          child: Icon(Icons.circle, size: 10, color: color),
        ),
      ),
      title: Text(
        session.profile.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${session.profile.protocol.name.toUpperCase()} · '
        '${_connectionStateLabel(session.connectionState)}',
      ),
      trailing: IconButton(
        tooltip: libL10n.close,
        icon: const Icon(Icons.close, size: 18),
        onPressed: () =>
            ref.read(remoteDesktopSessionsProvider.notifier).close(session.id),
      ),
      onTap: () => _showViewer(session.id),
    );
  }

  String _connectionStateLabel(ffi.RemoteDesktopConnectionState state) =>
      switch (state) {
        ffi.RemoteDesktopConnectionState.connected => libL10n.ready,
        ffi.RemoteDesktopConnectionState.connecting =>
          context.l10n.pveLoadingConnect,
        ffi.RemoteDesktopConnectionState.reconnecting => libL10n.reconnecting,
        ffi.RemoteDesktopConnectionState.disconnected => libL10n.disconnected,
      };

  Future<void> _showServers(List<Spi> servers) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([_search, _sort]),
        builder: (_, _) => ListView(
          shrinkWrap: true,
          children: [
            SideBarActions(
              actions: [_sortButton, _searchButton],
              search: _search,
            ),
            SideBarSection(libL10n.servers),
            for (final spi in _visibleServers(servers))
              ListTile(
                leading: distIcon(spi.id, size: 24),
                title: Text(spi.name),
                subtitle: Text(spi.displayAddr),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showProfiles(spi);
                },
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> _showSessions(RemoteDesktopSessionsState state) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final session in state.ordered)
              ListTile(
                selected: session.id == state.activeId,
                leading: Semantics(
                  label: _connectionStateLabel(session.connectionState),
                  excludeSemantics: true,
                  child: Tooltip(
                    message: _connectionStateLabel(session.connectionState),
                    child: const Icon(Icons.desktop_windows_outlined),
                  ),
                ),
                title: Text(session.profile.name),
                subtitle: Text(
                  '${session.profile.protocol.name.toUpperCase()} · '
                  '${_connectionStateLabel(session.connectionState)}',
                ),
                trailing: IconButton(
                  tooltip: libL10n.close,
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    ref
                        .read(remoteDesktopSessionsProvider.notifier)
                        .close(session.id);
                  },
                ),
                onTap: () {
                  _showViewer(session.id);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCertificate(
    RemoteDesktopCertificatePrompt certificate,
  ) async {
    final state = ref.read(remoteDesktopSessionsProvider);
    final session = state.active;
    if (session == null || session.certificate?.sha256 != certificate.sha256) {
      return;
    }
    final replacing = certificate.replacesExisting;
    final accepted = await context.showRoundDialog<bool>(
      title: replacing
          ? 'Remote desktop certificate changed'
          : 'Trust certificate?',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              replacing
                  ? 'The certificate fingerprint no longer matches the saved value. Verify the new fingerprint before replacing trust.'
                  : 'The system could not verify this certificate. Verify its SHA-256 fingerprint before continuing.',
            ),
            const SizedBox(height: 12),
            SelectableText('SHA-256\n${certificate.sha256}'),
            if (certificate.previousSha256 case final previous?) ...[
              const SizedBox(height: 8),
              SelectableText('Previously trusted\n$previous'),
            ],
            const SizedBox(height: 8),
            SelectableText('Subject: ${certificate.subject}'),
            SelectableText('Issuer: ${certificate.issuer}'),
            SelectableText(
              'Valid: ${certificate.validFrom} – ${certificate.validTo}',
            ),
          ],
        ),
      ),
      actions: [
        Btn.cancel(),
        TextButton(
          onPressed: () => context.popDialog(true),
          child: Text(replacing ? 'Replace trust' : 'Trust and reconnect'),
        ),
      ],
    );
    if (!mounted) return;
    if (accepted == true) {
      await ref
          .read(remoteDesktopSessionsProvider.notifier)
          .trustCertificate(session.id);
    } else {
      await ref.read(remoteDesktopSessionsProvider.notifier).close(session.id);
    }
  }
}

enum _RemoteDesktopSort {
  sequence,
  nameAsc,
  nameDesc;

  static _RemoteDesktopSort get stored =>
      values.elementAtOrNull(Stores.setting.remoteDesktopSort.fetch()) ??
      sequence;

  IconData get icon => switch (this) {
    sequence => Icons.format_list_numbered,
    nameAsc => Icons.sort_by_alpha,
    nameDesc => Icons.sort,
  };

  String get label => switch (this) {
    sequence => libL10n.sequence,
    nameAsc => '${libL10n.sortByName} (A-Z)',
    nameDesc => '${libL10n.sortByName} (Z-A)',
  };

  List<Spi> order(List<Spi> servers) {
    if (this == sequence) return servers;
    final rank = {for (var i = 0; i < servers.length; i++) servers[i].id: i};
    final sorted = servers.toList();
    sorted.sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) return this == nameAsc ? byName : -byName;
      return rank[a.id]!.compareTo(rank[b.id]!);
    });
    return sorted;
  }
}
