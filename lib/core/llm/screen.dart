import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/workspace/workspace.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/selection.dart';
import 'package:server_box/data/provider/workspace.dart';

/// What the user has on screen, said to the Agent before their next message
/// whenever it changed (`LlmUi.appContext`): "this server" means the one they
/// are looking at, and a chat should not have to ask which one that is.
///
/// Read when a message is sent, never pushed: the tabs are kept alive behind
/// one another, so what is mounted says nothing about what is on screen.
abstract final class AgentScreen {
  /// The terminal tab's current session: its server, or null for a terminal
  /// on this device. Null while the tab shows its picker. Set by the tab.
  static ({Spi? spi})? Function() terminal = () => null;

  /// The file tab's current session: its server (null for this device's
  /// files) and the directory it shows. Null while the tab shows its picker.
  /// Set by the tab.
  static ({Spi? spi, String? path})? Function() files = () => null;

  static String? describe(ChatMeta? meta) {
    final c = AgentScope.container;
    final tab = c.read(currentHomeTabProvider);
    final at = switch (tab) {
      null => null,
      // The Agent's own tab shows the chat, which says nothing about a
      // server; the last place it was told of still stands.
      AppTab.agent => null,
      AppTab.server => switch (c.read(serverSelectionProvider)) {
        final id? => 'Server tab, the status page of ${_server(id, c.read(serversProvider).servers[id])}',
        null => 'Server tab, the list of servers',
      },
      AppTab.ssh => switch (terminal()) {
        (:final spi?) => 'Terminal tab, a terminal on ${_server(spi.id, spi)}',
        (spi: null) => 'Terminal tab, a terminal on this device',
        null => 'Terminal tab, picking a server to open',
      },
      AppTab.file => switch (files()) {
        (:final spi?, :final path) => 'File tab, the files of ${_server(spi.id, spi)}${_in(path)}',
        (spi: null, :final path) => "File tab, this device's files${_in(path)}",
        null => 'File tab, picking a server to open',
      },
      AppTab.workspace => _workspace(c.read(workspacesProvider).current, c.read(serversProvider).servers),
      _ => '${tab.name} tab',
    };
    return at == null ? null : 'On screen: $at.';
  }

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
