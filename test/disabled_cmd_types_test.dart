import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/system.dart';

void main() {
  group('disabledCmdTypes filtering', () {
    test('filters Linux status commands when disabled', () {
      final disabled = <String>{
        StatusCmdType.net.displayName,
        StatusCmdType.sys.displayName,
      }.toList();

      final script = ShellFuncManager.allScript(
        null,
        systemType: SystemType.linux,
        disabledCmdTypes: disabled,
      );

      // Linux-specific commands should be removed
      expect(script, isNot(contains('cat /proc/net/dev'))); // net
      expect(script, isNot(contains('cat /etc/*-release | grep ^PRETTY_NAME'))); // sys

      // Other commands should remain
      expect(script, contains('uptime'));
      expect(script, contains('date +%s'));
    });

    test('filters BSD status commands when disabled', () {
      final disabled = <String>{
        BSDStatusCmdType.sys.displayName,
        BSDStatusCmdType.mem.displayName,
      }.toList();

      final script = ShellFuncManager.allScript(
        null,
        systemType: SystemType.linux, // Unix builder is used for Linux/BSD
        disabledCmdTypes: disabled,
      );

      // BSD-specific commands should be removed
      expect(script, isNot(contains('uname -or'))); // sys
      expect(script, isNot(contains('top -l 1 | grep PhysMem'))); // mem

      // Linux equivalents should remain
      expect(script, contains('cat /etc/*-release | grep ^PRETTY_NAME'));
      expect(script, contains("cat /proc/meminfo | grep -E 'Mem|Swap'"));
    });

    test('filters Windows status commands when disabled', () {
      final disabled = <String>{
        WindowsStatusCmdType.net.displayName,
        WindowsStatusCmdType.uptime.displayName,
        WindowsStatusCmdType.temp.displayName,
      }.toList();

      final script = ShellFuncManager.allScript(
        null,
        systemType: SystemType.windows,
        disabledCmdTypes: disabled,
      );

      // Windows-specific commands should be removed
      expect(script, isNot(contains('LastBootUpTime'))); // uptime
      expect(script, isNot(contains('MSAcpi_ThermalZoneTemperature'))); // temp

      // Other Windows commands should remain
      expect(script, contains('Get-Process'));
      expect(script, contains('Get-WmiObject -Class Win32_OperatingSystem'));
    });

    test('ignores disabled names for other platforms', () {
      final disabled = <String>{
        WindowsStatusCmdType.sys.displayName,
        WindowsStatusCmdType.net.displayName,
      }.toList();

      final script = ShellFuncManager.allScript(
        null,
        systemType: SystemType.linux,
        disabledCmdTypes: disabled,
      );

      // Linux commands should not be affected by Windows-only disables
      expect(script, contains('cat /etc/*-release | grep ^PRETTY_NAME'));
      expect(script, contains('cat /proc/net/dev'));
    });

    test('disabling all status commands removes separators', () {
      final allUnixDisabled = <String>{
        ...StatusCmdType.values.map((e) => e.displayName),
        ...BSDStatusCmdType.values.map((e) => e.displayName),
      }.toList();

      final unixScript = ShellFuncManager.allScript(
        null,
        systemType: SystemType.linux,
        disabledCmdTypes: allUnixDisabled,
      );

      // No status separators for Unix script
      expect(unixScript, isNot(contains('SrvBoxSep.')));

      final allWinDisabled = <String>{
        ...WindowsStatusCmdType.values.map((e) => e.displayName),
      }.toList();

      final windowsScript = ShellFuncManager.allScript(
        null,
        systemType: SystemType.windows,
        disabledCmdTypes: allWinDisabled,
      );

      // No status separators for Windows script
      expect(windowsScript, isNot(contains('SrvBoxSep.')));
    });
  });
}

