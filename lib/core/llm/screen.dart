import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show ChatMeta;
import 'package:flutter/widgets.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/workspace/workspace.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/selection.dart';
import 'package:server_box/data/provider/workspace.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/page/storage/sftp.dart';

/// What the user has on screen, said to the Agent before their next message
/// whenever it changed (`LlmUi.appContext`): "this server" means the one they
/// are looking at, and a chat should not have to ask which one that is.
///
/// Read when a message is sent, never pushed: the tabs are kept alive behind
/// one another, so what is mounted says nothing about what is on screen.
///
/// Every navigator the user can be looking into is watched, so a page pushed
/// on any of them is seen without the page having to say so: it is described
/// by its route's path and arguments.
abstract final class AgentScreen {
  static final _root = _Routes();
  static final _settings = _Routes();
  static final _tabs = <AppTab, _Routes>{};
  static final _wsTabs = <String, _Routes>{};

  /// The app's own navigator: a page pushed there covers every tab.
  static NavigatorObserver get rootObserver => _root;

  /// The navigator of home tab [tab].
  static NavigatorObserver tabObserver(AppTab tab) =>
      _tabs[tab] ??= _Routes();

  /// The navigator of the settings shown in place of a tab.
  static NavigatorObserver get settingsObserver => _settings;

  /// The navigator of workspace tab [tabId].
  static NavigatorObserver workspaceObserver(String tabId) =>
      _wsTabs[tabId] ??= _Routes();

  /// Whether the settings are shown in place of the tabs, which go on being
  /// the current tab behind them.
  static var settingsOpen = false;

  static TerminalSource? Function()? _terminal;
  static String? Function()? _files;

  /// Where the terminal tab's current session comes from; null while the tab
  /// shows its picker. The returned callback removes [current], and only it.
  static VoidCallback terminal(TerminalSource? Function() current) {
    _terminal = current;
    return () {
      if (identical(_terminal, current)) _terminal = null;
    };
  }

  /// What the file tab shows, naming a server with [server]; null while it
  /// shows its picker. The returned callback removes [current], and only it.
  static VoidCallback files(String? Function() current) {
    _files = current;
    return () {
      if (identical(_files, current)) _files = null;
    };
  }

  static String? describe(ChatMeta? meta) {
    final tab = AgentScope.container.read(currentHomeTabProvider);
    if (tab == null) return null;
    final at = switch (tab) {
      _ when _root.above != null => _page(_root.above!),
      _ when settingsOpen => switch (_settings.above) {
        final r? => 'Settings, ${_page(r)}',
        null => 'Settings',
      },
      _ when _tabs[tab]?.above != null =>
        '${_tabName(tab)} tab, ${_page(_tabs[tab]!.above!)}',
      _ => _tabRoot(tab),
    };
    return at == null ? null : 'On screen: $at.';
  }

  /// What [tab] shows when nothing is pushed over it.
  static String? _tabRoot(AppTab tab) {
    final c = AgentScope.container;
    return switch (tab) {
      // The Agent's own tab shows the chat, which says nothing about a
      // server; the last place it was told of still stands.
      AppTab.agent => null,
      // Every view of every workspace is mounted; the focused one is the
      // provider's to say.
      AppTab.workspace => _workspace(c.read(workspacesProvider).current),
      // In place, in a wide window; a phone pushes the page instead.
      AppTab.server => switch (c.read(serverSelectionProvider)) {
        final id? => 'Server tab, the status page of ${_server(id)}',
        null => 'Server tab, the list of servers',
      },
      AppTab.ssh => switch (_terminal?.call()) {
        final source? => 'Terminal tab, ${_terminalOf(source)}',
        null => 'Terminal tab, picking a server to open',
      },
      AppTab.file =>
        'File tab, ${_files?.call() ?? 'picking a server to open'}',
      _ => '${_tabName(tab)} tab',
    };
  }

  static String _workspace(Workspace ws) {
    final t = ws.focused?.active;
    if (t == null) return 'Workspace "${ws.name}", empty';
    if (_wsTabs[t.id]?.above case final r?) {
      return 'Workspace "${ws.name}", ${_page(r)}';
    }
    return 'Workspace "${ws.name}", ${_views[t.view]} of ${_server(t.serverId)}';
  }

  /// [route]'s page: what its path is, and which server its arguments name.
  static String _page(Route<dynamic> route) {
    final path = route.settings.name;
    final page = _paths[path] ?? (path == null ? 'a page' : 'the page "$path"');
    return switch (route.settings.arguments) {
      SpiRequiredArgs(:final spi) => '$page of ${_server(spi.id)}',
      SftpPageArgs(:final spi) => '$page of ${_server(spi.id)}',
      SshPageArgs(:final source) => _terminalOf(source),
      _ => page,
    };
  }

  static String _terminalOf(TerminalSource source) => switch (source) {
    ServerSource(:final spi) => 'a terminal on ${_server(spi.id)}',
    LocalSource() => 'a terminal on this device',
    ConsoleSource(:final label) => 'the console of guest "$label"',
  };

  /// Pages by their route's path, where the path alone reads poorly.
  static const _paths = {
    '/servers/detail': 'the status page',
    '/servers/edit': 'the edit page',
    '/container': 'the containers',
    '/process': 'the processes',
    '/services': 'the systemd services',
    '/files/transfers': 'the transfer list',
    '/sftp': 'the files',
    '/files/server': 'the files',
    '/settings': 'the settings',
  };

  static const _views = {
    WorkspaceView.term: 'a terminal',
    WorkspaceView.status: 'the status page',
    WorkspaceView.files: 'the files',
    WorkspaceView.agent: 'the Agent chat',
    WorkspaceView.docker: 'the containers',
    WorkspaceView.proc: 'the processes',
    WorkspaceView.systemd: 'the systemd services',
    WorkspaceView.snippet: 'the snippets',
  };

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
    AppTab.monitor => 'Monitor',
  };

  /// [spi] as the model reads it.
  static String server(Spi spi) => _server(spi.id);

  /// Named as the server is now: a page keeps the `Spi` it was opened with,
  /// and the name may have changed since.
  static String _server(String id) {
    final name = AgentScope.container.read(serversProvider).servers[id]?.name;
    return 'server "${name ?? id}" (server_id: $id)';
  }
}

/// One navigator's routes, bottom first.
final class _Routes extends NavigatorObserver {
  final _routes = <Route<dynamic>>[];

  /// The page on top, unless it is the navigator's first: a dialog is over a
  /// page rather than in place of one, so only pages count.
  Route<dynamic>? get above {
    final pages = _routes.whereType<PageRoute<dynamic>>();
    if (pages.length < 2) return null;
    return pages.last;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final at = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (newRoute == null) {
      if (at >= 0) _routes.removeAt(at);
    } else if (at >= 0) {
      _routes[at] = newRoute;
    } else {
      _routes.add(newRoute);
    }
  }
}
