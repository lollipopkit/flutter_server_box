import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:server_box/data/model/ai/agent_conversation_replay.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/provider/ai/agent_scope.dart';
import 'package:server_box/data/provider/ai/agent_session.dart';
import 'package:server_box/data/provider/ai/ask_ai.dart';
import 'package:server_box/data/provider/ai/global_agent_tools.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/agent_conversation.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

/// The two Agent surfaces run one loop, and this is the seam that lets them.
///
/// [AgentSession] is keyed by scope and asks [AgentScopeHost] for the four
/// things that differ. These are about that: that a terminal's session sends
/// what a terminal should send and stores what a terminal stored before this
/// merge, and that the two encodings never cross.
void main() {
  const proposal = AskAiCommand(
    id: 'call-1',
    command: 'uptime',
    description: 'Inspect uptime',
    toolName: 'run_shell_command',
  );

  late Directory tempDir;
  late AgentConversationStore conversationStore;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-agent-scope-');
    await openTestDb();
    await getIt.reset();
    getIt.registerSingleton<SettingStore>(SettingStore.forTest()..init());
    getIt.registerSingleton<ServerStore>(ServerStore.forTest());
    conversationStore = AgentConversationStore.forTest();
    getIt.registerSingleton<AgentConversationStore>(conversationStore);
  });

  tearDownAll(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  /// Lets a turn arrive.
  ///
  /// `submitPrompt` starts the stream and returns; the events reach the
  /// session on later microtasks, and the views that read it are rebuilt by
  /// the state changing rather than by that future completing.
  Future<void> settle() => pumpEventQueue();

  /// A container whose one turn hands back [proposal] for review.
  ({ProviderContainer container, _ProposingRepository repository}) harness() {
    final repository = _ProposingRepository(proposal);
    final container = ProviderContainer(
      overrides: [askAiRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return (container: container, repository: repository);
  }

  /// A terminal that answers, and a record of what it was asked.
  ({TerminalAgentHost host, List<String> ran, List<String> inserted}) terminal({
    String context = r'user@web-1:~$ ',
    AskAiCommandResult? result,
  }) {
    final ran = <String>[];
    final inserted = <String>[];
    return (
      host: TerminalAgentHost(
        serverName: 'web-1',
        readContext: () => context,
        run: (command) async {
          ran.add(command.command);
          return result ??
              AskAiCommandResult(
                command: command.command,
                exitCode: 0,
                stdout: 'up 3 days',
                stderr: '',
                duration: const Duration(milliseconds: 12),
              );
        },
        insert: inserted.add,
        cancel: () async {},
      ),
      ran: ran,
      inserted: inserted,
    );
  }

  test('a terminal session sends the terminal, and only the shell tool', () async {
    final h = harness();
    final t = terminal(context: 'df -h\n/dev/disk1s1  92% /');
    h.container.read(agentScopeHostsProvider).register('srv-a', t.host);

    await h.container
        .read(agentSessionProvider('srv-a').notifier)
        .submitPrompt('why is the disk full');
    await settle();

    expect(h.repository.terminalContext, contains('92%'));
    expect(h.repository.serverName, 'web-1');
    expect(h.repository.tools, [AskAiToolDefinition.runShellCommand]);
    // The terminal is the context and is already being sent; a second
    // description of the machine would be the app-wide Agent's prompt on a
    // surface that is not it.
    expect(h.repository.customInstructions, isNull);
  });

  test('the terminal is read per turn, not captured when the panel opened', () async {
    final h = harness();
    var screen = 'first screen';
    final host = TerminalAgentHost(
      serverName: 'web-1',
      readContext: () => screen,
      run: (_) async => throw StateError('not reached'),
      insert: (_) {},
      cancel: () async {},
    );
    h.container.read(agentScopeHostsProvider).register('srv-b', host);
    final notifier = h.container.read(agentSessionProvider('srv-b').notifier);

    await notifier.submitPrompt('what is this');

    await settle();
    expect(h.repository.terminalContext, 'first screen');

    screen = 'second screen';
    await notifier.declinePendingTool();
    await settle();
    expect(
      h.repository.terminalContext,
      'second screen',
      reason: 'a session outlives the panel, so the screen it opened on is gone',
    );
  });

  test('an approved command is stored the way a terminal has always stored it', () async {
    final h = harness();
    final t = terminal();
    h.container.read(agentScopeHostsProvider).register('srv-c', t.host);
    final notifier = h.container.read(agentSessionProvider('srv-c').notifier);

    await notifier.submitPrompt('check uptime');

    await settle();
    await notifier.runPendingTool();
    await settle();

    expect(t.ran, ['uptime']);
    final state = h.container.read(agentSessionProvider('srv-c'));
    final entry = state.timeline.whereType<AgentShellResultEntry>().single;
    expect(entry.result.stdout, 'up 3 days');

    // The output the model reads next turn. A terminal Agent writes a shell
    // result, and the app-wide Agent's marked encoding stays out of it —
    // conversations written before the merge are read back through the same
    // decoder.
    final output = state.history.whereType<AskAiFunctionOutputItem>().single;
    expect(AgentToolExecutionResult.tryFromToolMessage(output.output), isNull);
    expect(
      AskAiCommandResult.tryFromToolMessage(
        output.output,
        fallbackCommand: 'uptime',
      )?.stdout,
      'up 3 days',
    );
  });

  test('a command approved after the terminal closed says so, and does not throw', () async {
    final h = harness();
    final t = terminal();
    final hosts = h.container.read(agentScopeHostsProvider)
      ..register('srv-d', t.host);
    final notifier = h.container.read(agentSessionProvider('srv-d').notifier);
    await notifier.submitPrompt('check uptime');
    await settle();

    // The tab is closed while the proposal is on screen. The conversation is
    // stored and survives; the terminal it was about does not.
    hosts.unregister('srv-d', t.host);
    await notifier.runPendingTool();
    await settle();

    expect(t.ran, isEmpty);
    final entry = h.container
        .read(agentSessionProvider('srv-d'))
        .timeline
        .whereType<AgentShellResultEntry>()
        .single;
    expect(entry.result.succeeded, isFalse);
    expect(entry.result.stderr, contains('closed'));
  });

  group('insertPendingTool', () {
    test('puts the command on the terminal and ends the turn there', () async {
      final h = harness();
      final t = terminal();
      h.container.read(agentScopeHostsProvider).register('srv-e', t.host);
      final notifier = h.container.read(agentSessionProvider('srv-e').notifier);
      await notifier.submitPrompt('check uptime');
      await settle();
      final turnsBefore = h.repository.calls;

      expect(await notifier.insertPendingTool(), isTrue);

      await settle();
      expect(t.inserted, ['uptime']);

      final state = h.container.read(agentSessionProvider('srv-e'));
      expect(state.pendingTool, isNull);
      expect(
        state.timeline.whereType<AgentNoticeEntry>().single.kind,
        AgentNoticeKind.inserted,
      );
      // No new turn, unlike declining: whether the command runs at all is the
      // user's now, and the model has no result to react to.
      expect(h.repository.calls, turnsBefore);
      expect(
        decodeAgentConversationToolAction(
          state.history.whereType<AskAiFunctionOutputItem>().single.output,
        ),
        AgentConversationToolAction.inserted,
      );
    });

    test('is refused where there is no input line to put it on', () async {
      final h = harness();
      final notifier = h.container.read(
        agentSessionProvider(globalAgentConversationScope).notifier,
      );
      await notifier.submitPrompt('check uptime');
      await settle();

      expect(await notifier.insertPendingTool(), isFalse);
      await settle();
      expect(
        h.container.read(globalAgentSessionProvider).pendingTool,
        isNotNull,
        reason: 'refusing to insert must not also drop the proposal',
      );
    });
  });

  test('two tabs on one server: the first closing does not detach the second', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final hosts = container.read(agentScopeHostsProvider);
    final first = terminal().host;
    final second = terminal().host;

    hosts
      ..register('srv-f', first)
      ..register('srv-f', second)
      ..unregister('srv-f', first);

    expect(identical(hosts['srv-f'], second), isTrue);
  });
}

/// Answers every turn with one tool call awaiting review.
class _ProposingRepository extends AskAiRepository {
  _ProposingRepository(this.proposal);

  final AskAiCommand proposal;
  int calls = 0;
  String? terminalContext;
  String? serverName;
  String? customInstructions;
  List<AskAiToolDefinition>? tools;

  @override
  Stream<AskAiEvent> ask({
    required String terminalContext,
    required String serverName,
    String? localeHint,
    List<AskAiConversationItem> conversation = const [],
    AskAiProtocol? protocol,
    String? customInstructions,
    List<AskAiToolDefinition> tools = const [
      AskAiToolDefinition.runShellCommand,
    ],
  }) {
    calls++;
    this.terminalContext = terminalContext;
    this.serverName = serverName;
    this.customInstructions = customInstructions;
    this.tools = tools;
    return Stream.fromIterable([
      AskAiCompleted(
        fullText: 'Let me look.',
        commands: [proposal],
        outputItems: [
          const AskAiMessageItem.assistant('Let me look.'),
          AskAiFunctionCallItem(command: proposal),
        ],
        protocol: protocol ?? AskAiProtocol.chatCompletions,
      ),
    ]);
  }
}
