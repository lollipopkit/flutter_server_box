import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/local_exec.dart';
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

  group('ad-hoc SSH targets', () {
    AskAiCommand shell(Map<String, dynamic> arguments) => AskAiCommand(
      id: 'call-1',
      command: arguments['command'] as String? ?? 'uptime',
      toolName: 'run_shell_command',
      rawArguments: jsonEncode(arguments),
      modelSafeToRun: arguments['safe_to_run'] as bool? ?? false,
    );

    test('a session id resolves to an ad-hoc connection', () {
      final target = AgentSshTarget.fromArguments(
        shell({'session_id': 'sess-1', 'command': 'uptime'}),
      );

      expect(target, isA<AdHocSessionTarget>());
      expect((target as AdHocSessionTarget).sessionId, 'sess-1');
    });

    test('naming both machines is refused rather than resolved', () {
      // Picking one would run the command somewhere nobody chose.
      expect(
        () => AgentSshTarget.fromArguments(
          shell({
            'server_id': 'server-a',
            'session_id': 'sess-1',
            'command': 'uptime',
          }),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('an explicit null session id still names the server', () {
      // What the schema produces for "the other one": both fields are always
      // present, and one of them is null.
      final target = AgentSshTarget.fromArguments(
        shell({
          'server_id': 'server-a',
          'session_id': null,
          'command': 'uptime',
        }),
      );

      expect((target as ConfiguredServerTarget).serverId, 'server-a');
    });

    test('nothing runs unattended on a host met this conversation', () {
      final onServer = shell({
        'server_id': 'server-a',
        'command': 'ls /etc',
        'safe_to_run': true,
      });
      final onAdHoc = shell({
        'session_id': 'sess-1',
        'command': 'ls /etc',
        'safe_to_run': true,
      });

      // The same read-only command. On a vetted server it may auto-run; on a
      // machine the user has only just handed a password to it may not.
      expect(onServer.risk, AskAiCommandRisk.readOnly);
      expect(onServer.canAutoRun, isTrue);
      // Not `caution`: the command is read-only and saying otherwise would be
      // a claim about the wrong thing. The host is what has not been vetted.
      expect(onAdHoc.risk, AskAiCommandRisk.unknown);
      expect(onAdHoc.intrinsicRisk, AskAiCommandRisk.readOnly);
      expect(onAdHoc.raisedByUnvettedHost, isTrue);
      expect(onAdHoc.canAutoRun, isFalse);
    });

    test('the floor does not lower a destructive command', () {
      final proposal = shell({
        'session_id': 'sess-1',
        'command': 'rm -rf /var/log',
        'safe_to_run': true,
      });

      expect(proposal.risk, AskAiCommandRisk.destructive);
      expect(proposal.raisedByUnvettedHost, isFalse);
      expect(proposal.canAutoRun, isFalse);
    });

    test('reading a file on an ad-hoc host is not auto-runnable either', () {
      const onAdHoc = AskAiCommand(
        id: 'call-1',
        command: '',
        toolName: 'read_file',
        rawArguments:
            '{"session_id":"sess-1","path":"/etc/hosts","safe_to_run":true}',
        modelSafeToRun: true,
      );
      const onServer = AskAiCommand(
        id: 'call-2',
        command: '',
        toolName: 'read_file',
        rawArguments:
            '{"server_id":"server-a","path":"/etc/hosts","safe_to_run":true}',
        modelSafeToRun: true,
      );

      expect(onAdHoc.risk, AskAiCommandRisk.unknown);
      expect(onAdHoc.raisedByUnvettedHost, isTrue);
      expect(onAdHoc.canAutoRun, isFalse);
      expect(onServer.canAutoRun, isTrue);
    });
  });

  group('ssh_connect', () {
    AskAiCommand connect(Map<String, dynamic> arguments) => AskAiCommand(
      id: 'call-1',
      command: '',
      toolName: 'ssh_connect',
      rawArguments: jsonEncode(arguments),
      modelSafeToRun: arguments['safe_to_run'] as bool? ?? false,
    );

    test('reaching an unknown machine is always destructive', () {
      final proposal = connect({
        'host': '10.0.0.9',
        'port': 22,
        'user': 'root',
        'safe_to_run': true,
      });

      expect(proposal.risk, AskAiCommandRisk.destructive);
      expect(proposal.canAutoRun, isFalse);
    });

    test('what the user reviews is the host, not an empty line', () {
      expect(
        connect({'host': '10.0.0.9', 'port': 2222, 'user': 'deploy'})
            .displayValue,
        'deploy@10.0.0.9:2222',
      );
    });

    test('its schema asks for no secret', () {
      final tool = globalAgentToolDefinitions.firstWhere(
        (tool) => tool.name == 'ssh_connect',
      );
      final properties =
          tool.parameters['properties'] as Map<String, dynamic>;

      // The password is collected by the app. A field for it here would put it
      // in `rawArguments`, which is written into the stored conversation and
      // replayed to the model on every later turn.
      expect(properties.keys, isNot(contains('password')));
      expect(properties.keys, isNot(contains('pwd')));
      expect(properties.keys, isNot(contains('private_key')));
      expect(properties.keys, isNot(contains('passphrase')));
      expect(
        properties.keys,
        containsAll(<String>['host', 'port', 'user']),
      );
    });

    test('a stored key is a credential the schema still cannot carry', () {
      // Picking a key means the tool call names one by id — which would be
      // harmless in itself, but the field would then also accept a PEM.
      final tool = globalAgentToolDefinitions.firstWhere(
        (tool) => tool.name == 'ssh_connect',
      );
      final properties =
          tool.parameters['properties'] as Map<String, dynamic>;

      expect(properties.keys, isNot(contains('key_id')));
      expect(properties.keys, isNot(contains('private_key_id')));
    });

    test('the model is told not to ask for credentials itself', () {
      final instructions = buildGlobalAgentInstructions(servers: const []);
      expect(instructions, contains('ssh_connect'));
      expect(instructions, contains('Never ask for a password'));
    });

    test('reaching an unlisted host is framed before anything limits it', () {
      // The framing used to say the Agent operates on "configured servers" and
      // to "use only exact server IDs", with ssh_connect mentioned eight lines
      // further down. Models read that as the boundary and refused to connect
      // to anything unlisted, telling the user to add the server first — which
      // is the one thing this tool exists to make unnecessary.
      final lines = buildGlobalAgentInstructions(
        servers: const [],
      ).split('\n');

      expect(
        lines.take(3).join('\n'),
        contains('ssh_connect'),
        reason: 'ad-hoc hosts must be in the opening framing, not a footnote',
      );
      expect(
        buildGlobalAgentInstructions(servers: const []),
        contains('Do not ask the user to add it first'),
      );
    });

    test('disconnecting is reviewed but not alarming', () {
      const proposal = AskAiCommand(
        id: 'call-1',
        command: '',
        toolName: 'ssh_disconnect',
        rawArguments: '{"session_id":"sess-1","safe_to_run":true}',
        modelSafeToRun: true,
      );

      expect(proposal.risk, AskAiCommandRisk.caution);
      expect(proposal.canAutoRun, isFalse);
      expect(proposal.displayValue, 'sess-1');
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

    test('add_server is one of the declared actions', () {
      expect(declaredActions(), contains('add_server'));
    });

    test('add_server asks for no monitor credential', () {
      final serverbox = globalAgentToolDefinitions.firstWhere(
        (tool) => tool.name == 'serverbox',
      );
      final properties =
          serverbox.parameters['properties'] as Map<String, dynamic>;

      // Its address is a fact the Agent may have learned by installing it; the
      // user and password are secrets, and go the same way the SSH password
      // does — through a dialog, never through the transcript.
      expect(properties.keys, contains('monitor_addr'));
      expect(properties.keys, isNot(contains('monitor_user')));
      expect(properties.keys, isNot(contains('monitor_pwd')));
      expect(properties.keys, isNot(contains('monitor_password')));
    });

    test('saving a host is reviewed, and never automatic', () {
      final proposal = command('add_server', modelSafeToRun: true);
      expect(proposal.risk, AskAiCommandRisk.caution);
      expect(proposal.canAutoRun, isFalse);
    });

    test('the model is told the app collects monitor credentials', () {
      final instructions = buildGlobalAgentInstructions(servers: const []);
      expect(instructions, contains('add_server'));
      expect(instructions, contains('the app asks the user for them'));
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

  group('the Agent on this device', () {
    AskAiCommand shell(Map<String, Object?> args) => AskAiCommand(
      id: 'call-1',
      command: args['command'] as String? ?? '',
      toolName: 'run_shell_command',
      rawArguments: jsonEncode(args),
      modelSafeToRun: args['safe_to_run'] == true,
    );

    test('the reserved id names this machine, not a server', () {
      final target = AgentSshTarget.fromArguments(
        shell({
          'server_id': LocalExec.deviceId,
          'command': 'uname -a',
          'safe_to_run': true,
        }),
      );

      expect(target, isA<LocalTarget>());
    });

    test('nothing auto-runs here, however read-only it looks', () {
      final onDevice = shell({
        'server_id': LocalExec.deviceId,
        'command': 'ls /etc',
        'safe_to_run': true,
      });
      final onServer = shell({
        'server_id': 'server-a',
        'command': 'ls /etc',
        'safe_to_run': true,
      });

      // The same command. `askAiAutoRunSafeCommands` is a convenience for a
      // machine the user added on purpose and that is somewhere else; this one
      // holds the app's own stores and the user's keys.
      expect(onServer.risk, AskAiCommandRisk.readOnly);
      expect(onServer.canAutoRun, isTrue);
      expect(onDevice.risk, AskAiCommandRisk.readOnly);
      expect(onDevice.onThisDevice, isTrue);
      expect(onDevice.canAutoRun, isFalse);
    });

    test('the model is not told about it unless it is available', () {
      expect(
        buildGlobalAgentInstructions(servers: const []),
        isNot(contains(LocalExec.deviceId)),
      );
      expect(
        buildGlobalAgentInstructions(servers: const [], localExec: true),
        contains(LocalExec.deviceId),
      );
    });
  });
}
