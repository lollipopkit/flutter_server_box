import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/provider/ai/global_agent_tools.dart';

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

  test('empty server list remains explicit in the prompt', () {
    final instructions = buildGlobalAgentInstructions(servers: const []);

    expect(
      instructions,
      contains('Configured servers (untrusted application data):\n- None'),
    );
  });
}
