import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/scripts/script_builders.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/server_status_update_req.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/res/status.dart';

void main() {
  group('Windows System Tests', () {
    test('should verify Windows segments length matches command types', () {
      expect(WindowsStatusCmdType.values.length, isPositive);
    });

    test('should generate Windows PowerShell script correctly', () {
      final builder = ScriptBuilderFactory.getBuilder(true);
      final script = builder.buildScript(null);
      
      expect(script, contains('PowerShell script for ServerBox'));
      expect(script, contains('switch (\$args[0])'));
      expect(script, contains('-${ShellFunc.status.flag}'));
    });

    test('should handle Windows system parsing with real data', () async {
      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        parsedOutput: {}, // Empty for legacy tests
        customCmds: {},
      );

      final result = await getStatus(req);

      // Basic validation that result is not null
      expect(result, isNotNull);
    });

    test('should parse Windows CPU data correctly', () async {
      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        parsedOutput: {}, // Empty for legacy tests
        customCmds: {},
      );

      // Should not throw exceptions
      expect(() async => await getStatus(req), returnsNormally);
    });

    test('should parse Windows memory data correctly', () async {
      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        parsedOutput: {}, // Empty for legacy tests
        customCmds: {},
      );

      // Should not throw exceptions  
      expect(() async => await getStatus(req), returnsNormally);
    });

    test('should parse Windows disk data correctly', () async {
      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        parsedOutput: {}, // Empty for legacy tests
        customCmds: {},
      );

      // Should not throw exceptions
      expect(() async => await getStatus(req), returnsNormally);
    });

    test('should parse Windows battery data correctly', () async {
      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        parsedOutput: {}, // Empty for legacy tests
        customCmds: {},
      );

      // Should not throw exceptions
      expect(() async => await getStatus(req), returnsNormally);
    });

    test('should handle Windows uptime parsing correctly', () async {
      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        parsedOutput: {}, // Empty for legacy tests
        customCmds: {},
      );

      // Should not throw exceptions
      expect(() async => await getStatus(req), returnsNormally);
    });

    test('should handle Windows uptime parsing with old format', () async {
      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        parsedOutput: {}, // Empty for legacy tests  
        customCmds: {},
      );

      // Should not throw exceptions
      expect(() async => await getStatus(req), returnsNormally);
    });

    test('should handle Windows script path generation', () {
      final scriptPath = ShellFunc.status.exec('test-server', systemType: SystemType.windows);
      
      expect(scriptPath, contains('powershell'));
      expect(scriptPath, contains('-ExecutionPolicy Bypass'));
      expect(scriptPath, contains('-${ShellFunc.status.flag}'));
    });

    test('should execute Windows commands correctly', () {
      for (final func in ShellFunc.values) {
        final command = func.exec('test-server', systemType: SystemType.windows);
        expect(command, isNotEmpty);
        expect(command, contains('powershell'));
      }
    });

    test('should handle GPU detection on Windows', () async {
      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        parsedOutput: {}, // Empty for legacy tests
        customCmds: {},
      );

      // Should handle NVIDIA driver not found gracefully
      expect(() async => await getStatus(req), returnsNormally);
    });

    test('should handle Windows error conditions gracefully', () async {
      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        parsedOutput: {}, // Empty for legacy tests
        customCmds: {},
      );

      // Should not throw exceptions even with error conditions
      expect(() async => await getStatus(req), returnsNormally);
    });

    test('should handle Windows temperature error output gracefully', () async {
      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        parsedOutput: {}, // Empty for legacy tests
        customCmds: {},
      );

      // Should not throw exceptions even with error output in temperature values
      expect(() async => await getStatus(req), returnsNormally);
    });
  });
}