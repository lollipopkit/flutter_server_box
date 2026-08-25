import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/local_shell.dart';
import 'package:server_box/core/utils/rootfs.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/widget/dist_icon.dart';
import 'package:server_box/view/widget/pane_settings.dart';
import 'package:server_box/view/widget/rootfs_install.dart';

part 'tab_add.dart';
part 'tab_sort.dart';

/// Every open terminal, one tab each, plus a picker at the head of the strip.
class SSHTabPage extends ConsumerStatefulWidget {
  const SSHTabPage({super.key});

  @override
  ConsumerState<SSHTabPage> createState() => _SSHTabPageState();

  static const route = AppRouteNoArg(page: SSHTabPage.new, path: '/ssh');
}

/// What a terminal tab is, beyond the name, focus and visibility that
/// [SessionTabsController] already keeps for it.
///
/// The page is built once and held rather than rebuilt from this record: a
/// terminal's state lives in its element, and handing `PageView` a fresh
/// widget every frame would be leaning on `GlobalKey` to put it back.
class _SshSession {
  const _SshSession({required this.page, required this.pageKey});

  final SSHPage page;
  final GlobalKey<SSHPageState> pageKey;

  /// What has to survive a relaunch. Read from the live page when there is
  /// one, and from the arguments it was opened with when there is not — a tab
  /// restored but never looked at has no state of its own yet.
  Map<String, dynamic> toRestorable() {
    final live = pageKey.currentState;
    return {
      // The source's id, not a server's: this device has one too, and it is
      // what tells the two apart when the set is reopened.
      'sourceId': live?.widget.args.source.id ?? page.args.source.id,
      'tmuxSession': live?.tmuxCurrentSession ?? page.args.tmuxSession,
      'tmuxWindow': live?.tmuxCurrentWindow ?? page.args.tmuxWindow,
    };
  }
}

