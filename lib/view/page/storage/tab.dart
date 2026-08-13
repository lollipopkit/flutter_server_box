import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/storage/local.dart';
import 'package:server_box/view/page/storage/sftp.dart';
import 'package:server_box/view/widget/pane_settings.dart';

/// Every open file browser, one tab each, plus a picker at the head of the
/// strip.
///
/// Browsing used to be a page pushed over whatever was on screen, so opening
/// two servers meant losing the first, and going back to compare meant
/// reconnecting. Sessions here behave like the terminal's: they stay open, and
/// the strip says what is open.
class FileTabPage extends ConsumerStatefulWidget {
  const FileTabPage({super.key});

  @override
  ConsumerState<FileTabPage> createState() => _FileTabPageState();
}

/// One thing being browsed.
///
/// This device and a server differ in what it takes to reach them and in
/// nothing else the tab cares about, which is why they are two shapes of one
/// session rather than two kinds of tab.
sealed class _FileSession {
  _FileSession({this.initialPath});

  /// Where the page opens. Separate from [currentPath] because the page reads
  /// it once, when it is created; changing it later would do nothing and
  /// pretending otherwise invites someone to try.
  final String? initialPath;

  /// Where the browser is now, reported as it moves. Null until the first
  /// listing lands.
  String? currentPath;

  /// The page's toolbar, which it hands over rather than drawing, so the tab
  /// strip is the only bar on screen.
  ///
  /// One per session: every page is built, including the ones off screen, and
  /// a shared sink would have them overwriting each other.
  final actions = ValueNotifier<List<Widget>>(const []);

  String? get path => currentPath ?? initialPath;

  Map<String, dynamic> toRestorable();

  void dispose() => actions.dispose();
}

/// This device's own files.
final class _LocalSession extends _FileSession {
  _LocalSession({super.initialPath});

  /// No `serverId`, which is how [_FileTabPageState._restore] tells the two
  /// apart. Records written before there were local tabs always carry one.
  @override
  Map<String, dynamic> toRestorable() => {'path': path};
}

/// A server's files, over SFTP.
final class _RemoteSession extends _FileSession {
  _RemoteSession({required this.spi, super.initialPath});

  final Spi spi;

  @override
  Map<String, dynamic> toRestorable() => {'serverId': spi.id, 'path': path};
}

