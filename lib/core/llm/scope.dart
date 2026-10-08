import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';

/// Where an Agent chat belongs: the app-wide Agent's list, or one server's
/// terminal. Kept as [ChatMeta.scope], so each place lists only its own.
abstract final class AgentScope {
  /// The app's providers, for the tools: they run outside any widget. Set
  /// once, before the first frame — see `main`.
  static late final ProviderContainer container;

  static const _terminalPrefix = 'terminal:';

  /// The scope of the chats in the terminals of server [serverId].
  static String terminal(String serverId) => '$_terminalPrefix$serverId';

  /// The server whose terminal [meta]'s chat belongs to; null for the
  /// app-wide Agent's.
  static String? terminalServerOf(ChatMeta? meta) {
    final scope = meta?.scope;
    if (scope == null || !scope.startsWith(_terminalPrefix)) return null;
    return scope.substring(_terminalPrefix.length);
  }
}

/// What a terminal page hands the Agent: closures, never the terminal itself,
/// so a chat that outlives the page cannot reach a disposed controller.
final class TerminalHost {
  const TerminalHost({
    required this.serverName,
    required this.run,
    required this.insert,
    required this.screen,
    required this.programStatus,
    required this.cancel,
  });

  final String serverName;

  /// Runs a command on the terminal's connection, beside the shell.
  final Future<AskAiCommandResult> Function(AskAiCommand command) run;

  /// Types a command into the shell for the user to edit and run.
  final void Function(String command) insert;

  /// What the terminal shows now.
  final String Function() screen;

  /// What the terminal's programs report about themselves (OSC 7501, OSC 9;4,
  /// OSC 133), one line each; empty when nothing is reported.
  final String Function() programStatus;

  /// Stops the command [run] is waiting on.
  final Future<void> Function() cancel;
}

/// The terminal each server has open, for its chats' tools. Looked up per call:
/// a terminal opens and closes under chats that outlive both.
abstract final class TerminalHosts {
  /// Per server, every terminal of it that is open, newest last: closing the
  /// newest hands the chats back to the one before it rather than to none.
  static final _hosts = <String, List<TerminalHost>>{};

  /// Registers [host] for server [serverId]; the returned callback removes it,
  /// and only it — another terminal of the same server stays reachable.
  static void Function() register(String serverId, TerminalHost host) {
    (_hosts[serverId] ??= []).add(host);
    return () {
      final stack = _hosts[serverId];
      if (stack == null) return;
      stack.removeWhere((h) => identical(h, host));
      if (stack.isEmpty) _hosts.remove(serverId);
    };
  }

  /// The newest terminal of [serverId] still open.
  static TerminalHost? of(String serverId) => _hosts[serverId]?.lastOrNull;

  static TerminalHost? forChat(String chatId) => switch (AgentScope
      .terminalServerOf(LlmStores.chat.fetch(chatId))) {
    final id? => of(id),
    null => null,
  };
}

/// Which chat each place shows: the app-wide Agent's (a null scope) and each
/// server's terminal. One place can be on screen twice — the tab and the
/// floating shell — and both follow this.
abstract final class AgentChats {
  static final _current = <String?, ValueNotifier<String?>>{};

  /// The Agent's starts at the empty composer, a new chat; the history is a
  /// tap away. Starting at the newest chat had the floating window open over
  /// whatever the app launched to, showing a conversation nobody had asked
  /// for. A terminal's starts at its server's newest chat: that panel is
  /// about the one server, and picking up where it was left is the point.
  static ValueNotifier<String?> of(String? scope) => _current[scope] ??=
      ValueNotifier(
        scope == null
            ? null
            : LlmStores.chat.all(scope: scope).firstOrNull?.id,
      );

  /// Whether the Agent has had a chat to follow this run — one picked, or
  /// started by a message — or was sent floating on purpose. Until then its
  /// floating window stays away: there is nothing in it but a composer.
  ///
  /// Never cleared by a new chat after that, so "new chat" pressed in the
  /// floating window does not make the window vanish under the pointer.
  static final engaged = ValueNotifier(false);

  static void select(String? scope, String? id) {
    of(scope).value = id;
    if (scope == null && id != null) engaged.value = true;
    // What `Chats` keeps open while something else borrows a chat.
    if (id != null) Chats.current.value = id;
  }

  @visibleForTesting
  static void reset() {
    _current.clear();
    engaged.value = false;
  }

  /// The empty composer, for a new chat on the next message.
  static void startNew(String? scope) => select(scope, null);

  /// Whether [scope]'s chat is writing a reply or running a tool.
  static bool busy(String? scope) => switch (of(scope).value) {
    final id? => Chats.openOf(id)?.running.value ?? false,
    null => false,
  };

  /// Deletes every chat of [scope], trashed ones included: its server is gone.
  static Future<void> clearScope(String scope) async {
    for (final trashed in const [false, true]) {
      for (final meta in LlmStores.chat.all(scope: scope, trashed: trashed)) {
        await Chats.deleteForever(meta.id);
      }
    }
    select(scope, null);
  }

  /// Deletes chat [id] of [scope], and shows the next one if it was showing.
  static Future<void> delete(String? scope, String id) async {
    await Chats.deleteForever(id);
    if (of(scope).value == id) {
      select(scope, LlmStores.chat.all(scope: scope).firstOrNull?.id);
    }
  }
}