class _SSHTabPageState extends ConsumerState<SSHTabPage>
    with AutomaticKeepAliveClientMixin {
  late final _sessions = SessionTabsController<_SshSession>(
    leadingName: libL10n.add,
  );

  /// Notified when the picker's sort order changes. That order lives in the
  /// settings store rather than a provider, so nothing else would tell the
  /// picker — or the icon on the bar — to rebuild.
  final _sortVersion = RNode();

  /// The picker, and the button for adding a server to pick from.
  ///
  /// A scaffold of its own so the button belongs to the page it acts on,
  /// wherever that page is shown — the first tab on one screen, the column
  /// beside the terminals on two.
  late final _picker = Scaffold(
    body: _AddPage(
      sortVersion: _sortVersion,
      onTap: _openServer,
      onLocal: () => _open(const LocalSource()),
      onRootfsOpen: _openRootfs,
      onRootfsAdd: _addRootfs,
      onRootfsRemove: _removeRootfs,
      onLongPress: (spi) =>
          ServerEditPage.route.go(context, args: SpiRequiredArgs(spi)),
    ),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Rootfs.removed.addListener(_onRootfsRemoved);
    // Both after the first frame, and in this order: a queued request is what
    // the user just asked for, and it should end up beside the tabs that were
    // already open rather than racing them.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreTabs();
      if (!mounted) return;
      // Here and not only from the listener: a flag set before this tab was
      // ever built is not a *change* by the time the listener exists, so
      // nothing would fire and the request would stand for good — after which
      // asking again would set a value it already had, and change nothing.
      //
      // Before the queue, not after it. Both can be standing at once — close
      // every terminal, then open one from a server's row — and draining them
      // the other way round closed the terminal that was just asked for.
      _drainCloseAll();
      _drainRequests();
    });
  }

  @override
  void dispose() {
    Rootfs.removed.removeListener(_onRootfsRemoved);
    _sessions.dispose();
    _sortVersion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(terminalRequestsProvider, (_, _) => _drainRequests());
    ref.listen(terminalCloseAllRequestProvider, (_, _) => _drainCloseAll());
    return ListenBuilder(
      listenable: _sessions,
      builder: () => SbPaneList(
        // The rail is there from the start, empty surface or not. Folding it
        // away until the first terminal opened meant this tab greeted a wide
        // window with a full-width grid of cards, and then rearranged itself
        // into a rail and a surface the moment one was opened — two layouts
        // for one page, the first of which is not what the page looks like.
        sideBuilder: (_) => _SideBar(
          sessions: _sessions,
          sortVersion: _sortVersion,
          actions: [_sortBtn, _searchBtn, _historyBtn],
          onOpen: _openServer,
          onLocal: () => _open(const LocalSource()),
          onRootfsOpen: _openRootfs,
          onRootfsAdd: _addRootfs,
          onRootfsRemove: _removeRootfs,
          onEdit: (spi) =>
              ServerEditPage.route.go(context, args: SpiRequiredArgs(spi)),
          onSelect: _sessions.select,
          onClose: _confirmClose,
        ),
        builder: (_, split) => _buildTerminals(split),
      ),
    );
  }

  Widget _buildTerminals(bool split) {
    // Selected here rather than left where it was: page 0 is the picker's,
    // and once the rail is drawing that list nothing in it can reach page 0
    // again, so a layout that turns split while the picker was current left an
    // empty surface beside a rail with no way back. Deferred, because this
    // runs during a build.
    final landOn = _firstTabToStart();
    if (split && _sessions.index == 0 && landOn != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sessions.index == 0) _sessions.select(landOn);
      });
    }

    return Scaffold(
      // With a rail beside it there is nothing left for a strip to do: the
      // rail switches sessions and starts them, so all the bar has to say is
      // which one is on screen.
      appBar: split ? _sessionBar : _tabBar,
      body: SessionTabsView<_SshSession>(
        controller: _sessions,
        // Page 0 is the picker's on one column. Beside a rail it is what the
        // surface shows before anything is opened — and nothing else, because
        // the rail is already that list and drawing it twice is what the grid
        // of cards was.
        leading: split
            ? const EmptyPane(icon: Icons.terminal_outlined)
            : _picker,
        builder: (_, tab) => tab.data.page,
      ),
    );
  }

  PreferredSizeWidget get _tabBar => PreferredSizeListenBuilder(
    // Both: the bar shows which tab is current *and* how the picker behind it
    // is sorted.
    listenable: Listenable.merge([_sessions, _sortVersion]),
    // The wrapper is what the `Scaffold` measures, so it has to be told;
    // its own default is a full toolbar.
    preferSize: const Size.fromHeight(SessionTabBar.height),
    builder: () => SessionTabBar(
      names: _sessions.names,
      index: _sessions.index,
      onTap: _sessions.select,
      onClose: _confirmClose,
      detailOf: _sessionAddr,
      sessionActions: _serverActions,
      leadingActions: [_sortBtn, _searchBtn, _historyBtn],
    ),
  );

  /// What a session's row in the sheet says under the name: the machine the
  /// shell is on. Nothing for a shell on this device — its name already says
  /// so, and it has no address to give.
  String? _sessionAddr(int index) {
    final tab = _sessions.tabs.elementAtOrNull(index - 1);
    return switch (tab?.data.page.args.source) {
      ServerSource(:final spi) => spi.displayAddr,
      _ => null,
    };
  }

  PreferredSizeWidget get _sessionBar => PreferredSizeListenBuilder(
    listenable: _sessions,
    builder: () {
      final current = _sessions.current;
      return CustomAppBar(
        title: Text(current?.name ?? libL10n.terminal),
        // Both act on the terminal that is showing, and now that the rail
        // stays up with none of them open there may be no such terminal. A
        // button that looks tappable and does nothing is worse than no button.
        actions: current == null
            ? const []
            : [..._serverActions, const SizedBox(width: 7)],
      );
    },
  );
}

