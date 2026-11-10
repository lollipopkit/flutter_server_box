import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/view/agent/screen.dart';
import 'package:server_box/view/page/server/widget/server_side_tile.dart';
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
  /// Where the browser is now, reported as it moves. Null until the first
  /// listing lands.
  String? currentPath;

  /// The page's toolbar, which it hands over rather than drawing, so the tab
  /// strip is the only bar on screen.
  ///
  /// One per session: every page is built, including the ones off screen, and
  /// a shared sink would have them overwriting each other.
  final actions = ValueNotifier<List<BarAction>>(const []);

  void dispose() => actions.dispose();
}

/// This device's own files.
final class LocalFileSession extends FileSession {}

/// A server's files, however they are reached.
///
/// Not `SftpSession`: which transport carries the bytes is resolved by
/// capability when the page opens, and a server that gains sshd later changes
/// backend without changing what kind of tab it is.
final class ServerFileSession extends FileSession {
  ServerFileSession({required this.spi});

  final Spi spi;
}

class _FileTabPageState extends ConsumerState<FileTabPage>
    with AutomaticKeepAliveClientMixin {
  // A list to pick from, as the terminal tab's is (#1808).
  late final _sessions = SessionTabsController<FileSession>(
    leadingName: libL10n.select,
  );

  late final VoidCallback _hideFromAgent;

  /// The bar's search: what is typed, and whether the bar is a field at all.
  ///
  /// It is for "which server do I open", which is what the picker and the rail
  /// are both a list of — so it narrows that list where it is, in the column
  /// or the tab holding it.
  final _search = InlineSearchController();

  /// What the right column is showing instead of the browsers, if anything.
  ///
  /// Null is the ordinary state. Set by [FilePaneHost.open] — the transfers,
  /// the one thing it shows — and cleared by the way back this page draws for
  /// it.
  WidgetBuilder? _paneView;

  /// Whether the last build had a column beside the rail, which is where
  /// [_paneView] is drawn.
  var _split = false;

  late final _picker = _PickPage(
    search: _search,
    onLocal: _openLocal,
    onServer: _openRemote,
  );

  @override
  bool get wantKeepAlive => true;

  /// Whether this page has already chosen what to open with. Once, on the way
  /// to the first frame; an empty tab after that is one the user emptied.
  bool _chosenInitial = false;

  @override
  void initState() {
    super.initState();
    _hideFromAgent = AgentScreen.files(
      () {
        final at = switch (_sessions.current?.data) {
          final ServerFileSession s =>
            'the files of ${AgentScreen.server(s.spi)}${_at(s.currentPath)}',
          final s? => "this device's files${_at(s.currentPath)}",
          null => null,
        };
        // The column is drawn only while split, and left set when it stops.
        if (!_split || _paneView == null) return at;
        return at == null
            ? 'the transfer list'
            : 'the transfer list, over $at';
      },
    );
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

    // What was asked for while this tab did not exist is about to be drained:
    // this page is not empty and has nothing to default to.
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
    _hideFromAgent();
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
          actions: [_searchAction],
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
    _split = split;
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
        // Sessions can open while another tab is the one on screen.
        mayFocus: () => ref.read(currentHomeTabProvider) == AppTab.file,
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
          }

          return switch (session) {
            LocalFileSession() => LocalFilePage(
              key: ValueKey(tab.id),
              args: LocalFilePageArgs(
                actionsSink: session.actions,
                onPathChanged: onPathChanged,
              ),
            ),
            ServerFileSession(:final spi) => ServerFilePage(
              key: ValueKey(tab.id),
              args: SftpPageArgs(
                spi: spi,
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
    // The wrapper is what the `Scaffold` measures, so it has to be told;
    // its own default is a full toolbar.
    preferSize: const Size.fromHeight(SessionTabBar.height),
    builder: () {
      // The page's own, handed over through its sink — see
      // [FileSession.actions].
      final actions = _sessions.current?.data.actions ?? _noActions;
      return ListenBuilder(
        listenable: actions,
        builder: () => SessionTabBar(
          names: _sessions.names,
          index: _sessions.index,
          leadingIcon: null,
          onTap: _sessions.select,
          onClose: _close,
          detailOf: _sessionPath,
          leadingOf: _sessions.markOf,
          sessionActions: actions.value,
          // The same one the rail carries. On one screen the picker is a tab
          // rather than a column, and this acts on what it lists.
          leadingActions: [_searchAction],
          // In place of the strip, as on the terminal tab: what is searched is
          // the picker, and the tabs beside it are open browsers.
          search: _search,
        ),
      );
    },
  );

  PreferredSizeWidget get _sessionBar => PreferredSizeListenBuilder(
    listenable: _sessions,
    builder: () {
      final actions = _sessions.current?.data.actions ?? _noActions;
      return CustomAppBar(
        title: Text(_sessions.current?.name ?? libL10n.file),
        actions: [
          ListenBuilder(
            listenable: actions,
            builder: () => Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final action in actions.value) action.button()],
            ),
          ),
          const SizedBox(width: 7),
        ],
      );
    },
  );

  static String _at(String? path) =>
      path == null || path.isEmpty ? '' : ' at $path';

  /// What a session's row in the sheet says under the name: where that browser
  /// is. Two tabs on one server are told apart by this and by nothing else.
  String? _sessionPath(int index) =>
      _sessions.tabs.elementAtOrNull(index - 1)?.data.currentPath;
}

extension _Sessions on _FileTabPageState {
  void _openLocal() =>
      _add(preferred: libL10n.device, session: LocalFileSession());

  void _openRemote(Spi spi) =>
      _add(preferred: spi.name, session: ServerFileSession(spi: spi));

  void _add({required String preferred, required FileSession session}) {
    final tab = _sessions.add(preferred: preferred, build: (_, _, _) => session);
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
  }
}

/// What the bar listens to while no browser is open.
final _noActions = ValueNotifier<List<BarAction>>(const []);

/// What acts on the list of places rather than on one browser in it.
extension _Actions on _FileTabPageState {
  BarAction get _searchAction => BarAction(
    icon: Icons.search,
    label: libL10n.search,
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
                // No generic icon behind the mark: `distIcon` answers null
                // when marks are off, and the same icon on every server row
                // would tell them apart from nothing.
                leading: distIcon(spi.id, size: 24),
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
extension on SessionTabsController<FileSession> {
  String? _serverIdAt(int index) =>
      switch (tabs.elementAtOrNull(index - 1)?.data) {
        ServerFileSession(:final spi) => spi.id,
        _ => null,
      };

  /// The server's mark before a browser's name in the strip's sheet, where it
  /// has one.
  Widget? markOf(int index) => switch (_serverIdAt(index)) {
    final id? => distIcon(id, size: kSideMarkSize),
    null => null,
  };

  /// The browser at [index] as a row of the rail — see [railRow].
  RailRow railOf(int index) => railRow(
    serverId: _serverIdAt(index),
    live: true,
    selected: index == this.index,
  );
}

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
  final List<BarAction> actions;

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
        leadingOf: (i) => sessions.railOf(i).leading,
        liveOf: (i) => sessions.railOf(i).live,
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
              ServerSideTile(
                key: ValueKey(id),
                spi: spi,
                onTap: () => onServer(spi),
              ),
          ],
        );
      },
    );
  }
}

