import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';

import '../../helpers/rust_lib_helper.dart';

AskAiCommand _call(String name, Map<String, Object?> args) =>
    AskAiCommand.fromToolCall(id: 'call-1', name: name, args: args);

void main() {
  // The command risk is `sbm_parser::command_risk`, over FFI.
  setUpAll(initRustLibForTest);

  group('a tool call, as the app reviews it', () {
    test('says in one line what each tool is about', () {
      expect(_call('run_shell_command', {'command': ' ls -la '}).command, 'ls -la');
      expect(_call('read_file', {'path': '/etc/hosts'}).command, '/etc/hosts');
      expect(_call('serverbox', {'action': 'list_servers'}).command, 'list_servers');
      expect(_call('ssh_connect', {'host': '10.0.0.2'}).command, '10.0.0.2');
      expect(_call('ssh_disconnect', {'session_id': 's1'}).command, 's1');
    });

    test('reads the two flags leniently, and false when left out', () {
      // A model that spelled one loosely used to lose the whole call.
      final loose = _call('run_shell_command', {
        'command': 'uptime',
        'safe_to_run': 'true',
        'destructive': 0,
      });
      expect(loose.modelSafeToRun, isTrue);
      expect(loose.modelDestructive, isFalse);

      final bare = _call('run_shell_command', {'command': 'uptime'});
      expect(bare.modelSafeToRun, isFalse);
      expect(bare.modelDestructive, isFalse);
    });

    test('keeps the arguments, for the tools that read more of them', () {
      final call = _call('run_shell_command', {
        'server_id': 'srv-1',
        'command': 'df -h',
        'description': 'Disk usage.',
      });
      expect(call.serverId, 'srv-1');
      expect(call.description, 'Disk usage.');
      expect(call.risk, AskAiCommandRisk.readOnly);
    });

    test('a destructive word from the model is enough to ask', () {
      final call = _call('run_shell_command', {
        'command': 'ls',
        'safe_to_run': true,
        'destructive': true,
      });
      expect(call.risk, AskAiCommandRisk.destructive);
      expect(call.canAutoRun, isFalse);
    });
  });
}
