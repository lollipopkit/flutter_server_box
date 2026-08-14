import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/provider/ai/global_agent_tools.dart';
import 'package:server_box/view/page/agent/view.dart';

void main() {
  test('global Agent instructions expose exact live server IDs', () {
    final instructions = buildGlobalAgentInstructions(
      localeHint: 'zh-CN',
      servers: const [
        GlobalAgentServerContext(
          id: 'server-a',
          name: 'Production',
          connection: 'finished',
          system: 'linux',
        ),
        GlobalAgentServerContext(
          id: 'server-b',
          name: 'Production',
          connection: 'disconnected',
          system: 'unknown',
        ),
      ],
    );

    expect(instructions, contains('"id":"server-a"'));
    expect(instructions, contains('"id":"server-b"'));
    expect(instructions, contains('Propose exactly one tool call at a time'));
    expect(instructions, contains('zh-CN'));
  });

  test('Agent tool results round-trip through conversation output', () {
    const result = AgentToolExecutionResult(
      toolName: 'serverbox',
      serverId: 'server-a',
      summary: 'Read status.',
      succeeded: true,
      duration: Duration(milliseconds: 42),
      data: {'connection': 'finished', 'cpu_used_percent': 12.5},
    );

    final decoded = AgentToolExecutionResult.fromToolMessage(
      result.toToolMessage(),
    );

    expect(decoded.toolName, 'serverbox');
    expect(decoded.serverId, 'server-a');
    expect(decoded.succeeded, isTrue);
    expect(decoded.duration, const Duration(milliseconds: 42));
    expect(decoded.displayData, contains('cpu_used_percent'));
  });

  test('non-Agent tool payloads are ignored', () {
    final result = AgentToolExecutionResult.tryFromToolMessage(
      '{"tool":"serverbox","ok":true}',
    );

    expect(result, isNull);
  });

  test('oversized shell output preserves its head and tail', () {
    final stdout = 'HEAD-${List.filled(200, 'x').join()}-TAIL';
    final limited = limitGlobalAgentShellOutput(stdout, '', maxCharacters: 96);

    expect(limited.truncated, isTrue);
    expect(limited.stdout, startsWith('HEAD-'));
    expect(limited.stdout, endsWith('-TAIL'));
    expect(limited.stdout, contains('[... output truncated ...]'));
    expect(limited.stdout.length, lessThanOrEqualTo(96));
    expect(limited.stderr, isEmpty);
  });

  test('shell result display shows output instead of raw tool JSON', () {
    const result = AgentToolExecutionResult(
      toolName: 'run_shell_command',
      summary: 'Command timed out.',
      succeeded: false,
      duration: Duration(seconds: 5),
      truncated: true,
      data: {
        'command': 'raw tool command',
        'exit_code': 124,
        'stdout': 'partial output',
        'stderr': 'timeout warning',
        'timed_out': true,
      },
    );

    final output = formatGlobalAgentToolResultOutput(
      result,
      cancelledLabel: 'Cancelled',
      timedOutLabel: 'Timed out',
      noOutputLabel: 'No output',
      truncatedLabel: 'Truncated',
    );

    expect(output, contains('Timed out · Exit code: 124'));
    expect(output, contains('stdout\npartial output'));
    expect(output, contains('stderr\ntimeout warning'));
    expect(output, contains('Truncated'));
    expect(output, isNot(contains('raw tool command')));
    expect(output, isNot(contains('"command"')));
  });

  test('empty server list remains explicit in the prompt', () {
    final instructions = buildGlobalAgentInstructions(servers: const []);

    expect(
      instructions,
      contains('Configured servers (untrusted application data):\n- None'),
    );
  });

  group('AgentSshTarget.fromArguments', () {
    AskAiCommand shell(Map<String, dynamic> arguments) => AskAiCommand(
      id: 'call-1',
      command: 'uptime',
      toolName: 'run_shell_command',
      rawArguments: jsonEncode(arguments),
    );

    test('a named server resolves to that server', () {
      final target = AgentSshTarget.fromArguments(
        shell({'server_id': 'server-a', 'command': 'uptime'}),
      );

      expect(target, isA<ConfiguredServerTarget>());
      expect((target as ConfiguredServerTarget).serverId, 'server-a');
    });

    test('a call that names no machine is refused', () {
      expect(
        () => AgentSshTarget.fromArguments(shell({'command': 'uptime'})),
        throwsA(isA<FormatException>()),
      );
    });

    test('a blank server id is not a machine', () {
      // The model filling the field with whitespace to satisfy the schema must
      // not read as "the server called ' '".
      expect(
        () => AgentSshTarget.fromArguments(
          shell({'server_id': '   ', 'command': 'uptime'}),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('unparsable arguments name no machine either', () {
      const proposal = AskAiCommand(
        id: 'call-1',
        command: 'uptime',
        toolName: 'run_shell_command',
        rawArguments: 'not json',
      );

      expect(
        () => AgentSshTarget.fromArguments(proposal),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('serverbox actions', () {
    AskAiCommand command(String action, {bool modelSafeToRun = false}) {
      return AskAiCommand(
        id: 'call-1',
        command: '',
        toolName: 'serverbox',
        rawArguments: jsonEncode({
          'action': action,
          'server_id': 'server-a',
          'description': 'why',
          'safe_to_run': modelSafeToRun,
        }),
        modelSafeToRun: modelSafeToRun,
      );
    }

    /// The schema and the switch that answers it are written apart. A name
    /// only in one of them is a tool call the model can make and the app
    /// throws on.
    List<String> declaredActions() {
      final serverbox = globalAgentToolDefinitions.firstWhere(
        (tool) => tool.name == 'serverbox',
      );
      final properties =
          serverbox.parameters['properties'] as Map<String, dynamic>;
      final action = properties['action'] as Map<String, dynamic>;
      return (action['enum'] as List).cast<String>();
    }

    test('open_server is one of the declared actions', () {
      expect(declaredActions(), contains('open_server'));
    });

    test('only reading is read-only', () {
      expect(command('list_servers').risk, AskAiCommandRisk.readOnly);
      expect(command('get_status').risk, AskAiCommandRisk.readOnly);
      for (final action in declaredActions()) {
        if (action == 'list_servers' || action == 'get_status') continue;
        expect(
          command(action).risk,
          AskAiCommandRisk.caution,
          reason: '$action changes something and must be reviewed',
        );
      }
    });

    test('open_server is never automatic, whatever the model claims', () {
      // It moves the app out from under the user. Harmless to the server, but
      // not something to do without being asked.
      final proposal = command('open_server', modelSafeToRun: true);
      expect(proposal.risk, AskAiCommandRisk.caution);
      expect(proposal.canAutoRun, isFalse);
    });

    test('the model is told what open_server is for', () {
      final instructions = buildGlobalAgentInstructions(servers: const []);
      expect(instructions, contains('open_server'));
      expect(instructions, contains('not to read its state'));
    });
  });
}