/// Opening, closing and remembering terminals.
extension _Sessions on _SSHTabPageState {
  /// Opens a shell on [spi].
  void _openServer(
    Spi spi, {
    Snippet? snippet,
    TerminalSession? session,
    String? tmuxSession,
    int? tmuxWindow,
    bool select = true,
  }) => _open(
    ServerSource(spi),
    snippet: snippet,
    session: session,
    tmuxSession: tmuxSession,
    tmuxWindow: tmuxWindow,
    select: select,
  );

  /// Opens a shell wherever [source] says.
  ///
  /// [select] is off while restoring: selecting each tab as it arrives would
  /// animate through all of them and land on the last, which is not where
  /// anyone left off.
  void _open(
    TerminalSource source, {
    Snippet? snippet,
    TerminalSession? session,
    String? tmuxSession,
    int? tmuxWindow,
    bool select = true,
  }) {
    // Assigned once `add` returns. Only the callback below reads it, and only
    // after the session it names has run for a while — the tab's own name is
    // what anything evaluated *during* the build has to use.
    late final String id;
    final tab = _sessions.add(
      preferred: source.label,
      build: (name, focus, visible) {
        final key = GlobalKey<SSHPageState>(debugLabel: name);
        return _SshSession(
          pageKey: key,
          page: SSHPage(
            key: key,
            args: SshPageArgs(
              source: source,
              initSnippet: snippet,
              session: session,
              notFromTab: false,
              // The tab's id, not its name: a connection can end long after
              // its tab was closed, by which time the name may belong to a
              // newer session on the same server.
              onSessionEnd: () => _closeTab(id),
              focusNode: focus,
              visibleListenable: visible,
              tmuxSession: tmuxSession,
              tmuxWindow: tmuxWindow,
              onTmuxStateChanged: _saveTabs,
              // Per tab: two shells on one server would otherwise share one
              // restoration bucket and overwrite each other's tmux state.
              //
              // The name, not the id: this is evaluated while `add` is still
              // running, so the id does not exist yet. The name is unique
              // among the open tabs and comes back in the same order after a
              // relaunch, which is all a restoration key needs.
              restorationId: 'tab_$name',
            ),
          ),
        );
      },
    );
    id = tab.id;
    // History is a list of servers visited. This device is not one of them,
    // and is one tap away in the rail regardless.
    if (source case ServerSource(:final spi)) {
      Stores.history.sshServerHistory.add(spi.id);
    }
    if (!select) return;
    _saveTabs();
    _sessions.select(_sessions.names.indexOf(tab.name));
  }

  /// Opens a shell in the system a chip names.
  ///
  /// Which one is picked on the page rather than asked for here: they can all
  /// run at once, so it is a tap on the one wanted and not a question in the
  /// way.
  void _openRootfs(String profileId) =>
      _open(LocalSource(rootfs: true, profileId: profileId));

  /// Installs another system and opens a shell in it.
  ///
  /// The install is where the tap may stop: it downloads, and it can be
  /// cancelled or fail. Only a system that is actually there gets a tab, which
  /// is why the id comes back from the install rather than from the settings.
  Future<void> _addRootfs() async {
    final before = {for (final e in Rootfs.profiles) e.id};
    // The chip says "install" with nothing there and "add" otherwise, and it
    // has to mean both.
    if (!await installRootfs(context, another: before.isNotEmpty)) return;
    if (!mounted) return;
    final added = Rootfs.profiles.firstWhereOrNull(
      (e) => !before.contains(e.id),
    );
    // Nothing new means it was already there and the install returned early —
    // the first system, opened by the chip that offered to install it.
    //
    // Null rather than an empty string: null is what every layer below reads
    // as "whichever is selected", while "" is a profile name, and the engine
    // answers -EINVAL to it.
    final id = added?.id ?? Rootfs.selected?.id;
    if (id == null) return;
    _openRootfs(id);
  }

