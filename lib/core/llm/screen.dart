import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/workspace/workspace.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/workspace.dart';

/// What the user has on screen, said to the Agent before their next message
/// whenever it changed (`LlmUi.appContext`): "this server" means the one they
/// are looking at, and a chat should not have to ask which one that is.
///
/// Read when a message is sent, never pushed: the tabs are kept alive behind
/// one another, so what is mounted says nothing about what is on screen.
abstract final class AgentScreen {
  static final _shown = <_AgentSubjectState>[];

  static ({Spi? spi})? Function()? _terminal;
  static ({Spi? spi, String? path})? Function()? _files;

  /// The terminal tab's current session: its server, or null for a terminal
  /// on this device; null while the tab shows its picker. The returned
  /// callback removes [current], and only it.
  static VoidCallback terminal(({Spi? spi})? Function() current) {
    _terminal = current;
    return () {
      if (identical(_terminal, current)) _terminal = null;
    };
  }

  /// The file tab's current session: its server (null for this device's
  /// files) and the directory it shows; null while the tab shows its picker.
  static VoidCallback files(({Spi? spi, String? path})? Function() current) {
    _files = current;
    return () {
      if (identical(_files, current)) _files = null;
    };
  }

  static String? describe(ChatMeta? meta) {
    // A terminal's chat is about its own server, which its prompt names, and
    // its tools take no server id.
    if (AgentScope.terminalServerOf(meta) != null) return null;
    final c = AgentScope.container;
    final tab = c.read(currentHomeTabProvider);
    if (tab == null) return null;

    // Newest first: a page pushed over another is the one on screen.
    final shown = _shown.reversed.where((s) => s._current).toList();
    // A route pushed over the tabs covers whichever one is current.
    if (shown.where((s) => s._tab == null).firstOrNull case final s?) {
      return 'On screen: ${s._describe()}.';
    }
    String? page() =>
        shown.where((s) => s._tab == tab).firstOrNull?._describe();

    final at = switch (tab) {
      // The Agent's own tab shows the chat, which says nothing about a
      // server; the last place it was told of still stands.
      AppTab.agent => null,
      // Every view of every workspace is mounted; the focused one is the
      // provider's to say.
      AppTab.workspace => _workspace(
        c.read(workspacesProvider).current,
        c.read(serversProvider).servers,
      ),
      AppTab.server => 'Server tab, ${page() ?? 'the list of servers'}',
      AppTab.ssh =>
        'Terminal tab, ${page() ?? switch (_terminal?.call()) {
          (:final spi?) => 'a terminal on ${_server(spi.id, spi)}',
          (spi: null) => 'a terminal on this device',
          null => 'picking a server to open',
        }}',
      AppTab.file =>
        'File tab, ${page() ?? switch (_files?.call()) {
          (:final spi?, :final path) => 'the files of ${_server(spi.id, spi)}${_in(path)}',
          (spi: null, :final path) => "this device's files${_in(path)}",
          null => 'picking a server to open',
        }}',
      _ => '${_tabName(tab)} tab${switch (page()) {
        final p? => ', $p',
        null => '',
      }}',
    };
    return at == null ? null : 'On screen: $at.';
  }

  static String _tabName(AppTab tab) => switch (tab) {
    AppTab.server => 'Server',
    AppTab.ssh => 'Terminal',
    AppTab.file => 'File',
    AppTab.snippet => 'Snippet',
    AppTab.agent => 'Agent',
    AppTab.benchmark => 'Benchmark',
    AppTab.remoteDesktop => 'Remote desktop',
    AppTab.virt => 'Virtualization',
    AppTab.workspace => 'Workspace',
  };

  static String _workspace(Workspace ws, Map<String, Spi> servers) {
    final t = ws.focused?.active;
    if (t == null) return 'Workspace "${ws.name}", empty';
    final view = switch (t.view) {
      WorkspaceView.term => 'a terminal',
      WorkspaceView.status => 'the status page',
      WorkspaceView.files => 'the files',
      WorkspaceView.agent => 'the Agent chat',
      WorkspaceView.docker => 'the containers',
      WorkspaceView.proc => 'the processes',
      WorkspaceView.systemd => 'the systemd services',
      WorkspaceView.snippet => 'the snippets',
    };
    return 'Workspace "${ws.name}", $view of ${_server(t.serverId, servers[t.serverId])}';
  }

  static String _server(String id, Spi? spi) =>
      'server "${spi?.name ?? id}" (server_id: $id)';

  static String _in(String? path) =>
      path == null || path.isEmpty ? '' : ' at $path';
}

/// The home tab a subtree is in: set around each tab's navigator, so a page
/// pushed inside the tab has it, and one pushed over the tabs does not.
class AgentScreenTab extends InheritedWidget {
  const AgentScreenTab({super.key, required this.tab, required super.child});

  final AppTab tab;

  @override
  bool updateShouldNotify(AgentScreenTab oldWidget) => tab != oldWidget.tab;
}

/// Marks [child] as showing [page] of [spi] to the Agent ([AgentScreen]),
/// while its route is the top one of its navigator.
class AgentSubject extends StatefulWidget {
  const AgentSubject({
    super.key,
    required this.page,
    required this.spi,
    required this.child,
  });

  /// What of the server is shown, as the model reads it: "the status page".
  final String page;
  final Spi spi;
  final Widget child;

  @override
  State<AgentSubject> createState() => _AgentSubjectState();
}

class _AgentSubjectState extends State<AgentSubject> {
  AppTab? _tab;

  /// Whether nothing is pushed over this page, as of its last build — which
  /// is every time that changes, as the route is a dependency.
  var _current = false;

  String _describe() =>
      '${widget.page} of ${AgentScreen._server(widget.spi.id, widget.spi)}';

  @override
  void initState() {
    super.initState();
    AgentScreen._shown.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tab = context.getInheritedWidgetOfExactType<AgentScreenTab>()?.tab;
  }

  @override
  void dispose() {
    AgentScreen._shown.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _current = ModalRoute.of(context)?.isCurrent ?? true;
    return widget.child;
  }
}
