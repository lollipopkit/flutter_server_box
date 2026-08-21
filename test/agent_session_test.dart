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

  group('replayGlobalAgentTimeline', () {
    test('replays messages, tool results, declines and the pending call', () {
      const result = AgentToolExecutionResult(
        toolName: 'run_shell_command',
        serverId: 'srv',
        summary: 'Command exited with code 0.',
        succeeded: true,
        duration: Duration(milliseconds: 25),
        data: {'stdout': 'up 3 days', 'exit_code': 0},
      );
      final replay = replayGlobalAgentTimeline([
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
      expect(replay.pending?.id, pendingCommand.id);
    });

    test('carries no localized text, only the reason for a notice', () {
      final replay = replayGlobalAgentTimeline([
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
      final replay = replayGlobalAgentTimeline([
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
      expect(replay.pending, isNull);
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
      final replay = replayGlobalAgentTimeline([
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
      expect(replay.pending?.command, 'df -h');
    });

    test('an empty conversation replays to nothing pending', () {
      final replay = replayGlobalAgentTimeline(const []);
      expect(replay.entries, isEmpty);
      expect(replay.pending, isNull);
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
        pendingTool: pendingCommand,
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
        pendingTool: pendingCommand,
        error: 'boom',
        streamingContent: 'partial',
      );
      final cleared = withPending.copyWith(
        pendingTool: null,
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
      expect(base.copyWith(pendingTool: pendingCommand).isEmpty, isFalse);
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
      tempDir = await Directory.systemTemp.createTemp('server-box-agent-session-');
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

    test('rapid double submission persists and streams only once', () async {
      final repository = _CountingAskAiRepository();
      final container = ProviderContainer(
        overrides: [askAiRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(agentSessionProvider.notifier);

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