  /// Deletes one Linux system, and the terminals that were inside it.
  ///
  /// Their shells are already gone with the files they were running from, so
  /// leaving the tabs up would leave dead terminals nobody asked to keep. Tabs
  /// in the *other* systems are untouched — that is the point of them being
  /// separate.
  Future<void> _removeRootfs(LinuxProfile target) async {
    await removeRootfs(context, profile: target);
  }

  /// Closes the terminals that were running in a system that has been deleted.
  ///
  /// Their shells went with the files they were running from, so leaving the
  /// tabs up leaves dead terminals nobody asked to keep. Driven by
  /// `Rootfs.removed` rather than by the delete here, because the settings page
  /// deletes too and only this page has the tabs.
  void _onRootfsRemoved() {
    final id = Rootfs.removed.value;
    if (id == null || !mounted) return;
    for (final tab in [..._sessions.tabs]) {
      final source = tab.data.page.args.source;
      if (source is! LocalSource || !source.rootfs) continue;
      // A tab that names no profile was opened in whichever was selected then.
      // With that one gone the selection has moved, so it cannot be recovered
      // here — such a tab is left alone rather than closed on a guess, and its
      // shell reports what it finds.
      if (source.profileId == id) _closeTab(tab.id);
    }
  }

  Future<void> _confirmClose(int index) async {
    // Resolved now, while the position still means what the bar drew.
    final tab = _sessions.tabs.elementAtOrNull(index - 1);
    if (tab == null) return;

    final confirm = await contextSafe?.showRoundDialog(
      title: libL10n.attention,
      // Not "SSH": this strip also carries a shell on this device and one
      // inside the Linux userland, neither of which is a connection to
      // anything.
      child: Text('${libL10n.close} ${libL10n.terminal}(${tab.name}) ?'),
      actions: Btnx.okReds,
    );
    if (confirm != true) return;
    // Only once the tab is actually going. Dropping focus on the way out of a
    // cancelled dialog took the keyboard from a terminal the user had just
    // decided to keep.
    if (mounted) FocusScope.of(context).unfocus();
    _closeTab(tab.id);
  }

  /// Closes every terminal, when something has asked for it.
  ///
  /// No confirmation here. The ask comes from the tab strip's own menu, which
  /// confirms before it gets this far; this end only knows that the answer was
  /// yes.
  void _drainCloseAll() {
    if (!ref.read(terminalCloseAllRequestProvider)) return;
    ref.read(terminalCloseAllRequestProvider.notifier).done();

    // Copied, because closing a tab is what mutates the list being walked.
    final ids = [for (final tab in _sessions.tabs) tab.id];
    if (ids.isEmpty) return;
    if (mounted) FocusScope.of(context).unfocus();
    for (final id in ids) {
      _closeTab(id);
    }
  }

  /// Opens everything queued for this tab and empties the queue.
  void _drainRequests() {
    final pending = ref.read(terminalRequestsProvider);
    if (pending.isEmpty) return;
    ref.read(terminalRequestsProvider.notifier).clear();
    for (final request in pending) {
      _openServer(
        request.spi,
        snippet: request.snippet,
        session: request.session,
      );
    }
  }

  /// The first open tab worth landing on, or null when there is none.
  ///
  /// Local shells are passed over. Showing a terminal starts it, and on iOS
  /// starting the local one boots the Linux guest — too much to happen because
  /// a tab came into view. They are still in the rail, one tap away, and a
  /// server reconnects on sight as it always did.
  int? _firstTabToStart() {
    final tabs = _sessions.tabs;
    for (var i = 0; i < tabs.length; i++) {
      if (tabs[i].data.page.args.source is! LocalSource) return i + 1;
    }
    return null;
  }

  void _closeTab(String id) {
    _sessions.remove(id);
    if (mounted) _saveTabs();
  }

