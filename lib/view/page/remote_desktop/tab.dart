import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/inset.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/tag_group.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/src/rust/api/remote_desktop.dart' as ffi;
import 'package:server_box/view/page/remote_desktop/pane_slide.dart';
import 'package:server_box/view/page/remote_desktop/profiles.dart';
import 'package:server_box/view/page/remote_desktop/viewer.dart';
import 'package:server_box/view/widget/dist_icon.dart';
import 'package:server_box/view/widget/pane_settings.dart';

part 'sort.dart';

class RemoteDesktopTabPage extends ConsumerStatefulWidget {
  const RemoteDesktopTabPage({super.key});

  @override
  ConsumerState<RemoteDesktopTabPage> createState() =>
      _RemoteDesktopTabPageState();
}

class _RemoteDesktopTabPageState extends ConsumerState<RemoteDesktopTabPage> {
  String? _shownCertificate;
  String? _selectedServerId;
  bool _showPicker = false;
  String? _testingSessionId;
  late final _sortBySetting = Stores.setting.remoteDesktopSortBy.listenable();
  late final _sortAscSetting = Stores.setting.remoteDesktopSortAsc.listenable();

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
    _sortBySetting.addListener(_onListViewChanged);
    _sortAscSetting.addListener(_onListViewChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sessions.setSurfaceVisible(
        ref.read(currentHomeTabProvider) == AppTab.remoteDesktop,
      );
    });
  }

  @override
  void dispose() {
    _sortBySetting.removeListener(_onListViewChanged);
    _sortAscSetting.removeListener(_onListViewChanged);
    _sessions.setSurfaceVisible(false);
    super.dispose();
  }

  void _onListViewChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(remoteDesktopSessionsProvider);
    final servers = ref.watch(serversProvider);
    final order = _SortOrder.stored.apply(servers.serverOrder, servers.servers);
    final groups = groupByTag(order, (id) => servers.servers[id]?.tags);
    ref.listen(currentHomeTabProvider, (_, tab) {
      _sessions.setSurfaceVisible(
        tab == AppTab.remoteDesktop &&
            _selectedServerId == null &&
            !_showPicker,
      );
    });
    ref.listen(remoteDesktopSessionsProvider, (previous, next) {
      final activeId = next.activeId;
      if (activeId == null ||
          activeId == previous?.activeId ||
          (previous?.sessions.containsKey(activeId) ?? false) ||
          activeId == _testingSessionId) {
        return;
      }
      if (_selectedServerId == null && !_showPicker) return;
      setState(() {
        _selectedServerId = null;
        _showPicker = false;
      });
      _sessions.setSurfaceVisible(
        ref.read(currentHomeTabProvider) == AppTab.remoteDesktop,
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
    return SbPaneList(
      sideBuilder: (_) => _buildRail(state, servers, groups),
      builder: (_, split) {
        final surface = _buildSurface(state, servers, groups, split);
        return RemoteDesktopPaneSlide(
          child: NestedNavigator(
            rootId: _surfaceId(state, split),
            rootBuilder: (_) => surface,
          ),
        );
      },
    );
  }

  Object _surfaceId(RemoteDesktopSessionsState state, bool split) {
    if (_selectedServerId case final id?) return ('server', id);
    if (!split && (_showPicker || state.active == null)) return #picker;
    if (state.activeId case final id?) return ('session', id);
    return #empty;
  }

  Widget _buildRail(
    RemoteDesktopSessionsState state,
    ServersState servers,
    List<TagGroup<String>> groups,
  ) => Scaffold(body: _rail(state, servers, groups));

  Widget _buildSurface(
    RemoteDesktopSessionsState state,
    ServersState servers,
    List<TagGroup<String>> groups,
    bool split,
  ) {
    if (_selectedServerId case final serverId?) {
      if (servers.servers[serverId] case final spi?) {
        return RemoteDesktopProfilesPage(
          key: ValueKey(serverId),
          args: SpiRequiredArgs(spi),
          onBack: _clearSelection,
          onSessionOpened: _showActiveSession,
          onTestSessionOpening: (id) => _testingSessionId = id,
        );
      }
    }
    if (!split && (_showPicker || state.active == null)) {
      return _buildPicker(state, servers, groups);
    }
    final active = state.active;
    if (active == null) return _empty();
    // One bar, the viewer's own: in a single column its name opens the other
    // sessions, as the terminal tab's does.
    return RemoteDesktopViewer(
      sessionId: active.id,
      switcher: split
          ? null
          : (
              position:
                  state.ordered.indexWhere((e) => e.id == active.id) + 1,
              total: state.sessions.length,
              onTap: () => _showSessions(state),
            ),
    );
  }

  /// The first page of a single column: the servers, as cards, under the
  /// same bar the terminal and file tabs put over their pickers.
  ///
  /// Not the rail. The rail is an index beside a surface; on its own it is a
  /// column of small rows with nothing on the other side of them.
  Widget _buildPicker(
    RemoteDesktopSessionsState state,
    ServersState servers,
    List<TagGroup<String>> groups,
  ) => Scaffold(
    appBar: _pickerBar(state),
    body: servers.servers.isEmpty
        ? const EmptyPane(icon: Icons.dns_outlined)
        : ListView(
            padding: context.padBottom(UIs.roundRectCardPadding),
            children: [
              for (final group in groups) ...[
                if (group.label case final label?) CenterGreyTitle(label),
                for (final id in group.items)
                  if (servers.servers[id] case final spi?)
                    CardTile(
                      key: ValueKey('server:$id'),
                      // No fallback icon: with marks off every row would
                      // carry the same one, which says nothing.
                      leading: distIcon(spi.id, size: 24),
                      title: spi.name,
                      subtitle: spi.displayAddr,
                      onTap: () => _selectServer(spi),
                    ),
              ],
            ],
          ),
  );

  /// The terminal tab's strip: the picker as its leading entry, the running
  /// sessions behind the switcher.
  PreferredSizeWidget _pickerBar(RemoteDesktopSessionsState state) {
    final sessions = state.ordered;
    return SessionTabBar(
      names: [libL10n.add, for (final session in sessions) session.profile.name],
      index: 0,
      onTap: (index) {
        if (index > 0) _selectSession(sessions[index - 1].id);
      },
      onClose: (index) {
        if (index > 0) _sessions.close(sessions[index - 1].id);
      },
      detailOf: (index) => _sessionDetail(sessions[index - 1]),
      sessionActions: const [],
      leadingActions: [_sortBtn],
    );
  }

  Widget get _sortBtn => Btn.icon(
    text: libL10n.sort,
    icon: Icon(_SortOrder.stored.icon, size: 18),
    onTap: _showSortSheet,
  );

  String _sessionDetail(RemoteDesktopSessionView session) =>
      '${session.profile.protocol.name.toUpperCase()} · '
      '${_connectionStateLabel(session.connectionState)}';

  Widget _empty() => const EmptyPane(icon: Icons.desktop_windows_outlined);

  Widget _rail(
    RemoteDesktopSessionsState state,
    ServersState servers,
    List<TagGroup<String>> groups,
  ) => ListView(
    padding: const EdgeInsets.only(top: 4, bottom: 77),
    children: [
      SideBarActions(actions: [_sortBtn]),
      if (state.ordered.isNotEmpty) SideBarSection(libL10n.running),
      for (final session in state.ordered)
        SideBarTile(
          key: ValueKey(session.id),
          title: session.profile.name,
          icon: Icons.desktop_windows_outlined,
          selected:
              _selectedServerId == null &&
              !_showPicker &&
              state.activeId == session.id,
          live:
              session.connectionState ==
              ffi.RemoteDesktopConnectionState.connected,
          onTap: () => _selectSession(session.id),
          onMenu: (at) => _showSessionMenu(session, at),
        ),
      for (final group in groups) ...[
        if (group.label case final label?) SideBarSection(label),
        for (final id in group.items)
          if (servers.servers[id] case final spi?)
            SideBarTile(
              key: ValueKey('server:$id'),
              leading: distIcon(spi.id, size: 22),
              title: spi.name,
              selected: _selectedServerId == id,
              onTap: () => _selectServer(spi),
            ),
      ],
    ],
  );

  Future<void> _showSortSheet() async {
    await showRowsSheet<void>(
      context,
      rows: (sheetContext) => [
        for (final order in _SortOrder.all)
          SheetChoiceTile(
            icon: order.icon,
            title: order.label,
            selected: order.isCurrent,
            onTap: () {
              order.save();
              Navigator.of(sheetContext).pop();
            },
          ),
      ],
    );
  }

  void _selectServer(Spi spi) {
    setState(() {
      _selectedServerId = spi.id;
      _showPicker = false;
    });
    _sessions.setSurfaceVisible(false);
  }

  void _selectSession(String id) {
    _sessions.select(id);
    _showActiveSession();
  }

  void _showActiveSession() {
    setState(() {
      _selectedServerId = null;
      _showPicker = false;
    });
    _sessions.setSurfaceVisible(
      ref.read(currentHomeTabProvider) == AppTab.remoteDesktop,
    );
  }

  void _openPicker() {
    setState(() {
      _selectedServerId = null;
      _showPicker = true;
    });
    _sessions.setSurfaceVisible(false);
  }

  void _clearSelection() {
    setState(() => _selectedServerId = null);
    _sessions.setSurfaceVisible(
      ref.read(currentHomeTabProvider) == AppTab.remoteDesktop,
    );
  }

  void _showSessionMenu(RemoteDesktopSessionView session, Offset? at) {
    showContextMenu(
      context,
      [
        ContextMenuAction(
          text: libL10n.close,
          icon: Icons.close,
          destructive: true,
          onTap: () => ref
              .read(remoteDesktopSessionsProvider.notifier)
              .close(session.id),
        ),
      ],
      title: session.profile.name,
      at: at,
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
                subtitle: Text(_sessionDetail(session)),
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
                  ref
                      .read(remoteDesktopSessionsProvider.notifier)
                      .select(session.id);
                  Navigator.of(sheetContext).pop();
                },
              ),
            const Divider(height: 17, indent: 17, endIndent: 17),
            // Last, as in the terminal's sheet: back to the picker, under the
            // name and icon its entry in the strip has.
            ListTile(
              leading: const Icon(MingCute.add_circle_fill),
              title: Text(libL10n.add),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openPicker();
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
