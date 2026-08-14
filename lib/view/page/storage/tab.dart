import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/storage/local.dart';
import 'package:server_box/view/page/storage/send_to.dart';
import 'package:server_box/view/page/storage/server_file.dart';
import 'package:server_box/view/page/storage/sftp.dart';
import 'package:server_box/view/widget/empty_pane.dart';
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
sealed class FileSession {
  FileSession({this.initialPath});

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

  /// Written with an explicit `kind`, because "local is the one with no
  /// serverId" was a rule the reader had to know and the writer never stated.
  Map<String, dynamic> toRestorable();

  void dispose() => actions.dispose();
}

/// This device's own files.
final class LocalFileSession extends FileSession {
  LocalFileSession({super.initialPath});

  @override
  Map<String, dynamic> toRestorable() => {'kind': _kindLocal, 'path': path};
}

/// A server's files, however they are reached.
///
/// Not `SftpSession`: which transport carries the bytes is resolved by
/// capability when the page opens, and a server that gains sshd later changes
/// backend without changing what kind of tab it is.
final class ServerFileSession extends FileSession {
  ServerFileSession({required this.spi, super.initialPath});

  final Spi spi;

  @override
  Map<String, dynamic> toRestorable() => {
    'kind': _kindServer,
    'serverId': spi.id,
    'path': path,
  };
}

const _kindLocal = 'local';
const _kindServer = 'server';