  void _saveTabs() {
    Stores.history.sshTabs.put(
      jsonEncode([for (final tab in _sessions.tabs) tab.data.toRestorable()]),
    );
  }

  /// Reopens whatever was open when the app last went away.
  ///
  /// Each entry is read defensively and skipped on its own. This is the one
  /// path that runs against data an older build wrote, and a single malformed
  /// record used to abort the loop — taking every other terminal with it.
  Future<void> _restoreTabs() async {
    final saved = Stores.history.sshTabs.fetch();
    if (saved.isEmpty) return;

    final List<dynamic> entries;
    try {
      entries = jsonDecode(saved) as List;
    } catch (e, st) {
      Loggers.app.warning('Unreadable SSH tab state', e, st);
      return;
    }

    // Read once, not once per tab.
    final servers = {for (final spi in Stores.server.fetch()) spi.id: spi};

    var restored = 0;
    for (final entry in entries) {
      if (entry is! Map) continue;
      // TODO(migration residue; remove once no saved tab set predates
      // `sourceId`): `serverId` is what records written before this tab could
      // open a shell on the device itself carry. Read as a fallback rather
      // than migrated: one relaunch rewrites the lot, and a session that fails
      // to reopen has cost nothing.
      final id = entry['sourceId'] ?? entry['serverId'];
      final TerminalSource source;
      if (id is String && id.startsWith(LocalSource.rootfsId)) {
        // Only where there is one to enter. A rootfs the user deleted, or a
        // tab set restored onto a build without proot, would otherwise reopen
        // as a terminal that can only print an error.
        if (!Rootfs.isAvailable) continue;
        if (!Rootfs.isReady) continue;
        // A saved set from before profiles existed names no profile, and reads
        // as "whichever is selected" — which is what it meant.
        final profileId = LocalSource.profileIdOf(id);
        // One that names a profile this device has not got is skipped like an
        // unknown server: a backup restored onto another device is exactly how
        // that happens.
        if (profileId != null &&
            !Rootfs.profiles.any((e) => e.id == profileId)) {
          continue;
        }
        source = LocalSource(rootfs: true, profileId: profileId);
      } else if (id == const LocalSource().id) {
        // A tab set saved on a desktop can be restored on a phone — the same
        // backup, the same account — and iOS has no shell to give. Skipped
        // like an unknown server below, rather than opening a tab that can
        // only fail when its pty is asked for.
        if (!LocalShellBackend.isSupported) continue;
        source = const LocalSource();
      } else {
        final spi = servers[id];
        if (spi == null) continue;
        source = ServerSource(spi);
      }
      // Tested rather than cast. `as String?` throws on a value that is
      // neither — a number where a name was expected — and the throw leaves the
      // loop, which is the whole-set abort the entry-by-entry reads above
      // exist to prevent.
      final tmuxSession = entry['tmuxSession'];
      final tmuxWindow = entry['tmuxWindow'];
      _open(
        source,
        tmuxSession: tmuxSession is String ? tmuxSession : null,
        tmuxWindow: tmuxWindow is int ? tmuxWindow : null,
        select: false,
      );
      restored++;
    }

    if (restored == 0) return;
    // One write for the whole restore, and only once the set is final.
    _saveTabs();
    // Nothing to land on means every restored tab was a local shell: stay on
    // the picker, where the rail lists them and one tap starts whichever was
    // wanted.
    final landOn = _firstTabToStart();
    if (landOn != null) _sessions.select(landOn);
  }
}

/// The buttons on the tab bar.
extension _Actions on _SSHTabPageState {
  /// The buttons for whichever terminal is showing.
  ///
  /// The agent's tools all name a server, so it is offered only on one.
  /// Snippets are offered everywhere: the picker leaves out the ones that
  /// mention a server when there is none.
  ///
  /// Read from the tab's arguments rather than its live state: a tab that has
  /// not been looked at yet has no state, and the buttons would flicker in as
  /// it built.
  List<Widget> get _serverActions {
    final current = _sessions.current;
    if (current == null) return const [];
    final onServer = current.data.page.args.spi != null;
    return onServer ? [_agentBtn, _snippetBtn] : [_snippetBtn];
  }