class _FileTabPageState extends ConsumerState<FileTabPage>
    with AutomaticKeepAliveClientMixin, RestorationMixin {
  late final _sessions = SessionTabsController<_FileSession>(
    leadingName: libL10n.open,
  );

  final _restorableSessions = RestorableString('');

  late final _picker = _PickPage(
    onLocal: _openLocal,
    onServer: _openRemote,
  );

  @override
  String get restorationId => 'file_tab_page';

  @override
  bool get wantKeepAlive => true;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restorableSessions, 'sessions');
    if (!initialRestore || _restorableSessions.value.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  @override
  void initState() {
    super.initState();
    // Anything queued before this tab existed — tabs are built when first
    // visited, so a request from the server list arrives before there is
    // anything here to receive it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainRequests());
  }

  @override
  void dispose() {
    _restorableSessions.dispose();
    // The controller disposes what it created — focus, visibility — but the
    // session data is ours.
    for (final tab in _sessions.tabs) {
      tab.data.dispose();
    }
    _sessions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(sftpRequestsProvider, (_, _) => _drainRequests());

    return ListenBuilder(
      listenable: _sessions,
      builder: () => SbPaneList(
        // Nothing open yet means nothing for a column to sit beside, so the
        // picker keeps the whole width until the first browser is opened.
        hasContent: _sessions.tabs.isNotEmpty,
        sideBuilder: (_) => _SideBar(
          sessions: _sessions,
          onLocal: _openLocal,
          onServer: _openRemote,
          onSelect: _sessions.select,
          onClose: _close,
        ),
        builder: (_, split) => _buildBrowsers(split),
      ),
    );
  }

  Widget _buildBrowsers(bool split) {
    // Selected here rather than left where it was: page 0 is the picker's,
    // and once the rail is drawing that list nothing in it can reach page 0
    // again, so a layout that turns split while the picker was current left an
    // empty surface beside a rail with no way back. Deferred, because this
    // runs during a build.
    if (split && _sessions.index == 0 && _sessions.tabs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sessions.index == 0) _sessions.select(1);
      });
    }

    return Scaffold(
      // With a rail beside it there is nothing left for a strip to do: the
      // rail switches sessions and starts them, so all the bar has to say is
      // which one is on screen.
      appBar: split ? _sessionBar : _tabBar,
      body: SessionTabsView<_FileSession>(
        controller: _sessions,
        // Page 0 is still the picker's, and while it has a column of its own
        // nothing can reach that page — building it here would be drawing the
        // same list twice.
        leading: split ? const SizedBox.shrink() : _picker,
        builder: (_, tab) {
          final session = tab.data;
          void onPathChanged(String path) {
            if (session.currentPath == path) return;
            session.currentPath = path;
            _save();
          }

          return switch (session) {
            _LocalSession() => LocalFilePage(
              key: ValueKey(tab.id),
              args: LocalFilePageArgs(
                initDir: session.initialPath,
                actionsSink: session.actions,
                onPathChanged: onPathChanged,
              ),
            ),
            _RemoteSession(:final spi) => SftpPage(
              key: ValueKey(tab.id),
              args: SftpPageArgs(
                spi: spi,
                initPath: session.initialPath,
                actionsSink: session.actions,
                onPathChanged: onPathChanged,
              ),
            ),
          };
        },
      ),
    );
  }

  PreferredSizeWidget get _tabBar => PreferredSizeListenBuilder(
    listenable: _sessions,
    builder: () => SessionTabBar(
      names: _sessions.names,
      index: _sessions.index,
      leadingIcon: MingCute.folder_fill,
      onTap: _sessions.select,
      onClose: _close,
      // One widget that follows whichever session is showing, rather than a
      // list the bar would have to rebuild itself to keep current.
      sessionActions: [_SessionActions(sessions: _sessions)],
      leadingActions: const [],
    ),
  );

  PreferredSizeWidget get _sessionBar => PreferredSizeListenBuilder(
    listenable: _sessions,
    builder: () => CustomAppBar(
      title: Text(_sessions.current?.name ?? libL10n.file),
      actions: [_SessionActions(sessions: _sessions)],
    ),
  );
}

extension _Sessions on _FileTabPageState {
  void _openLocal({String? initialPath, bool select = true}) {
    _add(
      preferred: libL10n.device,
      session: _LocalSession(initialPath: initialPath),
      select: select,
    );
  }

  void _openRemote(Spi spi, {String? initialPath, bool select = true}) {
    _add(
      preferred: spi.name,
      session: _RemoteSession(spi: spi, initialPath: initialPath),
      select: select,
    );
  }

  /// [select] is off while restoring: selecting each as it arrives would
  /// animate through every session to land on the last.
  void _add({
    required String preferred,
    required _FileSession session,
    required bool select,
  }) {
    final tab = _sessions.add(preferred: preferred, build: (_, _, _) => session);
    if (!select) return;
    _save();
    _sessions.select(_sessions.names.indexOf(tab.name));
  }

  void _drainRequests() {
    final pending = ref.read(sftpRequestsProvider);
    if (pending.isEmpty) return;
    ref.read(sftpRequestsProvider.notifier).clear();
    for (final spi in pending) {
      _openRemote(spi);
    }
  }

  Future<void> _close(int index) async {
    // Resolved now, while the position still means what the bar drew.
    final tab = _sessions.tabs.elementAtOrNull(index - 1);
    if (tab == null) return;

    final confirm = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text('${libL10n.close} ${tab.name} ?'),
      actions: Btnx.okReds,
    );
    if (confirm != true) return;
    final session = tab.data;
    _sessions.remove(tab.id);
    // After the controller has let go of it, and after the frame in which the
    // page view still has the page that writes to it.
    WidgetsBinding.instance.addPostFrameCallback((_) => session.dispose());
    if (mounted) _save();
  }

  void _save() {
    _restorableSessions.value = jsonEncode([
      for (final tab in _sessions.tabs) tab.data.toRestorable(),
    ]);
  }

  /// Reopens what was being browsed, where it was being browsed.
  ///
  /// Unlike a terminal there is nothing still alive on the far side — a remote
  /// tab reconnects. What this restores is the intent: which places, and where
  /// in them.
  void _restore() {
    final List<dynamic> entries;
    try {
      entries = jsonDecode(_restorableSessions.value) as List;
    } catch (e, st) {
      Loggers.app.warning('Unreadable file tab state', e, st);
      return;
    }

    // Read once, not once per tab.
    final servers = {for (final spi in Stores.server.fetch()) spi.id: spi};

    var restored = 0;
    for (final entry in entries) {
      if (entry is! Map) continue;
      final path = entry['path'] as String?;
      final serverId = entry['serverId'];
      if (serverId == null) {
        _openLocal(initialPath: path, select: false);
      } else {
        final spi = servers[serverId];
        // A server can be deleted, or switched to a connection that cannot
        // carry SFTP, while a tab on it is still remembered.
        if (spi == null || !_canBrowse(spi)) continue;
        _openRemote(spi, initialPath: path, select: false);
      }
      restored++;
    }

    if (restored == 0) return;
    _save();
    _sessions.select(1);
  }
}

