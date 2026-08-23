import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/provider/ai/global_agent_tools.dart';
import 'package:server_box/data/provider/server/all.dart';

part 'agent_scope.g.dart';

/// What one Agent surface has that another does not.
///
/// There are two surfaces and they run the same turn: the same request, the
/// same events, the same state machine, the same storage. What separates them
/// is which machine the conversation is about, what the model may do, and who
/// carries out an approved proposal — and that is all of it. Everything on
/// this interface is one of those, so a surface is a value rather than a
/// second copy of the loop.
abstract interface class AgentScopeHost {
  /// The machine the model is told it is working on.
  String get serverName;

  /// What is on the terminal right now, or empty where there is no terminal.
  ///
  /// Read at the start of each turn rather than stored: a session outlives the
  /// panel that opened it, and the screen it was opened on has scrolled since.
  String get terminalContext;

  /// The system prompt this surface adds, or null for none.
  String? buildInstructions({String? localeHint});

  /// What the model is allowed to ask for here.
  List<AskAiToolDefinition> get tools;

  Future<AgentRunResult> execute(AskAiCommand proposal);

  /// What [execute] throwing looks like as a result.
  ///
  /// The session cannot build this itself without knowing which encoding this
  /// surface writes, and a failure recorded in the other one is a turn the
  /// model reads as something else entirely.
  AgentRunResult describeFailure(AskAiCommand proposal, Object error);

  /// Puts [command] where the user can run it themselves, and says whether
  /// there was anywhere to put it.
  ///
  /// A terminal has an input line; the app-wide Agent has no such place, which
  /// is why this answers rather than assuming one.
  bool insert(String command);

  Future<void> cancelCurrent();
}

/// The outcome of running a proposal, in the two forms the app stores.
///
/// Two rather than one because the encoding is protocol: it is what the model
/// reads as the tool's output on the next turn, and conversations written by
/// earlier releases are still replayed through it. A shell result stays a
/// shell result.
@immutable
sealed class AgentRunResult {
  const AgentRunResult();

  /// What the model is told, verbatim.
  String toToolMessage();

  bool get cancelled;
}

final class AgentToolRun extends AgentRunResult {
  const AgentToolRun(this.result);

  final AgentToolExecutionResult result;

  @override
  String toToolMessage() => result.toToolMessage();

  @override
  bool get cancelled => result.cancelled;
}

final class AgentShellRun extends AgentRunResult {
  const AgentShellRun(this.result);

  final AskAiCommandResult result;

  @override
  String toToolMessage() => result.toToolMessage();

  @override
  bool get cancelled => result.cancelled;
}

/// The whole app, reached through [GlobalAgentToolService].
final class _GlobalAgentHost implements AgentScopeHost {
  const _GlobalAgentHost(this._tools);

  final GlobalAgentToolService _tools;

  /// Not a machine's name: these tools name their own target, and several of
  /// them reach more than one server in a turn.
  @override
  String get serverName => 'ServerBox';

  @override
  String get terminalContext => '';

  @override
  String? buildInstructions({String? localeHint}) =>
      _tools.buildInstructions(localeHint: localeHint);

  @override
  List<AskAiToolDefinition> get tools => globalAgentToolDefinitions;

  @override
  Future<AgentRunResult> execute(AskAiCommand proposal) async =>
      AgentToolRun(await _tools.execute(proposal));

  @override
  AgentRunResult describeFailure(AskAiCommand proposal, Object error) =>
      AgentToolRun(
        AgentToolExecutionResult(
          toolName: proposal.toolName,
          serverId: proposal.serverId,
          summary: 'The tool failed to run.',
          succeeded: false,
          duration: Duration.zero,
          localFailure: true,
          data: {'error': error.toString()},
        ),
      );

  /// Nowhere: this Agent is not attached to any one input line.
  @override
  bool insert(String command) => false;

  @override
  Future<void> cancelCurrent() => _tools.cancelCurrent();
}

/// One terminal, held by the page that owns the pty.
///
/// A proposal here runs in the session the user is looking at, so it inherits
/// that shell's directory, environment and privileges — which is the reason
/// this surface exists at all, and the reason its only tool is a shell
/// command. The page hands over closures rather than the terminal itself: the
/// session must not be able to outlive its way into a disposed controller.
final class TerminalAgentHost implements AgentScopeHost {
  const TerminalAgentHost({
    required this.serverName,
    required String Function() readContext,
    required Future<AskAiCommandResult> Function(AskAiCommand command) run,
    required void Function(String command) insert,
    required Future<void> Function() cancel,
  }) : _readContext = readContext,
       _run = run,
       _insert = insert,
       _cancel = cancel;