  /// Opens the agent on the terminal that is on screen, the same way the
  /// snippet picker beside it works.
  Widget get _agentBtn => Btn.icon(
    text: l10n.askAi,
    icon: const Icon(Icons.auto_awesome, size: 18),
    onTap: () =>
        _sessions.current?.data.pageKey.currentState?.openAgentFromToolbar(),
  );

  Widget get _snippetBtn => Btn.icon(
    text: libL10n.snippet,
    icon: const Icon(Icons.code, size: 18),
    onTap: () =>
        _sessions.current?.data.pageKey.currentState?.pickSnippetFromToolbar(),
  );

  Widget get _sortBtn => Btn.icon(
    text: libL10n.sort,
    icon: Icon(_SortOrder.stored.icon, size: 18),
    onTap: _showSortMenu,
  );

  Widget get _searchBtn => Btn.icon(
    text: libL10n.search,
    icon: const Icon(Icons.search, size: 18),
    onTap: _showSearch,
  );

  Widget get _historyBtn => Btn.icon(
    text: l10n.history,
    icon: const Icon(Icons.history, size: 18),
    onTap: _showHistory,
  );

  /// The rail's own way to add a server. On one screen that is the picker's
  /// floating button; a rail has no room for one.

  void _showSortMenu() {
    context.showRoundDialog(
      title: libL10n.sort,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final order in _SortOrder.all)
            _SortOptionTile(
              order: order,
              onTap: () {
                order.save();
                _sortVersion.notify();
                context.popDialog();
              },
            ),
        ],
      ),
    );
  }

  void _showSearch() {
    showSearch(
      context: context,
      delegate: SearchPage<Spi>(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        future: (query) async {
          if (query.isEmpty) return [];
          // Read per query rather than snapshotted when the dialog opened, so
          // a server added or renamed meanwhile is findable.
          final state = ref.read(serversProvider);
          final needle = query.toLowerCase();
          return [
            for (final id in state.serverOrder)
              if (state.servers[id] case final spi?)
                if (spi.name.toLowerCase().contains(needle) ||
                    spi.displayAddr.toLowerCase().contains(needle))
                  spi,
          ];
        },
        builder: (ctx, spi) => ListTile(
          leading: distIcon(spi.id, size: 22),
          title: Text(spi.name),
          subtitle: Text(spi.displayAddr),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ctx.pop();
            _openServer(spi);
          },
        ),
      ),
    );
  }

  void _showHistory() {
    final history = Stores.history.sshServerHistory.all.cast<String>();
    if (history.isEmpty) {
      context.showRoundDialog(
        title: l10n.serverHistory,
        child: Text(libL10n.empty),
        actions: [Btn.ok(onTap: context.popDialog)],
      );
      return;
    }

    final servers = ref.read(serversProvider).servers;
    context.showRoundDialog(
      title: l10n.serverHistory,
      child: SizedBox(
        width: 420,
        height: 300,
        child: ListView.builder(
          itemCount: history.length,
          itemBuilder: (_, index) {
            final id = history[index];
            final spi = servers[id];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              // A server can be deleted while its visits stay in the history.
              // Saying so beats a row that looks tappable and is not.
              enabled: spi != null,
              title: Text(spi?.name ?? id),
              subtitle: Text(spi?.displayAddr ?? libL10n.unknown),
              trailing: const Icon(Icons.chevron_right),
              onTap: spi == null
                  ? null
                  : () {
                      context.popDialog();
                      _openServer(spi);
                    },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Stores.history.sshServerHistory.clear();
            context.popDialog();
          },
          child: Text(libL10n.clearHistory),
        ),
        Btn.ok(onTap: context.popDialog),
      ],
    );
  }
}
