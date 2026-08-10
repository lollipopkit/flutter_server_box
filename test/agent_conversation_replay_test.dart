import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/view/page/ssh/agent_conversation_replay.dart';

void main() {
  const completedCommand = AskAiCommand(
    id: 'call-completed',
    command: 'uptime',
    description: 'Inspect uptime',
    rawArguments: '{"command":"uptime","safe_to_run":true}',
    modelSafeToRun: true,
  );
  const declinedCommand = AskAiCommand(
    id: 'call-declined',
    command: 'systemctl restart nginx',
    description: 'Restart nginx',
  );
  const pendingCommand = AskAiCommand(
    id: 'call-pending',
    command: 'df -h',
    description: 'Inspect disk usage',
    rawArguments: '{"command":"df -h","safe_to_run":true}',
    modelSafeToRun: true,
  );

  test('replays messages, results, actions, and the pending command', () {
    const result = AskAiCommandResult(
      command: 'uptime',
      exitCode: 0,
      stdout: 'up 3 days',
      stderr: '',
      duration: Duration(milliseconds: 25),
    );
    final replay = AgentConversationReplay.fromItems([
      const AskAiMessageItem.user('Check the server.'),
      const AskAiReasoningItem(rawResponseItem: {'type': 'reasoning'}),
      const AskAiMessageItem.assistant('I will inspect it.'),
      const AskAiFunctionCallItem(command: completedCommand),
      AskAiFunctionOutputItem(
        callId: completedCommand.id,
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

    expect(replay.entries.map((entry) => entry.type), [
      AgentConversationReplayEntryType.user,
      AgentConversationReplayEntryType.assistant,
      AgentConversationReplayEntryType.commandResult,
      AgentConversationReplayEntryType.declined,
    ]);
    expect(replay.entries[2].result?.stdout, 'up 3 days');
    expect(replay.pendingCommand?.id, pendingCommand.id);
  });

  test('round-trips inserted action output for history rendering', () {
    final replay = AgentConversationReplay.fromItems([
      const AskAiFunctionCallItem(command: pendingCommand),
      AskAiFunctionOutputItem(
        callId: pendingCommand.id,
        output: encodeAgentConversationToolAction(
          AgentConversationToolAction.inserted,
        ),
      ),
    ]);

    expect(
      replay.entries.single.type,
      AgentConversationReplayEntryType.inserted,
    );
    expect(replay.pendingCommand, isNull);
  });

  test('restored commands are never eligible for automatic execution', () {
    expect(
      shouldAutoRunAgentCommand(
        command: pendingCommand,
        enabled: true,
        restored: true,
        runCount: 0,
      ),
      isFalse,
    );
    expect(
      shouldAutoRunAgentCommand(
        command: pendingCommand,
        enabled: true,
        restored: false,
        runCount: 0,
      ),
      isTrue,
    );
  });
}
