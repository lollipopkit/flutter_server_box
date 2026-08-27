import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/system.dart';

import 'rust_lib_helper.dart';

void main() {
  setUpAll(initRustLibForTest);

  group('Windows command generation', () {
    test('should generate Windows PowerShell script correctly', () {
      final script = ShellFuncManager.allScript(systemType: SystemType.windows);

      expect(script, contains('PowerShell script for ServerBox'));
      expect(script, contains('switch (\$args[0])'));
      expect(script, contains('-${ShellFunc.status.flag}'));
    });

    test('should handle Windows script path generation', () {
      final scriptPath = ShellFunc.status.exec(
        'test-server',
        systemType: SystemType.windows,
        customDir: null,
      );

      expect(scriptPath, contains('powershell'));
      expect(scriptPath, contains('-ExecutionPolicy Bypass'));
      expect(
        _decodePowerShellCommand(scriptPath),
        contains('-${ShellFunc.status.flag}'),
      );
    });

    test('should execute Windows commands correctly', () {
      for (final func in ShellFunc.values) {
        final command = func.exec(
          'test-server',
          systemType: SystemType.windows,
          customDir: null,
        );
        expect(command, isNotEmpty);
        expect(command, contains('powershell'));
      }
    });
  });
}

String _decodePowerShellCommand(String command) {
  final encoded = command.split(' -EncodedCommand ').last;
  final bytes = base64.decode(encoded);
  final units = <int>[
    for (var i = 0; i + 1 < bytes.length; i += 2)
      bytes[i] | (bytes[i + 1] << 8),
  ];
  return String.fromCharCodes(units);
}
