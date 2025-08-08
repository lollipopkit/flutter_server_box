import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/script_builders.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/system.dart';

void main() {
  group('Script Builder Integration Tests', () {
    test('script generation produces valid output for all platforms', () {
      for (final builder in ScriptBuilderFactory.getAllBuilders()) {
        final script = builder.buildScript(null);

        // Basic validation
        expect(script, isNotEmpty, reason: 'Script should not be empty for ${builder.runtimeType}');

        // Should contain all required functions
        for (final func in ShellFunc.values) {
          expect(script, contains(func.name), reason: 'Script should contain function ${func.name}');
        }

        // Should contain proper headers
        expect(script, contains(builder.scriptHeader), reason: 'Script should contain proper header');

        // Should be well-formed
        if (builder is WindowsScriptBuilder) {
          expect(
            script,
            contains('switch (\$args[0])'),
            reason: 'Windows script should contain switch statement',
          );
          expect(
            script,
            contains('PowerShell script for ServerBox'),
            reason: 'Windows script should have PowerShell header',
          );
        } else if (builder is UnixScriptBuilder) {
          expect(script, contains('#!/bin/sh'), reason: 'Unix script should have shebang');
          expect(script, contains('case \$1 in'), reason: 'Unix script should contain case statement');
        }
      }
    });

    test('script generation with custom commands works correctly', () {
      final customCmds = {'custom_test': 'echo "Custom test command"', 'another_cmd': 'whoami'};

      for (final builder in ScriptBuilderFactory.getAllBuilders()) {
        final script = builder.buildScript(customCmds);

        expect(script, isNotEmpty);

        // Custom commands should only be included in status function for both platforms
        if (builder is UnixScriptBuilder) {
          expect(script, contains('echo "Custom test command"'));
          expect(script, contains('whoami'));
        }

        // Windows builder should include custom commands in SbStatus function
        if (builder is WindowsScriptBuilder) {
          expect(script, contains('echo "Custom test command"'));
          expect(script, contains('whoami'));
        }
      }
    });

    test('script file names are correct for each platform', () {
      final windowsBuilder = ScriptBuilderFactory.getBuilder(true);
      final unixBuilder = ScriptBuilderFactory.getBuilder(false);

      expect(windowsBuilder.scriptFileName, equals(ScriptConstants.scriptFileWindows));
      expect(windowsBuilder.scriptFileName, endsWith('.ps1'));

      expect(unixBuilder.scriptFileName, equals(ScriptConstants.scriptFile));
      expect(unixBuilder.scriptFileName, endsWith('.sh'));
    });

    test('install commands are generated correctly', () {
      const testDir = '/tmp/test';
      const testPath = '/tmp/test/script.sh';

      final unixBuilder = ScriptBuilderFactory.getBuilder(false);
      final installCmd = unixBuilder.getInstallCommand(testDir, testPath);

      expect(installCmd, contains('mkdir'));
      expect(installCmd, contains('chmod 755'));
      expect(installCmd, contains(testPath));

      const testDirWindows = 'C:\\temp\\test';
      const testPathWindows = 'C:\\temp\\test\\script.ps1';

      final windowsBuilder = ScriptBuilderFactory.getBuilder(true);
      final installCmdWindows = windowsBuilder.getInstallCommand(testDirWindows, testPathWindows);

      expect(installCmdWindows, contains('New-Item'));
      expect(installCmdWindows, contains('Set-Content'));
      expect(installCmdWindows, contains(testPathWindows));
    });

    test('exec commands are generated correctly for all platforms', () {
      const testPath = '/tmp/test/script.sh';
      const testPathWindows = 'C:\\temp\\test\\script.ps1';

      final unixBuilder = ScriptBuilderFactory.getBuilder(false);
      final windowsBuilder = ScriptBuilderFactory.getBuilder(true);

      for (final func in ShellFunc.values) {
        final unixExec = unixBuilder.getExecCommand(testPath, func);
        expect(unixExec, contains(testPath));
        expect(unixExec, contains(func.flag));

        final windowsExec = windowsBuilder.getExecCommand(testPathWindows, func);
        expect(windowsExec, contains('powershell'));
        expect(windowsExec, contains('-ExecutionPolicy Bypass'));
        expect(windowsExec, contains(func.flag));
      }
    });

    test('script headers contain proper metadata', () {
      final windowsBuilder = ScriptBuilderFactory.getBuilder(true);
      final unixBuilder = ScriptBuilderFactory.getBuilder(false);

      expect(windowsBuilder.scriptHeader, contains('PowerShell script for ServerBox'));
      expect(windowsBuilder.scriptHeader, contains('DO NOT delete this file'));
      expect(windowsBuilder.scriptHeader, contains('\$ErrorActionPreference = "SilentlyContinue"'));

      expect(unixBuilder.scriptHeader, contains('#!/bin/sh'));
      expect(unixBuilder.scriptHeader, contains('Script for ServerBox'));
      expect(unixBuilder.scriptHeader, contains('DO NOT delete this file'));
      expect(unixBuilder.scriptHeader, contains('export LANG=en_US.UTF-8'));
    });

    test('scripts handle all system types properly', () {
      // Test that system type detection is properly handled
      final unixScript = ShellFuncManager.allScript(null, systemType: SystemType.linux);
      final bsdScript = ShellFuncManager.allScript(null, systemType: SystemType.bsd);
      final windowsScript = ShellFuncManager.allScript(null, systemType: SystemType.windows);

      expect(unixScript, contains('#!/bin/sh'));
      expect(bsdScript, contains('#!/bin/sh')); // BSD uses same script as Linux
      expect(windowsScript, contains('PowerShell script'));

      // Verify OS detection logic in Unix script
      expect(unixScript, contains('macSign='));
      expect(unixScript, contains('bsdSign='));
      expect(unixScript, contains('isBusybox='));
    });

    test('error handling in script generation', () {
      // Test that script generation doesn't throw with edge cases
      expect(() => ShellFuncManager.allScript({}, systemType: SystemType.linux), returnsNormally);
      expect(() => ShellFuncManager.allScript(null, systemType: SystemType.windows), returnsNormally);

      // Test with empty custom commands
      expect(() => ShellFuncManager.allScript({}, systemType: SystemType.bsd), returnsNormally);

      // Test with null system type (should default to something)
      expect(() => ShellFuncManager.allScript(null), returnsNormally);
    });
  });

  group('ScriptBuilderFactory Tests', () {
    test('factory returns correct builder types', () {
      final windowsBuilder = ScriptBuilderFactory.getBuilder(true);
      final unixBuilder = ScriptBuilderFactory.getBuilder(false);

      expect(windowsBuilder, isA<WindowsScriptBuilder>());
      expect(unixBuilder, isA<UnixScriptBuilder>());
    });

    test('getAllBuilders returns all available builders', () {
      final builders = ScriptBuilderFactory.getAllBuilders();

      expect(builders, hasLength(2));
      expect(builders.any((b) => b is WindowsScriptBuilder), isTrue);
      expect(builders.any((b) => b is UnixScriptBuilder), isTrue);
    });
  });
}
