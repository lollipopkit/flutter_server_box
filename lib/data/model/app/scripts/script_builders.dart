import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';

/// Abstract base class for platform-specific script builders
sealed class ScriptBuilder {
  const ScriptBuilder();

  /// Generate a complete script for all shell functions
  String buildScript(Map<String, String>? customCmds, [List<String>? disabledCmdTypes]);

  /// Get the script file name for this platform
  String get scriptFileName;

  /// Get the command to install the script
  String getInstallCommand(String scriptDir, String scriptPath);

  /// Get the execution command for a specific function
  String getExecCommand(String scriptPath, ShellFunc func);

  /// Get custom commands string for this platform
  String getCustomCmdsString(ShellFunc func, Map<String, String>? customCmds);

  /// Get the script header for this platform
  String get scriptHeader;
}

/// Windows PowerShell script builder
class WindowsScriptBuilder extends ScriptBuilder {
  const WindowsScriptBuilder();

  @override
  String get scriptFileName => ScriptConstants.scriptFileWindows;

  @override
  String get scriptHeader => ScriptConstants.windowsScriptHeader;

  @override
  String getInstallCommand(String scriptDir, String scriptPath) {
    return 'New-Item -ItemType Directory -Force -Path \'$scriptDir\' | Out-Null; '
        '\$content = [System.Console]::In.ReadToEnd(); '
        'Set-Content -Path \'$scriptPath\' -Value \$content -Encoding UTF8';
  }

  @override
  String getExecCommand(String scriptPath, ShellFunc func) {
    return 'powershell -ExecutionPolicy Bypass -File "$scriptPath" -${func.flag}';
  }

  @override
  String getCustomCmdsString(ShellFunc func, Map<String, String>? customCmds) {
    if (func == ShellFunc.status && customCmds != null && customCmds.isNotEmpty) {
      final sb = StringBuffer();
      for (final e in customCmds.entries) {
        final cmdDivider = ScriptConstants.getCustomCmdSeparator(e.key);
        sb.writeln('    Write-Host "$cmdDivider"');
        sb.writeln('    ${e.value}');
      }
      return '\n$sb';
    }
    return '';
  }

  @override
  String buildScript(Map<String, String>? customCmds, [List<String>? disabledCmdTypes]) {
    final sb = StringBuffer();
    sb.write(scriptHeader);

    // Write each function
    for (final func in ShellFunc.values) {
      final customCmdsStr = getCustomCmdsString(func, customCmds);

      sb.write('''
function ${func.name} {
    ${_getWindowsCommand(func, disabledCmdTypes).split('\n').map((e) => e.isEmpty ? '' : '    $e').join('\n')}$customCmdsStr
}

''');
    }

    // Write switch case
    sb.write('''
switch (\$args[0]) {
''');
    for (final func in ShellFunc.values) {
      sb.write('''
    "-${func.flag}" { ${func.name} }
''');
    }
    sb.write('''
    default { Write-Host "Invalid argument \$(\$args[0])" }
}
''');
    return sb.toString();
  }

  /// Get Windows-specific command for a shell function
  String _getWindowsCommand(ShellFunc func, [List<String>? disabledCmdTypes]) => switch (func) {
    ShellFunc.status => _getWindowsStatusCommand(disabledCmdTypes: disabledCmdTypes ?? []),
    ShellFunc.process => 'Get-Process | Select-Object ProcessName, Id, CPU, WorkingSet | ConvertTo-Json',
    ShellFunc.shutdown => 'Stop-Computer -Force',
    ShellFunc.reboot => 'Restart-Computer -Force',
    ShellFunc.suspend =>
      'Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Application]::SetSuspendState(\'Suspend\', \$false, \$false)',
  };

  /// Get Windows status command with command-specific separators
  String _getWindowsStatusCommand({required List<String> disabledCmdTypes}) {
    final cmdTypes = WindowsStatusCmdType.values.where((e) => !disabledCmdTypes.contains(e.displayName));
    return cmdTypes.map((e) => '${e.divider}${e.cmd}').join('').trimRight(); // Remove trailing divider
  }
}

/// Unix shell script builder
class UnixScriptBuilder extends ScriptBuilder {
  const UnixScriptBuilder();

  @override
  String get scriptFileName => ScriptConstants.scriptFile;

  @override
  String get scriptHeader => ScriptConstants.unixScriptHeader;

  @override
  String getInstallCommand(String scriptDir, String scriptPath) {
    return '''
mkdir -p $scriptDir
cat > $scriptPath
chmod 755 $scriptPath
''';
  }