/// Whether a file browser can be opened on [spi] at all.
///
/// SFTP moves file contents over a channel, and a server reached only through
/// its monitor agent has nothing to carry one — listing it here would offer a
/// browser that can never open. Does not depend on what the agent grants, so
/// it needs no probe: no grant produces a byte stream today.
bool _canBrowse(Spi spi) =>
    ServerCapabilities.of(ServerConnectCredential.fromSpi(spi)).byteStream;

/// The first tab: pick somewhere to browse.
///
/// This device is first because it is always reachable, and because it is
/// where downloads land.
class _PickPage extends ConsumerWidget {
  const _PickPage({required this.onLocal, required this.onServer});

  final VoidCallback onLocal;
  final void Function(Spi spi) onServer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serversProvider);
    return MasonryList(
      columnWidth: _kColumnWidth,
      children: [
        _PickTile(
          icon: Icons.smartphone,
          title: libL10n.device,
          subtitle: Paths.file,
          onTap: onLocal,
        ),
        for (final id in state.serverOrder)
          if (state.servers[id] case final spi? when _canBrowse(spi))
            _PickTile(
              key: ValueKey(id),
              icon: Icons.dns,
              title: spi.name,
              subtitle: spi.displayAddr,
              onTap: () => onServer(spi),
            ),
      ],
    );
  }
}

/// Wide enough for a name and the chevron beside it, and narrow enough that a
/// desktop window gets more than one column.
const _kColumnWidth = 300.0;

/// The same two things as [_PickPage], in a column too narrow for cards: the
/// browsers that are open, and the places another could be opened on.
class _SideBar extends ConsumerWidget {
  const _SideBar({
    required this.sessions,
    required this.onLocal,
    required this.onServer,
    required this.onSelect,
    required this.onClose,
  });

  final SessionTabsController<_FileSession> sessions;
  final VoidCallback onLocal;
  final void Function(Spi spi) onServer;
  final void Function(int index) onSelect;
  final void Function(int index) onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serversProvider);

    return ListenBuilder(
      listenable: sessions,
      builder: () => SessionSideBar(
        names: sessions.names,
        index: sessions.index,
        onTap: onSelect,
        onClose: onClose,
        targets: [
          // Above the heading rather than under one of its own: it is the
          // place that is always reachable, not one entry in a list of many.
          const SizedBox(height: 8),
          SideBarTile(title: libL10n.device, onTap: onLocal),
          SideBarSection(libL10n.servers),
          for (final id in state.serverOrder)
            if (state.servers[id] case final spi? when _canBrowse(spi))
              SideBarTile(
                key: ValueKey(id),
                title: spi.name,
                onTap: () => onServer(spi),
              ),
        ],
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CardX(
      child: ListTile(
        leading: Icon(icon),
        title: Text(
          title,
          style: UIs.text18,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: UIs.text12Grey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// The toolbar of whichever session is showing.
///
/// Rebuilt from that session's own notifier, so the strip does not have to
/// listen to every open session to keep one row of buttons current.
class _SessionActions extends StatelessWidget {
  const _SessionActions({required this.sessions});

  final SessionTabsController<_FileSession> sessions;

  @override
  Widget build(BuildContext context) {
    final current = sessions.current;
    if (current == null) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: current.data.actions,
      builder: (_, actions, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions) ...[action, const SizedBox(width: 7)],
        ],
      ),
    );
  }
}
