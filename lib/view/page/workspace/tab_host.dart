import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/model/workspace/workspace.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/provider/workspace.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/view/page/agent/view.dart';
import 'package:server_box/view/page/container/container.dart';
import 'package:server_box/view/page/process.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/services.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/page/ssh/snippet_run.dart';
import 'package:server_box/view/page/storage/server_file.dart';
import 'package:server_box/view/page/storage/sftp.dart';
import 'package:server_box/view/page/workspace/view_meta.dart';
import 'package:server_box/view/widget/actions_sink.dart';

/// What a tab holds while the app runs, beyond what is saved: the widget
/// state of its page, its focus, whether it is on screen.
///
/// Kept by the workspace tab rather than by the pane the tab is in, because a
/// tab moves between panes — dragged, or split off — and its page has to go
/// with it: [key] is what carries the subtree across.
final class WsTabRuntime {
  WsTabRuntime({this.handoff});

  /// A shell another page handed over, for a terminal tab to show instead of
  /// opening its own — see `Workspaces.adoptSession`.
  final TerminalSession? handoff;

  final key = GlobalKey();
  final focus = FocusNode();

  /// Whether the tab is what the user is looking at: its workspace current,
  /// its pane laid out, and it the pane's active tab.
  final visible = ValueNotifier(false);

  /// The page's buttons, for the pane's bar.
  final ActionsSink actions = ValueNotifier(const []);

  /// A terminal tab's session, once its page has made one.
  final session = ValueNotifier<TerminalSession?>(null);

  final sshKey = GlobalKey<SSHPageState>();

  /// Whether the page has been built. A tab is built the first time it is
  /// shown, so a workspace of a dozen tabs does not start a dozen pages.
  bool built = false;

  WsTabHost? _host;

  /// The tab's host, the same instance for as long as nothing it is built
  /// from changes.
  ///
  /// Any change to a workspace — a tab selected, a ratio dragged — rebuilds
  /// every pane, and a fresh host each time rebuilt every page under it too:
  /// a status page redrawing its charts because a tab two panes away was
  /// clicked. An identical widget is one Flutter does not rebuild; what the
  /// page shows of its server it watches for itself.
  WsTabHost host(WsTab tab, String paneId) {
    final h = _host;
    if (h != null &&
        h.paneId == paneId &&
        h.tab.live == tab.live &&
        h.tab.view == tab.view &&
        h.tab.serverId == tab.serverId) {
      return h;
    }
    return _host = WsTabHost(tab: tab, paneId: paneId, runtime: this);
  }

  void dispose() {
    focus.dispose();
    visible.dispose();
    actions.dispose();
    session.dispose();
  }
}

/// The states in which a server has a connection a tab can use.
const _connected = {ServerConn.connected, ServerConn.loading, ServerConn.finished};

/// One tab's page, or what stands in for it before it is connected.
class WsTabHost extends ConsumerWidget {
  const WsTabHost({
    super.key,
    required this.tab,
    required this.paneId,
    required this.runtime,
  });