  @override
  String getExecCommand(String scriptPath, ShellFunc func) {
    return 'sh $scriptPath -${func.flag}';
  }

  @override
  String getCustomCmdsString(ShellFunc func, Map<String, String>? customCmds) {
    if (func == ShellFunc.status && customCmds != null && customCmds.isNotEmpty) {
      final sb = StringBuffer();
      for (final e in customCmds.entries) {
        final cmdDivider = ScriptConstants.getCustomCmdSeparator(e.key);
        sb.writeln('echo "$cmdDivider"');
        sb.writeln(e.value);
      }
      return '\n$sb';
    }
    return '';
  }

  @override
  String buildScript(Map<String, String>? customCmds, [List<String>? disabledCmdTypes]) {
    final sb = StringBuffer();
    sb.write(scriptHeader);
    // Write each function
    for (final func in ShellFunc.values) {
      final customCmdsStr = getCustomCmdsString(func, customCmds);
      sb.write('''
${func.name}() {
${_getUnixCommand(func, disabledCmdTypes).split('\n').map((e) => '\t$e').join('\n')}
$customCmdsStr
}

''');
    }

    // Write switch case
    sb.write('case \$1 in\n');
    for (final func in ShellFunc.values) {
      sb.write('''
  '-${func.flag}')
    ${func.name}
    ;;
''');
    }
    sb.write('''
  *)
    echo "Invalid argument \$1"
    ;;
esac''');
    return sb.toString();
  }

  /// Get Unix-specific command for a shell function
  String _getUnixCommand(ShellFunc func, [List<String>? disabledCmdTypes]) {
    return switch (func) {
      ShellFunc.status => _getUnixStatusCommand(disabledCmdTypes: disabledCmdTypes ?? []),
      ShellFunc.process => _getUnixProcessCommand(),
      ShellFunc.shutdown => _getUnixShutdownCommand(),
      ShellFunc.reboot => _getUnixRebootCommand(),
      ShellFunc.suspend => _getUnixSuspendCommand(),
    };
  }

  /// Get Unix status command with OS detection
  String _getUnixStatusCommand({required List<String> disabledCmdTypes}) {
    // Generate command lists with command-specific separators, filtering disabled commands
    final filteredLinuxCmdTypes = StatusCmdType.values.where(
      (e) => !disabledCmdTypes.contains(e.displayName),
    );
    final linuxCommands = filteredLinuxCmdTypes.map((e) => '${e.divider}${e.cmd}').join('').trimRight();

    final filteredBsdCmdTypes = BSDStatusCmdType.values.where(
      (e) => !disabledCmdTypes.contains(e.displayName),
    );
    final bsdCommands = filteredBsdCmdTypes.map((e) => '${e.divider}${e.cmd}').join('').trimRight();

    return '''
if [ "\$macSign" = "" ] && [ "\$bsdSign" = "" ]; then
\t$linuxCommands
else
\t$bsdCommands
fi''';
  }

  /// Get Unix process command with busybox detection
  String _getUnixProcessCommand() {
    return '''
if [ "\$macSign" = "" ] && [ "\$bsdSign" = "" ]; then
\tif [ "\$isBusybox" != "" ]; then
\t\tps w
\telse
\t\tps -aux
\tfi
else
\tps -ax
fi''';
  }

  /// Get Unix shutdown command with privilege detection
  String _getUnixShutdownCommand() {
    return '''
if [ "\$userId" = "0" ]; then
\tshutdown -h now
else
\tsudo -S shutdown -h now
fi''';
  }

  /// Get Unix reboot command with privilege detection
  String _getUnixRebootCommand() {
    return '''
if [ "\$userId" = "0" ]; then
\treboot
else
\tsudo -S reboot
fi''';
  }

  /// Get Unix suspend command with privilege detection
  String _getUnixSuspendCommand() {
    return '''
if [ "\$userId" = "0" ]; then
\tsystemctl suspend
else
\tsudo -S systemctl suspend
fi''';
  }
}

/// Factory class to get appropriate script builder for platform
class ScriptBuilderFactory {
  const ScriptBuilderFactory._();

  /// Get the appropriate script builder based on platform
  static ScriptBuilder getBuilder(bool isWindows) {
    return isWindows ? const WindowsScriptBuilder() : const UnixScriptBuilder();
  }

  /// Get all available builders (useful for testing)
  static List<ScriptBuilder> getAllBuilders() {
    return const [WindowsScriptBuilder(), UnixScriptBuilder()];
  }
}
