import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/provider/ai/global_agent_tools.dart';

/// What the Agent is told when it names a connection that is gone.
///
/// A conversation is restored after a relaunch with its transcript intact, so
/// the model still sees `session_id`s from before — and ad-hoc connections die
/// with the app. Listed in TODOS.md as delivered but never exercised; this is
/// the exercise, because the failure the app must avoid is a bare "not found",
/// which a model answers by retrying the same dead id.
void main() {
  late ProviderContainer container;
  late GlobalAgentToolService service;

  setUp(() {
    container = ProviderContainer();
    service = container.read(globalAgentToolServiceProvider);
  });

  tearDown(() => container.dispose());

  AskAiCommand shell(String sessionId) => AskAiCommand(
    id: 'call-1',
    toolName: 'run_shell_command',
    command: 'uptime',
    description: 'check uptime',
    rawArguments: '{"session_id":"$sessionId","command":"uptime"}',
    modelSafeToRun: true,
  );

  test('a session id from before the restart is refused, and says why', () async {
    await expectLater(
      service.execute(shell('sess-gone')),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('sess-gone'),
            // The part that changes what the model does next.
            contains('not kept across app restarts'),
            contains('ssh_connect'),
          ),
        ),
      ),
    );
  });

  test('reading a file over one is refused the same way', () async {
    const read = AskAiCommand(
      id: 'call-2',
      toolName: 'read_file',
      command: '',
      description: 'read hosts',
      rawArguments: '{"session_id":"sess-gone","path":"/etc/hosts"}',
      modelSafeToRun: true,
    );

    await expectLater(
      service.execute(read),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('not kept across app restarts'),
        ),
      ),
    );
  });

  test('naming both a server and a session is refused before either is used', () async {
    const both = AskAiCommand(
      id: 'call-3',
      toolName: 'run_shell_command',
      command: 'uptime',
      description: 'check uptime',
      rawArguments:
          '{"server_id":"server-a","session_id":"sess-1","command":"uptime"}',
      modelSafeToRun: true,
    );

    await expectLater(
      service.execute(both),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('not both'),
        ),
      ),
    );
  });
}