class _FileTabPageState extends ConsumerState<FileTabPage>
    with AutomaticKeepAliveClientMixin, RestorationMixin {
  late final _sessions = SessionTabsController<FileSession>(
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

  /// Whether there is saved state on its way back, known before the first
  /// frame ends and so before anything decides this tab is empty.
  bool _hasSavedSessions = false;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restorableSessions, 'sessions');
    if (!initialRestore || _restorableSessions.value.isEmpty) return;
    _hasSavedSessions = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  /// Whether this page has already chosen what to open with. Once, on the way
  /// to the first frame; an empty tab after that is one the user emptied.
  bool _chosenInitial = false;

  @override
  void initState() {
    super.initState();
    // Anything queued before this tab existed — tabs are built when first
    // visited, so a request from the server list arrives before there is
    // anything here to receive it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _drainRequests();
    });
  }

  @override
  void didChangeDependencies() {
    // First, because this is what runs [restoreState].
    super.didChangeDependencies();
    if (_chosenInitial) return;
    _chosenInitial = true;

    // What was saved comes back, and what was asked for while this tab did not
    // exist is about to be drained. Either way this page is not empty and has
    // nothing to default to.
    if (_hasSavedSessions) return;
    if (ref.read(sftpRequestsProvider).isNotEmpty) return;

    // Open on this device. Answering "which files" with a picker made the
    // common case — reach this device's own storage — cost a tap every time,
    // to choose the one place that is always reachable and where downloads
    // land.
    //
    // Here rather than in a callback after the first frame: a session added
    // later shows the full-width picker for a frame before replacing it.
    // Nothing is listening to the controller yet, which is what makes adding
    // one this early safe.
    _openLocal();
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
        // As on the terminal tab: the rail stays whether or not anything is
        // open, so closing the last browser does not fold the page into a
        // different layout.
        sideBuilder: (_) => _SideBar(
          sessions: _sessions,
          actions: [_searchBtn, _addBtn],
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
      body: SessionTabsView<FileSession>(
        controller: _sessions,
        // Page 0 is the picker's on one column. Beside a rail it is the empty
        // surface, and not the picker: the rail is already that list.
        leading: split
            ? const EmptyPane(icon: Icons.folder_open)
            : _picker,
        builder: (_, tab) {
          final session = tab.data;
          void onPathChanged(String path) {
            if (session.currentPath == path) return;
            session.currentPath = path;
            _save();
          }

          return switch (session) {
            LocalFileSession() => LocalFilePage(
              key: ValueKey(tab.id),
              args: LocalFilePageArgs(
                initDir: session.initialPath,
                actionsSink: session.actions,
                onPathChanged: onPathChanged,
              ),
            ),
            ServerFileSession(:final spi) => ServerFilePage(
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
      // The same two the rail carries. On one screen the picker is a tab
      // rather than a column, and these act on what it lists.
      leadingActions: [_searchBtn, _addBtn],
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
      session: LocalFileSession(initialPath: initialPath),
      select: select,
    );
  }

  void _openRemote(Spi spi, {String? initialPath, bool select = true}) {
    _add(
      preferred: spi.name,
      session: ServerFileSession(spi: spi, initialPath: initialPath),
      select: select,
    );
  }

  /// [select] is off while restoring: selecting each as it arrives would
  /// animate through every session to land on the last.
  void _add({
    required String preferred,
    required FileSession session,
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
      // A record written before `kind` existed says nothing, and local was
      // implied by the absence of a server. Both shapes read the same way.
      // TODO: drop the `serverId == null` fallback once no saved tab set
      // predates the `kind` field.
      final isLocal = entry['kind'] == _kindLocal || serverId == null;
      if (isLocal) {
        _openLocal(initialPath: path, select: false);
      } else {
        final spi = servers[serverId];
        // A server can be deleted, or switched to a connection that cannot
        // carry SFTP, while a tab on it is still remembered.
        if (spi == null || !_canBrowse(ref, spi)) continue;
        _openRemote(spi, initialPath: path, select: false);
      }
      restored++;
    }

    // Everything it remembered is gone — every server deleted, or switched to
    // a connection that cannot carry SFTP. That is the empty tab this page no
    // longer opens with, so it falls back to the same default a first run gets.
    if (restored == 0) {
      _openLocal();
      return;
    }
    _save();
    _sessions.select(1);
  }
}

/// What acts on the list of places rather than on one browser in it.
extension _Actions on _FileTabPageState {
  Widget get _searchBtn => Btn.icon(
    icon: const Icon(Icons.search, size: 18),
    onTap: _showSearch,
  );

  /// A server this app does not know about yet cannot be browsed, and the rail
  /// is where someone looking for it would look.
  Widget get _addBtn => Btn.icon(
    icon: const Icon(Icons.add, size: 18),
    onTap: () => ServerEditPage.route.go(context),
  );

  void _showSearch() {
    showSearch(
      context: context,
      delegate: SearchPage<Spi>(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        future: (query) async {
          if (query.isEmpty) return [];
          // Read per query rather than snapshotted when the search opened, so
          // a server added or renamed meanwhile is findable.
          final state = ref.read(serversProvider);
          final needle = query.toLowerCase();
          return [
            for (final id in state.serverOrder)
              if (state.servers[id] case final spi? when _canBrowse(ref, spi))
                if (spi.name.toLowerCase().contains(needle) ||
                    spi.displayAddr.toLowerCase().contains(needle))
                  spi,
          ];
        },
        builder: (ctx, spi) => ListTile(
          title: Text(spi.name),
          subtitle: Text(spi.displayAddr),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ctx.pop();
            _openRemote(spi);
          },
        ),
      ),
    );
  }
}

/// Whether a file browser can be opened on [spi] at all.
///
/// One question, asked in one place: [canTransferTo] is the same call, so the
/// list of servers you can browse and the list you can send a file to cannot
/// drift apart.
///
/// Depends on what the agent grants, which is why it needs a [ref]: a monitor
/// server serves files only where its operator switched the endpoint on, and
/// that answer arrives on `/capabilities` rather than from the credential.
bool _canBrowse(WidgetRef ref, Spi spi) => canTransferTo(ref, spi);

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
        CardTile(
          icon: Icons.smartphone,
          title: libL10n.device,
          subtitle: Paths.file,
          onTap: onLocal,
        ),
        for (final id in state.serverOrder)
          if (state.servers[id] case final spi? when _canBrowse(ref, spi))
            CardTile(
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
    required this.actions,
    required this.onLocal,
    required this.onServer,
    required this.onSelect,
    required this.onClose,
  });

  final SessionTabsController<FileSession> sessions;

  /// What acts on the rail rather than on one session in it.
  final List<Widget> actions;

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
        actions: actions,
        // Nothing here is running. A browser is a place you are looking at,
        // and the default heading — written for terminals, where a session can
        // have a command still going — said otherwise.
        runningLabel: libL10n.browsing,
        targets: [
          // Under a heading of its own, short as the group is. Without one it
          // ran straight on from the browsers above, and since this device is
          // now always one of them, the rail read as the same name twice with
          // nothing between to say that one goes there and the other opens
          // another.
          SideBarSection(libL10n.open),
          SideBarTile(title: libL10n.device, onTap: onLocal),
          SideBarSection(libL10n.servers),
          for (final id in state.serverOrder)
            if (state.servers[id] case final spi? when _canBrowse(ref, spi))
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

/// The toolbar of whichever session is showing.
///
/// Rebuilt from that session's own notifier, so the strip does not have to
/// listen to every open session to keep one row of buttons current.
class _SessionActions extends StatelessWidget {
  const _SessionActions({required this.sessions});

  final SessionTabsController<FileSession> sessions;

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
