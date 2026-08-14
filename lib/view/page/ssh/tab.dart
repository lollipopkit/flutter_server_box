import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/widget/pane_settings.dart';

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
      'serverId': live?.widget.args.spi.id ?? page.args.spi.id,
      'tmuxSession': live?.tmuxCurrentSession ?? page.args.tmuxSession,
      'tmuxWindow': live?.tmuxCurrentWindow ?? page.args.tmuxWindow,
    };
  }
}

class _SSHTabPageState extends ConsumerState<SSHTabPage>
    with AutomaticKeepAliveClientMixin, RestorationMixin {
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
      onTap: _open,
      onLongPress: (spi) =>
          ServerEditPage.route.go(context, args: SpiRequiredArgs(spi)),
    ),
    floatingActionButton: Builder(
      builder: (ctx) => FloatingActionButton(
        heroTag: 'sshAddServer',
        onPressed: () => ServerEditPage.route.go(ctx),
        tooltip: libL10n.add,
        child: const Icon(Icons.add),
      ),
    ),
  );

  final _restorableTabs = RestorableString('');

  @override
  String get restorationId => 'ssh_tab_page';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Anything queued before this tab existed. Tabs are built when first
    // visited, so a request made from the server list arrives while there is
    // nothing here to receive it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainRequests());
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restorableTabs, 'tabs_state');
    if (!initialRestore || _restorableTabs.value.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreTabs());
  }

  @override
  void dispose() {
    _restorableTabs.dispose();
    _sessions.dispose();
    _sortVersion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(terminalRequestsProvider, (_, _) => _drainRequests());
    return ListenBuilder(
      listenable: _sessions,
      builder: () => SbPaneList(
        // Nothing open yet means nothing for a column to sit beside, so the
        // picker keeps the whole width until the first terminal is opened —
        // the same as the server list before anything is selected.
        hasContent: _sessions.tabs.isNotEmpty,
        sideBuilder: (_) => _SideBar(
          sessions: _sessions,
          sortVersion: _sortVersion,
          actions: [_sortBtn, _searchBtn, _historyBtn, _addBtn],
          onOpen: _open,
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
      body: SessionTabsView<_SshSession>(
        controller: _sessions,
        // Page 0 is still the picker's, and while the rail is there nothing
        // can reach that page — building it would draw the same list twice.
        leading: split ? const SizedBox.shrink() : _picker,
        builder: (_, tab) => tab.data.page,
      ),
    );
  }

  PreferredSizeWidget get _tabBar => PreferredSizeListenBuilder(
    // Both: the bar shows which tab is current *and* how the picker behind it
    // is sorted.
    listenable: Listenable.merge([_sessions, _sortVersion]),
    builder: () => SessionTabBar(
      names: _sessions.names,
      index: _sessions.index,
      onTap: _sessions.select,
      onClose: _confirmClose,
      sessionActions: [_agentBtn, _snippetBtn],
      leadingActions: [_sortBtn, _searchBtn, _historyBtn],
    ),
  );

  PreferredSizeWidget get _sessionBar => PreferredSizeListenBuilder(
    listenable: _sessions,
    builder: () => CustomAppBar(
      title: Text(_sessions.current?.name ?? libL10n.terminal),
      actions: [_agentBtn, _snippetBtn, const SizedBox(width: 7)],
    ),
  );
}

/// Opening, closing and remembering terminals.
extension _Sessions on _SSHTabPageState {
  /// Opens a shell on [spi].
  ///
  /// [select] is off while restoring: selecting each tab as it arrives would
  /// animate through all of them and land on the last, which is not where
  /// anyone left off.
  void _open(
    Spi spi, {
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
      preferred: spi.name,
      build: (name, focus, visible) {
        final key = GlobalKey<SSHPageState>(debugLabel: name);
        return _SshSession(
          pageKey: key,
          page: SSHPage(
            key: key,
            args: SshPageArgs(
              spi: spi,
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
    Stores.history.sshServerHistory.add(spi.id);
    if (!select) return;
    _saveTabs();
    _sessions.select(_sessions.names.indexOf(tab.name));
  }

  Future<void> _confirmClose(int index) async {
    // Resolved now, while the position still means what the bar drew.
    final tab = _sessions.tabs.elementAtOrNull(index - 1);
    if (tab == null) return;

    final confirm = await contextSafe?.showRoundDialog(
      title: libL10n.attention,
      child: Text('${libL10n.close} SSH ${libL10n.conn}(${tab.name}) ?'),
      actions: Btnx.okReds,
    );
    if (confirm != true) return;
    // Only once the tab is actually going. Dropping focus on the way out of a
    // cancelled dialog took the keyboard from a terminal the user had just
    // decided to keep.
    if (mounted) FocusScope.of(context).unfocus();
    _closeTab(tab.id);
  }

  /// Opens everything queued for this tab and empties the queue.
  void _drainRequests() {
    final pending = ref.read(terminalRequestsProvider);
    if (pending.isEmpty) return;
    ref.read(terminalRequestsProvider.notifier).clear();
    for (final request in pending) {
      _open(request.spi, snippet: request.snippet, session: request.session);
    }
  }

  void _closeTab(String id) {
    _sessions.remove(id);
    if (mounted) _saveTabs();
  }

  void _saveTabs() {
    _restorableTabs.value = jsonEncode([
      for (final tab in _sessions.tabs) tab.data.toRestorable(),
    ]);
  }

  /// Reopens whatever was open when the app last went away.
  ///
  /// Each entry is read defensively and skipped on its own. This is the one
  /// path that runs against data an older build wrote, and a single malformed
  /// record used to abort the loop — taking every other terminal with it.
  void _restoreTabs() {
    final List<dynamic> entries;
    try {
      entries = jsonDecode(_restorableTabs.value) as List;
    } catch (e, st) {
      Loggers.app.warning('Unreadable SSH tab state', e, st);
      return;
    }

    // Read once, not once per tab.
    final servers = {for (final spi in Stores.server.fetch()) spi.id: spi};

    var restored = 0;
    for (final entry in entries) {
      if (entry is! Map) continue;
      final spi = servers[entry['serverId']];
      if (spi == null) continue;
      _open(
        spi,
        tmuxSession: entry['tmuxSession'] as String?,
        tmuxWindow: entry['tmuxWindow'] as int?,
        select: false,
      );
      restored++;
    }

    if (restored == 0) return;
    // One write for the whole restore, and only once the set is final.
    _saveTabs();
    _sessions.select(1);
  }
}

/// The buttons on the tab bar.
extension _Actions on _SSHTabPageState {
  /// Opens the agent on the terminal that is on screen, the same way the
  /// snippet picker beside it works.
  Widget get _agentBtn => Btn.icon(
    icon: const Icon(Icons.auto_awesome, size: 18),
    onTap: () =>
        _sessions.current?.data.pageKey.currentState?.openAgentFromToolbar(),
  );

  Widget get _snippetBtn => Btn.icon(
    icon: const Icon(Icons.code, size: 18),
    onTap: () =>
        _sessions.current?.data.pageKey.currentState?.pickSnippetFromToolbar(),
  );

  Widget get _sortBtn => Btn.icon(
    icon: Icon(_SortOrder.stored.icon, size: 18),
    onTap: _showSortMenu,
  );

  Widget get _searchBtn => Btn.icon(
    icon: const Icon(Icons.search, size: 18),
    onTap: _showSearch,
  );

  Widget get _historyBtn => Btn.icon(
    icon: const Icon(Icons.history, size: 18),
    onTap: _showHistory,
  );

  /// The rail's own way to add a server. On one screen that is the picker's
  /// floating button; a rail has no room for one.
  Widget get _addBtn => Btn.icon(
    icon: const Icon(Icons.add, size: 18),
    onTap: () => ServerEditPage.route.go(context),
  );

  void _showSortMenu() {
    context.showRoundDialog(
      title: l10n.sort,
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
          title: Text(spi.name),
          subtitle: Text(spi.displayAddr),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ctx.pop();
            _open(spi);
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
                      _open(spi);
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
          child: Text(l10n.clearHistory),
        ),
        Btn.ok(onTap: context.popDialog),
      ],
    );
  }
}