  final WsTab tab;
  final String paneId;
  final WsTabRuntime runtime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spi = ref.watch(serverProvider(tab.serverId).select((s) => s.spi));
    if (!tab.live) {
      // Connected from somewhere else — the server tab, by hand — is the
      // answer the button here would have asked for.
      final up = ref.watch(
        serverProvider(tab.serverId).select((s) => _connected.contains(s.conn)),
      );
      if (up) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(workspacesProvider.notifier).wake(tab.serverId),
        );
      }
      return _Dormant(tab: tab, spi: spi);
    }
    final reason = tab.view.unavailableOn(
      spi,
      ref.watch(serverProvider(tab.serverId).select((s) => s.remoteAccess)),
    );
    if (reason != null) {
      return Center(
        child: EmptyPane(icon: tab.view.icon, label: reason),
      );
    }
    // A navigator per tab: a page pushed from one — a container's logs, a
    // file opened for editing — covers its pane and nothing else, and the
    // back gesture closes it there.
    return NestedNavigator(
      rootId: tab.id,
      rootBuilder: (_) => _page(ref, spi),
    );
  }

  Widget _page(WidgetRef ref, Spi spi) {
    final args = SpiRequiredArgs(spi);
    return switch (tab.view) {
      WorkspaceView.term => SSHPage(
        key: runtime.sshKey,
        args: SshPageArgs(
          source: ServerSource(spi),
          session: runtime.handoff,
          onSession: (session) => runtime.session.value = session,
          notFromTab: false,
          onSessionEnd: () => ref
              .read(workspacesProvider.notifier)
              .closeTab(paneId, tab.id),
          focusNode: runtime.focus,
          visibleListenable: runtime.visible,
          // Per tab: two shells on one server would otherwise share one
          // restoration bucket.
          restorationId: 'ws_${tab.id}',
          homeTab: AppTab.workspace,
        ),
      ),
      WorkspaceView.status => Material(
        type: MaterialType.canvas,
        child: ServerDetailPage(args: args, bare: true),
      ),
      WorkspaceView.files => ServerFilePage(
        args: SftpPageArgs(spi: spi, actionsSink: runtime.actions),
      ),
      WorkspaceView.agent => AgentConversationView(
        scope: AgentScope.terminal(spi.id),
        compact: true,
      ),
      WorkspaceView.docker => ContainerPage(
        args: args,
        actionsSink: runtime.actions,
      ),
      WorkspaceView.proc => ProcessPage(
        args: args,
        actionsSink: runtime.actions,
      ),
      WorkspaceView.systemd => ServicesPage(
        args: args,
        actionsSink: runtime.actions,
      ),
      WorkspaceView.snippet => _SnippetView(spi: spi, paneId: paneId),
    };
  }
}

/// A tab back from a relaunch, waiting to be asked to connect.
class _Dormant extends ConsumerWidget {
  const _Dormant({required this.tab, required this.spi});

  final WsTab tab;
  final Spi spi;

  /// Every tab of this server, and its status polling with them: the pages
  /// that read the polled state — status — have nothing to show until it
  /// runs, and one asked to connect should not wait for the next round.
  void _wake(WidgetRef ref) {
    ref.read(workspacesProvider.notifier).wake(tab.serverId);
    TryLimiter.reset(spi.id);
    ref.read(serversProvider.notifier).refresh(spi: spi);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(17),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyPane(
              icon: Icons.link_off,
              label: l10n.workspaceNotConnected(spi.name),
            ),
            Text(
              l10n.workspaceConnectHint,
              textAlign: TextAlign.center,
              style: UIs.text12Grey,
            ),
            UIs.height13,
            FilledButton.tonalIcon(
              onPressed: () => _wake(ref),
              icon: const Icon(Icons.link),
              label: Text(l10n.connect),
            ),
          ],
        ),
      ),
    );
  }
}

/// The snippets, to run on this tab's server.
///
/// Run the way the server page runs one — in a dialog over the page — and
/// carried on, when asked, as a terminal tab beside this one.
class _SnippetView extends ConsumerWidget {
  const _SnippetView({required this.spi, required this.paneId});

  final Spi spi;
  final String paneId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snippets = ref.watch(snippetProvider.select((s) => s.snippets));
    if (snippets.isEmpty) {
      return Center(
        child: EmptyPane(icon: Icons.code, label: libL10n.empty),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(9),
      itemCount: snippets.length,
      itemBuilder: (context, i) {
        final s = snippets[i];
        return CardX(
          child: ListTile(
            leading: const Icon(Icons.code),
            title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              s.script.trim().split('\n').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: UIs.text12Grey,
            ),
            onTap: () async {
              final session = await showSnippetRun(
                context,
                ref,
                spi: spi,
                snippet: s,
              );
              if (session == null) return;
              ref
                  .read(workspacesProvider.notifier)
                  .addTab(
                    paneId,
                    WorkspaceView.term,
                    spi.id,
                    session: session,
                  );
            },
          ),
        );
      },
    );
  }
}
