import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:server_box/data/model/ai/agent_conversation_replay.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/provider/ai/agent_session.dart';
import 'package:server_box/data/provider/ai/ask_ai.dart';
import 'package:server_box/data/provider/ai/global_agent_tools.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/agent_conversation.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

void main() {
  const shellCommand = AskAiCommand(
    id: 'call-shell',
    command: 'uptime',
    description: 'Inspect uptime',
    toolName: 'run_shell_command',
    rawArguments: '{"server_id":"srv","command":"uptime","safe_to_run":true}',
    modelSafeToRun: true,
  );
  const declinedCommand = AskAiCommand(
    id: 'call-declined',
    command: 'systemctl restart nginx',
    description: 'Restart nginx',
    toolName: 'run_shell_command',
  );
  const pendingCommand = AskAiCommand(
    id: 'call-pending',
    command: 'df -h',
    description: 'Inspect disk usage',
    toolName: 'run_shell_command',
  );

  group('replayAgentTimeline', () {
    test('replays messages, tool results, declines and the pending call', () {
      const result = AgentToolExecutionResult(
        toolName: 'run_shell_command',
        serverId: 'srv',
        summary: 'Command exited with code 0.',
        succeeded: true,
        duration: Duration(milliseconds: 25),
        data: {'stdout': 'up 3 days', 'exit_code': 0},
      );
      final replay = replayAgentTimeline([
        const AskAiMessageItem.user('Check the server.'),
        const AskAiReasoningItem(rawResponseItem: {'type': 'reasoning'}),
        const AskAiMessageItem.assistant('I will inspect it.'),
        const AskAiFunctionCallItem(command: shellCommand),
        AskAiFunctionOutputItem(
          callId: shellCommand.id,
          output: result.toToolMessage(),
        ),
        const AskAiFunctionCallItem(command: declinedCommand),
        AskAiFunctionOutputItem(
          callId: declinedCommand.id,
          output: encodeAgentConversationToolAction(
            AgentConversationToolAction.declined,
          ),
        ),
        const AskAiFunctionCallItem(command: pendingCommand),
      ]);

      expect(replay.entries.map((entry) => entry.runtimeType.toString()), [
        'AgentUserEntry',
        'AgentAssistantEntry',
        'AgentToolResultEntry',
        'AgentNoticeEntry',
      ]);
      final toolEntry = replay.entries[2] as AgentToolResultEntry;
      expect(toolEntry.proposal.id, shellCommand.id);
      expect((toolEntry.result.data! as Map)['stdout'], 'up 3 days');
      expect(
        (replay.entries[3] as AgentNoticeEntry).kind,
        AgentNoticeKind.declined,
      );
      expect(replay.pending.single.id, pendingCommand.id);
    });

    test('carries no localized text, only the reason for a notice', () {
      final replay = replayAgentTimeline([
        const AskAiFunctionCallItem(command: declinedCommand),
        AskAiFunctionOutputItem(
          callId: declinedCommand.id,
          output: encodeAgentConversationToolAction(
            AgentConversationToolAction.declined,
          ),
        ),
      ]);

      // A `String` here would be a sentence chosen when the decline happened,
      // which is what this refactor exists to remove.
      expect(replay.entries.single, isA<AgentNoticeEntry>());
    });

    test('renders unparsable function output as a raw notice', () {
      final replay = replayAgentTimeline([
        const AskAiFunctionCallItem(command: pendingCommand),
        const AskAiFunctionOutputItem(
          callId: 'call-pending',
          output: 'remote runner returned an unknown response',
        ),
      ]);

      expect(
        (replay.entries.single as AgentRawNoticeEntry).text,
        contains('remote runner returned an unknown response'),
      );
      expect(replay.pending, isEmpty);
    });

    test('matches duplicate call IDs in arrival order', () {
      const first = AskAiCommand(id: 'duplicate', command: 'uptime');
      const second = AskAiCommand(id: 'duplicate', command: 'df -h');
      const result = AgentToolExecutionResult(
        toolName: 'run_shell_command',
        summary: 'Command exited with code 0.',
        succeeded: true,
        duration: Duration.zero,
      );
      final replay = replayAgentTimeline([
        const AskAiFunctionCallItem(command: first),
        AskAiFunctionOutputItem(
          callId: first.id,
          output: result.toToolMessage(),
        ),
        const AskAiFunctionCallItem(command: second),
      ]);

      expect(
        (replay.entries.single as AgentToolResultEntry).proposal.command,
        'uptime',
      );
      expect(replay.pending.single.command, 'df -h');
    });

    test('a summary shows on the page, with the turns it stands for', () {
      const result = AgentToolExecutionResult(
        toolName: 'run_shell_command',
        summary: 'Command exited with code 0.',
        succeeded: true,
        duration: Duration.zero,
      );
      final replay = replayAgentTimeline([
        const AskAiMessageItem.user('Check the server.'),
        const AskAiFunctionCallItem(command: shellCommand),
        AskAiFunctionOutputItem(
          callId: shellCommand.id,
          output: result.toToolMessage(),
        ),
        const AskAiSummaryItem(summary: 'Goal: check a server.'),
        const AskAiMessageItem.user('And now?'),
      ]);

      // The summarised turns are still there — only the request leaves them
      // out — with a line saying the model is no longer being sent them.
      expect(replay.entries.map((entry) => entry.runtimeType.toString()), [
        'AgentUserEntry',
        'AgentToolResultEntry',
        'AgentNoticeEntry',
        'AgentUserEntry',
      ]);
      expect(
        (replay.entries[2] as AgentNoticeEntry).kind,
        AgentNoticeKind.compacted,
      );
    });

    test('a whole unanswered batch comes back, in the order it was made', () {
      // Reopening a conversation has to restore all of them: an id left behind
      // is answered later with no call recorded, which the API rejects.
      const first = AskAiCommand(id: 'call-a', command: 'uptime');
      const second = AskAiCommand(id: 'call-b', command: 'free -m');
      final replay = replayAgentTimeline([
        const AskAiMessageItem.user('Check the machine.'),
        const AskAiFunctionCallItem(command: first),
        const AskAiFunctionCallItem(command: second),
      ]);

      expect(replay.pending.map((call) => call.id), ['call-a', 'call-b']);
    });

    test('only the calls still waiting come back', () {
      const answered = AskAiCommand(id: 'call-a', command: 'uptime');
      const waiting = AskAiCommand(id: 'call-b', command: 'free -m');
      final replay = replayAgentTimeline([
        const AskAiFunctionCallItem(command: answered),
        const AskAiFunctionCallItem(command: waiting),
        AskAiFunctionOutputItem(
          callId: answered.id,
          output: encodeAgentConversationToolAction(
            AgentConversationToolAction.declined,
          ),
        ),
      ]);

      expect(replay.pending.map((call) => call.id), ['call-b']);
    });

    test('an empty conversation replays to nothing pending', () {
      final replay = replayAgentTimeline(const []);
      expect(replay.entries, isEmpty);
      expect(replay.pending, isEmpty);
    });
  });

  group('AgentToolExecutionResult', () {
    test('round-trips a local failure through the tool message', () {
      const result = AgentToolExecutionResult(
        toolName: 'run_shell_command',
        summary: 'The tool failed to run.',
        succeeded: false,
        duration: Duration.zero,
        localFailure: true,
        data: {'error': 'Configured server not found: nope'},
      );
      final decoded = AgentToolExecutionResult.fromToolMessage(
        result.toToolMessage(),
      );

      expect(decoded.localFailure, isTrue);
      expect(decoded.succeeded, isFalse);
      // The English summary is what the model reads; the app substitutes its
      // own line when `localFailure` is set.
      expect(decoded.summary, 'The tool failed to run.');
    });

    test('a result from before the field defaults to no local failure', () {
      final decoded = AgentToolExecutionResult.fromToolMessage(
        '{"server_box_tool_result":true,"tool":"read_file","ok":true,'
        '"summary":"Read /etc/hosts.","duration_ms":4}',
      );

      expect(decoded.localFailure, isFalse);
      expect(decoded.succeeded, isTrue);
    });
  });

  group('AgentSessionState.copyWith', () {
    const base = AgentSessionState(protocol: AskAiProtocol.chatCompletions);

    test('leaves a nullable field alone when it is not passed', () {
      final withPending = base.copyWith(
        pendingTools: const [pendingCommand],
        error: 'boom',
        streamingContent: 'partial',
      );
      final rebuilt = withPending.copyWith(isStreaming: true);

      expect(rebuilt.pendingTool, pendingCommand);
      expect(rebuilt.error, 'boom');
      expect(rebuilt.streamingContent, 'partial');
      expect(rebuilt.isStreaming, isTrue);
    });

    test('clears a nullable field when null is passed explicitly', () {
      final withPending = base.copyWith(
        pendingTools: const [pendingCommand],
        error: 'boom',
        streamingContent: 'partial',
      );
      final cleared = withPending.copyWith(
        pendingTools: const [],
        error: null,
        streamingContent: null,
      );

      expect(cleared.pendingTool, isNull);
      expect(cleared.error, isNull);
      expect(cleared.streamingContent, isNull);
    });

    test('isWorking follows either half of the work', () {
      expect(base.isWorking, isFalse);
      expect(base.copyWith(isStreaming: true).isWorking, isTrue);
      expect(base.copyWith(isExecuting: true).isWorking, isTrue);
    });

    test('isEmpty is false as soon as there is anything to show', () {
      expect(base.isEmpty, isTrue);
      expect(base.copyWith(isStreaming: true).isEmpty, isFalse);
      expect(base.copyWith(pendingTools: const [pendingCommand]).isEmpty, isFalse);
      expect(
        base.copyWith(timeline: const [AgentUserEntry('hi')]).isEmpty,
        isFalse,
      );
    });
  });

  group('AgentSession.submitPrompt', () {
    late Directory tempDir;
    late AgentConversationStore conversationStore;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'server-box-agent-session-',
      );
      await openTestDb();
      await getIt.reset();
      getIt.registerSingleton<SettingStore>(
        SettingStore('setting_test')..init(),
      );
      getIt.registerSingleton<ServerStore>(ServerStore());
      conversationStore = AgentConversationStore();
      getIt.registerSingleton<AgentConversationStore>(conversationStore);
    });

    tearDownAll(() async {
      await getIt.reset();
      await SqliteDb.close();
      await tempDir.delete(recursive: true);
    });

    test('every call of a parallel turn is answered, run or not', () async {
      // `parallel_tool_calls: false` asks for one, and a provider that ignores
      // it used to leave the extra calls unanswered — which invalidates the
      // next request rather than this one, so it surfaced as results arriving
      // a turn late or not at all (#1463).
      const first = AskAiCommand(
        id: 'call-a',
        command: 'uptime',
        toolName: 'run_shell_command',
      );
      const second = AskAiCommand(
        id: 'call-b',
        command: 'free -m',
        toolName: 'run_shell_command',
      );
      final repository = _ParallelToolCallRepository(const [first, second]);
      final container = ProviderContainer(
        overrides: [askAiRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      // This turn leaves a call awaiting review, and the next test's session
      // would restore it out of the store and refuse to submit anything.
      addTearDown(() => conversationStore.clearServer(globalAgentConversationScope));
      final notifier = container.read(globalAgentSessionProvider.notifier);

      await notifier.submitPrompt('check the server');
      // The stream is synchronous; the turn is handled in microtasks.
      await Future<void>.delayed(Duration.zero);

      final state = container.read(globalAgentSessionProvider);
      // Both are kept, in the order the model made them, and the first is the
      // one on screen.
      expect(state.pendingTools.map((call) => call.id), [first.id, second.id]);
      expect(state.pendingIndex, 0);
      expect(state.pendingTool?.id, first.id);
      // Nothing is answered until the user acts: the model hears back once
      // every call in the turn has an answer, not before.
      expect(state.history.whereType<AskAiFunctionOutputItem>(), isEmpty);
    });

    test('declining answers the whole batch, not the card on screen', () async {
      const first = AskAiCommand(
        id: 'call-a',
        command: 'uptime',
        toolName: 'run_shell_command',
      );
      const second = AskAiCommand(
        id: 'call-b',
        command: 'free -m',
        toolName: 'run_shell_command',
      );
      final repository = _ParallelToolCallRepository(const [first, second]);
      final container = ProviderContainer(
        overrides: [askAiRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      addTearDown(
        () => conversationStore.clearServer(globalAgentConversationScope),
      );
      final notifier = container.read(globalAgentSessionProvider.notifier);

      await notifier.submitPrompt('check the server');
      await Future<void>.delayed(Duration.zero);
      await notifier.declinePendingTool();

      final state = container.read(globalAgentSessionProvider);
      // Every id answered, or the next request is the one the API rejects.
      final answered = state.history
          .whereType<AskAiFunctionOutputItem>()
          .map((item) => item.callId);
      expect(answered, containsAll([first.id, second.id]));
      expect(state.pendingTools, isEmpty);
      // One notice: the user said no once.
      expect(
        state.timeline.whereType<AgentNoticeEntry>().map((e) => e.kind),
        [AgentNoticeKind.declined],
      );
    });

    test('resending from a message discards what answered it', () async {
      final repository = _ParallelToolCallRepository(const []);
      final container = ProviderContainer(
        overrides: [askAiRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      addTearDown(
        () => conversationStore.clearServer(globalAgentConversationScope),
      );
      final notifier = container.read(globalAgentSessionProvider.notifier);

      await notifier.submitPrompt('first question');
      await Future<void>.delayed(Duration.zero);
      await notifier.submitPrompt('second question');
      await Future<void>.delayed(Duration.zero);

      // Back to the first, with different words.
      final sent = await notifier.resendFrom(0, 'first question, rephrased');
      await Future<void>.delayed(Duration.zero);

      expect(sent, isTrue);
      final state = container.read(globalAgentSessionProvider);
      final asked = state.history
          .whereType<AskAiMessageItem>()
          .where((item) => item.role == AskAiMessageRole.user)
          .map((item) => item.content);
      // The rewritten question, and nothing that came after the original.
      expect(asked, ['first question, rephrased']);
      expect(
        state.timeline.whereType<AgentUserEntry>().map((e) => e.content),
        ['first question, rephrased'],
      );
    });

    test('deleting cuts the same way, and asks nothing', () async {
      final repository = _ParallelToolCallRepository(const []);
      final container = ProviderContainer(
        overrides: [askAiRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      addTearDown(
        () => conversationStore.clearServer(globalAgentConversationScope),
      );
      final notifier = container.read(globalAgentSessionProvider.notifier);

      await notifier.submitPrompt('first question');
      await Future<void>.delayed(Duration.zero);
      await notifier.submitPrompt('second question');
      await Future<void>.delayed(Duration.zero);

      expect(await notifier.deleteFrom(1), isTrue);

      final state = container.read(globalAgentSessionProvider);
      expect(
        state.timeline.whereType<AgentUserEntry>().map((e) => e.content),
        ['first question'],
      );
      // No new turn: a delete is not a question.
      expect(state.isStreaming, isFalse);
    });

    test('resending is refused while a turn is running', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(globalAgentSessionProvider.notifier);
      notifier.state = notifier.state.copyWith(
        timeline: const [AgentUserEntry('hi')],
        history: const [AskAiMessageItem.user('hi')],
        isStreaming: true,
      );

      expect(await notifier.resendFrom(0, 'again'), isFalse);
      // And an empty edit is not a question.
      notifier.state = notifier.state.copyWith(isStreaming: false);
      expect(await notifier.resendFrom(0, '   '), isFalse);
      // Nor is a message that is not there.
      expect(await notifier.resendFrom(5, 'again'), isFalse);
    });

    test('showPendingTool moves within the batch and ignores nonsense', () {
      const first = AskAiCommand(id: 'call-a', command: 'uptime');
      const second = AskAiCommand(id: 'call-b', command: 'free -m');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(globalAgentSessionProvider.notifier);
      notifier.state = notifier.state.copyWith(
        pendingTools: const [first, second],
        pendingIndex: 0,
      );

      notifier.showPendingTool(1);
      expect(container.read(globalAgentSessionProvider).pendingTool?.id, 'call-b');

      // A page view settling on a stale index should do nothing at all.
      notifier.showPendingTool(7);
      notifier.showPendingTool(-1);
      expect(container.read(globalAgentSessionProvider).pendingTool?.id, 'call-b');
    });

    test('rapid double submission persists and streams only once', () async {
      final repository = _CountingAskAiRepository();
      final container = ProviderContainer(
        overrides: [askAiRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(globalAgentSessionProvider.notifier);

      final first = notifier.submitPrompt('inspect the server');
      final second = notifier.submitPrompt('duplicate submission');

      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(repository.calls, 1);
      final stored = conversationStore.fetchActive(
        globalAgentConversationScope,
      );
      expect(stored, isNotNull);
      expect(
        stored!.items.whereType<AskAiMessageItem>().map((item) => item.content),
        ['inspect the server'],
      );
    });
  });
}

/// A provider that ignores `parallel_tool_calls: false`.
class _ParallelToolCallRepository extends AskAiRepository {
  _ParallelToolCallRepository(this.commands);

  final List<AskAiCommand> commands;

  /// Only the first turn proposes anything. The turn that follows an answer is
  /// a real one in production, and here it only has to end — otherwise it is
  /// still running when the test's container is disposed.
  var _answered = false;

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
    if (_answered) return const Stream.empty();
    _answered = true;
    return Stream.fromIterable([
      for (final command in commands) AskAiToolSuggestion(command),
      AskAiCompleted(
        fullText: '',
        commands: commands,
        // What the codecs build: one assistant message carrying every call.
        outputItems: [
          const AskAiMessageItem.assistant(''),
          for (final command in commands) AskAiFunctionCallItem(command: command),
        ],
        protocol: AskAiProtocol.chatCompletions,
      ),
    ]);
  }
}

class _CountingAskAiRepository extends AskAiRepository {
  int calls = 0;

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
    return const Stream.empty();
  }
}