  @override
  final String serverName;

  final String Function() _readContext;
  final Future<AskAiCommandResult> Function(AskAiCommand command) _run;
  final void Function(String command) _insert;
  final Future<void> Function() _cancel;

  @override
  String get terminalContext => _readContext();

  /// None: the shell is the context, and it is already being sent.
  @override
  String? buildInstructions({String? localeHint}) => null;

  @override
  List<AskAiToolDefinition> get tools =>
      const [AskAiToolDefinition.runShellCommand];

  @override
  Future<AgentRunResult> execute(AskAiCommand proposal) async =>
      AgentShellRun(await _run(proposal));

  @override
  AgentRunResult describeFailure(AskAiCommand proposal, Object error) =>
      AgentShellRun(
        AskAiCommandResult(
          command: proposal.command,
          // `toString`, not the app's sentence for it: this is the tool output
          // the model reads on the next turn, and it is the same field a real
          // command's stderr arrives in. The view has its own line for the
          // reader, chosen in the reader's language.
          stderr: error.toString(),
          stdout: '',
          duration: Duration.zero,
        ),
      );

  @override
  bool insert(String command) {
    _insert(command);
    return true;
  }

  @override
  Future<void> cancelCurrent() => _cancel();
}

/// A terminal Agent whose terminal is gone.
///
/// The conversation survives the tab being closed — it is stored, and reopening
/// that server picks it up where it stopped. What cannot survive is running
/// anything, so this answers the way a failed command does rather than
/// throwing: the model is told, in the same shape it reads every other result,
/// and the turn ends instead of the session breaking.
final class _DetachedTerminalHost implements AgentScopeHost {
  const _DetachedTerminalHost(this.serverName);

  @override
  final String serverName;

  @override
  String get terminalContext => '';

  @override
  String? buildInstructions({String? localeHint}) => null;

  @override
  List<AskAiToolDefinition> get tools =>
      const [AskAiToolDefinition.runShellCommand];

  @override
  Future<AgentRunResult> execute(AskAiCommand proposal) async => AgentShellRun(
    AskAiCommandResult(
      command: proposal.command,
      // English, like every other `summary` here: the model reads it. The app
      // renders a failed command from the fields, not from this line.
      stderr: 'The terminal this command was for has been closed.',
      stdout: '',
      duration: Duration.zero,
    ),
  );

  @override
  AgentRunResult describeFailure(AskAiCommand proposal, Object error) =>
      AgentShellRun(
        AskAiCommandResult(
          command: proposal.command,
          stderr: error.toString(),
          stdout: '',
          duration: Duration.zero,
        ),
      );

  @override
  bool insert(String command) => false;

  @override
  Future<void> cancelCurrent() async {}
}

/// Which [AgentScopeHost] each scope has, right now.
///
/// A plain object rather than a provider holding a map, for two reasons. The
/// page registers from `initState`, and modifying a provider during a build is
/// not allowed. And the answer must not be cached: a terminal opens and closes
/// under a session that outlives both, so the lookup happens per use.
@Riverpod(keepAlive: true)
AgentScopeHosts agentScopeHosts(Ref ref) => AgentScopeHosts(ref);

class AgentScopeHosts {
  AgentScopeHosts(this._ref);

  final Ref _ref;
  final _terminals = <String, TerminalAgentHost>{};

  void register(String serverId, TerminalAgentHost host) {
    _terminals[serverId] = host;
  }

  /// Removes [host] only if it is still the registered one — two tabs on the
  /// same server register in turn, and the first one closing must not detach
  /// the second.
  void unregister(String serverId, TerminalAgentHost host) {
    if (!identical(_terminals[serverId], host)) return;
    _terminals.remove(serverId);
  }

  AgentScopeHost operator [](String scope) {
    if (scope == globalAgentConversationScope) {
      return _GlobalAgentHost(_ref.read(globalAgentToolServiceProvider));
    }
    final attached = _terminals[scope];
    if (attached != null) return attached;
    // Named from the server list rather than from the page that is gone, so a
    // conversation resumed from storage still says which machine it is about.
    final name = _ref.read(serversProvider).servers[scope]?.name;
    return _DetachedTerminalHost(name ?? scope);
  }
}
