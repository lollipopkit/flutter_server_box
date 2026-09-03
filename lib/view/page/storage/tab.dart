import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/storage/file_pane.dart';
import 'package:server_box/view/page/storage/local.dart';
import 'package:server_box/view/page/storage/send_to.dart';
import 'package:server_box/view/page/storage/server_file.dart';
import 'package:server_box/view/page/storage/sftp.dart';
import 'package:server_box/view/widget/dist_icon.dart';
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
    with AutomaticKeepAliveClientMixin {
  late final _sessions = SessionTabsController<FileSession>(
    leadingName: libL10n.open,
  );

  /// The bar's search: what is typed, and whether the bar is a field at all.
  ///
  /// It is for "which server do I open", which is what the picker and the rail
  /// are both a list of — so it narrows that list where it is, in the column
  /// or the tab holding it.
  final _search = InlineSearchController();

  /// What the right column is showing instead of the browsers, if anything.
  ///
  /// Null is the ordinary state. Set by [FilePaneHost.open] — the transfers,
  /// a search — and cleared by the way back this page draws for it.
  WidgetBuilder? _paneView;

  late final _picker = _PickPage(
    search: _search,
    onLocal: _openLocal,
    onServer: _openRemote,
  );

  @override
  bool get wantKeepAlive => true;

  /// Whether there is saved state on its way back, known before anything
  /// decides this tab is empty.
  ///
  /// Read from the store rather than from Flutter's restoration, which this
  /// page used until it was measured: `restoreState` ran with a null bucket,
  /// so nothing registered with it was ever written and "reopens where it was
  /// left" had never worked. The terminal tab moved to the same store for the
  /// same reason — and a store survives what saved instance state does not,
  /// which is the app being killed in the background.
  late final bool _hasSavedSessions =
      Stores.history.fileTabs.fetch().isNotEmpty;

  /// Whether this page has already chosen what to open with. Once, on the way
  /// to the first frame; an empty tab after that is one the user emptied.
  bool _chosenInitial = false;

  @override
  void initState() {
    super.initState();
    if (_hasSavedSessions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restore();
      });
    }
    // Anything queued before this tab existed — tabs are built when first
    // visited, so a request from the server list arrives before there is
    // anything here to receive it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _drainRequests();
    });
  }

  @override
  void didChangeDependencies() {
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
    // The controller disposes what it created — focus, visibility — but the
    // session data is ours.
    for (final tab in _sessions.tabs) {
      tab.data.dispose();
    }
    _sessions.dispose();
    _search.dispose();
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
          search: _search,
          actions: [_searchBtn],
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

    // Only while there is a column to lend. Without it `FilePaneHost.of`
    // answers null and every caller pushes a page, which is what a narrow
    // window has always done and the only thing it can do.
    if (!split) return _buildSessions(split);

    final view = _paneView;
    // Installed around whichever of the two is showing, so that what is *in*
    // the column can close itself — a search ends by picking something, not by
    // pressing back.
    return FilePaneHost(
      open: (body) => setStateSafe(() => _paneView = body),
      close: () => setStateSafe(() => _paneView = null),
      // Stacked, not swapped. The browsers stay mounted underneath: what the
      // search shows is built by the browser's own state — its entries, its
      // rows — and replacing it left that state defunct and the column red.
      //
      // So the switcher carries only the layer on top, and the layer below is
      // never rebuilt out of existence. Ignoring pointers while something is
      // over it, because it is still there to be tapped otherwise.
      child: Stack(
        children: [
          IgnorePointer(ignoring: view != null, child: _buildSessions(split)),
          AnimatedSwitcher(
            duration: Durations.short4,
            child: view == null
                ? const SizedBox.shrink(key: ValueKey('none'))
                : Builder(key: const ValueKey('pane'), builder: view),
          ),
        ],
      ),
    );
  }

  Widget _buildSessions(bool split) {
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
    listenable: Listenable.merge([_sessions, _search]),
    // The wrapper is what the `Scaffold` measures, so it has to be told;
    // its own default is a full toolbar.
    preferSize: const Size.fromHeight(SessionTabBar.height),
    builder: () => SizedBox(
      height: SessionTabBar.height,
      // In place of the strip, as on the terminal tab: what is searched is the
      // picker, and the tabs beside it are open browsers.
      child: InlineSearchBar(
        controller: _search,
        child: SessionTabBar(
      names: _sessions.names,
      index: _sessions.index,
      leadingIcon: MingCute.folder_fill,
      onTap: _sessions.select,
      onClose: _close,
      detailOf: _sessionPath,
      // One widget that follows whichever session is showing, rather than a
      // list the bar would have to rebuild itself to keep current.
      sessionActions: [_SessionActions(sessions: _sessions)],
      // The same two the rail carries. On one screen the picker is a tab
      // rather than a column, and these act on what it lists.
                leadingActions: [_searchBtn],
        ),
      ),
    ),
  );

  PreferredSizeWidget get _sessionBar => PreferredSizeListenBuilder(
    listenable: _sessions,
    builder: () => CustomAppBar(
      title: Text(_sessions.current?.name ?? libL10n.file),
      actions: [_SessionActions(sessions: _sessions)],
    ),
  );

  /// What a session's row in the sheet says under the name: where that browser
  /// is. Two tabs on one server are told apart by this and by nothing else.
  String? _sessionPath(int index) =>
      _sessions.tabs.elementAtOrNull(index - 1)?.data.path;
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
    Stores.history.fileTabs.put(
      jsonEncode([for (final tab in _sessions.tabs) tab.data.toRestorable()]),
    );
  }

  /// Reopens what was being browsed, where it was being browsed.
  ///
  /// Unlike a terminal there is nothing still alive on the far side — a remote
  /// tab reconnects. What this restores is the intent: which places, and where
  /// in them.
  void _restore() {
    final List<dynamic> entries;
    try {
      entries = jsonDecode(Stores.history.fileTabs.fetch()) as List;
    } catch (e, st) {
      Loggers.app.warning('Unreadable file tab state', e, st);
      return;
    }

    // Read once, not once per tab.
    final servers = {for (final spi in Stores.server.fetch()) spi.id: spi};

    var restored = 0;
    for (final entry in entries) {
      if (entry is! Map) continue;
      // Tested rather than cast: `as String?` throws on a value that is neither
      // and takes every remaining tab with it, which is what reading each entry
      // on its own is meant to avoid.
      final rawPath = entry['path'];
      final path = rawPath is String ? rawPath : null;
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
        // Only "the server is gone". It used to also require `_canBrowse`,
        // which for a monitor server is the agent's own answer and is false
        // until the first poll comes back — so restoring on the first frame
        // dropped those tabs, and the `_save()` below then wrote the shortened
        // list back and lost them for good. `ServerFilePage` already says so
        // when a server genuinely cannot serve files, which is the right place
        // for an answer that arrives later than this.
        if (spi == null) continue;
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
    text: libL10n.search,
    icon: const Icon(Icons.search, size: 18),
    onTap: _search.start,
  );

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
  const _PickPage({
    required this.search,
    required this.onLocal,
    required this.onServer,
  });

  /// The bar's search, shared with the rail beside this picker.
  final InlineSearchController search;

  final VoidCallback onLocal;
  final void Function(Spi spi) onServer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serversProvider);

    return ListenBuilder(
      listenable: search,
      builder: () {
        final needle = search.needle;
        final found = [
          for (final id in state.serverOrder)
            if (state.servers[id] case final spi? when _canBrowse(ref, spi))
              if (needle.isEmpty ||
                  spi.name.toLowerCase().contains(needle) ||
                  spi.displayAddr.toLowerCase().contains(needle))
                spi,
        ];

        if (needle.isNotEmpty && found.isEmpty) {
          return EmptyPane(icon: Icons.search_off, label: needle);
        }

        return MasonryList(
          columnWidth: _kColumnWidth,
          children: [
            // Dropped while a search is on: it is a card with a fixed name,
            // and leaving it under a query that does not match it makes it
            // read as a result.
            if (needle.isEmpty)
              CardTile(
                icon: Icons.smartphone,
                title: libL10n.device,
                subtitle: Paths.file,
                onTap: onLocal,
              ),
            for (final spi in found)
              CardTile(
                key: ValueKey(spi.id),
                // The mark where the generic icon was, and the generic icon
                // still behind it: `distIcon` answers null when marks are off,
                // and `icon` is what that falls through to.
                leading: distIcon(spi.id, size: 24),
                icon: Icons.dns,
                title: spi.name,
                subtitle: spi.displayAddr,
                onTap: () => onServer(spi),
              ),
          ],
        );
      },
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
    required this.search,
    required this.actions,
    required this.onLocal,
    required this.onServer,
    required this.onSelect,
    required this.onClose,
  });

  final SessionTabsController<FileSession> sessions;

  /// The bar's search, shared with the picker beside this rail.
  final InlineSearchController search;

  /// What acts on the rail rather than on one session in it.
  final List<Widget> actions;

  final VoidCallback onLocal;
  final void Function(Spi spi) onServer;
  final void Function(int index) onSelect;
  final void Function(int index) onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _buildSessionList(context, ref);
  }

  Widget _buildSessionList(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serversProvider);

    return ListenBuilder(
      listenable: Listenable.merge([sessions, search]),
      builder: () {
        // Read inside, or it is the query from whenever this method last ran:
        // a notification rebuilds the builder, not the widget around it, so a
        // value captured out here never changes.
        final needle = search.needle;
        return SessionSideBar(
        names: sessions.names,
        index: sessions.index,
        onTap: onSelect,
        onClose: onClose,
        actions: actions,
        search: search,
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
          // Dropped while a search is on: it is a row with a fixed name, and
          // leaving it under a query that does not match it makes it read as a
          // result.
          if (needle.isEmpty) ...[
            SideBarSection(libL10n.open),
            SideBarTile(title: libL10n.device, onTap: onLocal),
          ],
          SideBarSection(libL10n.servers),
          for (final id in state.serverOrder)
            if (state.servers[id] case final spi? when _canBrowse(ref, spi))
              if (needle.isEmpty ||
                  spi.name.toLowerCase().contains(needle) ||
                  spi.displayAddr.toLowerCase().contains(needle))
              SideBarTile(
                key: ValueKey(id),
                leading: distIcon(spi.id, size: 22),
                title: spi.name,
                onTap: () => onServer(spi),
              ),
          ],
        );
      },
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
