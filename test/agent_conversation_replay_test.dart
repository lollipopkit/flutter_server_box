import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/ai/agent_conversation_replay.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/provider/ai/agent_session.dart';
import 'package:server_box/data/provider/ai/global_agent_tools.dart';

/// Replaying a stored conversation, from the terminal Agent's side.
///
/// These were written against `AgentConversationReplay`, which was the second
/// of two replays — one per Agent surface — and is gone. The cases are the
/// same because the stored conversations are: a release that wrote one of
/// these is still on disk, and the merged replay is what has to read it.
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
    final replay = replayAgentTimeline([
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

    expect(replay.entries.map((entry) => entry.runtimeType), [
      AgentUserEntry,
      AgentAssistantEntry,
      AgentShellResultEntry,
      AgentNoticeEntry,
    ]);
    expect(
      (replay.entries[2] as AgentShellResultEntry).result.stdout,
      'up 3 days',
    );
    expect(
      (replay.entries[3] as AgentNoticeEntry).kind,
      AgentNoticeKind.declined,
    );
    expect(replay.pending?.id, pendingCommand.id);
  });

  test('a shell result is not read as a tool result', () {
    // The two encodings share this field and are told apart by a marker only
    // the tool one carries. Read the wrong way round, a command's output
    // becomes a tool named '' that reports failure — and the terminal, which
    // is the only surface that writes these, would show every past command as
    // having failed.
    const result = AskAiCommandResult(
      command: 'uptime',
      exitCode: 0,
      stdout: 'up 3 days',
      stderr: '',
      duration: Duration.zero,
    );
    expect(
      AgentToolExecutionResult.tryFromToolMessage(result.toToolMessage()),
      isNull,
    );

    final replay = replayAgentTimeline([
      const AskAiFunctionCallItem(command: completedCommand),
      AskAiFunctionOutputItem(
        callId: completedCommand.id,
        output: result.toToolMessage(),
      ),
    ]);
    expect(replay.entries.single, isA<AgentShellResultEntry>());
  });

  test('and a tool result is not read as a shell result', () {
    // The other direction: the shell decoder accepts anything carrying stdout
    // or stderr, and a `run_shell_command` tool result has both inside its
    // `data`. It is the ordering in the replay that keeps this right, so a
    // case for it rather than for the decoders alone.
    final toolResult = AgentToolExecutionResult(
      toolName: 'run_shell_command',
      summary: 'Ran uptime on web-1.',
      succeeded: true,
      duration: Duration.zero,
      serverId: 'web-1',
      data: const {'stdout': 'up 3 days', 'stderr': '', 'exit_code': 0},
    );
    final replay = replayAgentTimeline([
      const AskAiFunctionCallItem(command: completedCommand),
      AskAiFunctionOutputItem(
        callId: completedCommand.id,
        output: toolResult.toToolMessage(),
      ),
    ]);
    expect(replay.entries.single, isA<AgentToolResultEntry>());
  });

  test('round-trips inserted action output for history rendering', () {
    final replay = replayAgentTimeline([
      const AskAiFunctionCallItem(command: pendingCommand),
      AskAiFunctionOutputItem(
        callId: pendingCommand.id,
        output: encodeAgentConversationToolAction(
          AgentConversationToolAction.inserted,
        ),
      ),
    ]);

    expect(
      (replay.entries.single as AgentNoticeEntry).kind,
      AgentNoticeKind.inserted,
    );
    expect(replay.pending, isNull);
  });

  test('matches duplicate call IDs in arrival order', () {
    const first = AskAiCommand(id: 'duplicate', command: 'uptime');
    const second = AskAiCommand(id: 'duplicate', command: 'df -h');
    const result = AskAiCommandResult(
      command: 'uptime',
      exitCode: 0,
      stdout: 'up 3 days',
      stderr: '',
      duration: Duration.zero,
    );
    final replay = replayAgentTimeline([
      const AskAiFunctionCallItem(command: first),
      AskAiFunctionOutputItem(callId: first.id, output: result.toToolMessage()),
      const AskAiFunctionCallItem(command: second),
    ]);

    expect(
      (replay.entries.single as AgentShellResultEntry).command.command,
      'uptime',
    );
    expect(replay.pending?.command, 'df -h');
  });

  test('renders unparsable function output as a notice', () {
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
    expect(replay.pending, isNull);
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
        runCount: 2,
      ),
      isTrue,
    );
    expect(
      shouldAutoRunAgentCommand(
        command: pendingCommand,
        enabled: true,
        restored: false,
        runCount: 3,
      ),
      isFalse,
    );
    expect(
      shouldAutoRunAgentCommand(
        command: pendingCommand,
        enabled: true,
        restored: false,
        runCount: 8,
      ),
      isFalse,
    );
  });
}
