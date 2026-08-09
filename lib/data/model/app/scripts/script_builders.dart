import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';

String _quotePowerShellLiteral(String value) =>
    "'${value.replaceAll("'", "''")}'";

String _powerShellPathExpression(String path) {
  for (final prefix in const [r'$env:TEMP', r'$env:USERPROFILE']) {
    if (path == prefix) return prefix;
    if (path.startsWith('$prefix/') || path.startsWith('$prefix\\')) {
      return '($prefix + ${_quotePowerShellLiteral(path.substring(prefix.length))})';
    }
  }
  return _quotePowerShellLiteral(path);
}

String _quoteUnixLiteral(String value) =>
    "'${value.replaceAll("'", "'\"'\"'")}'";

String _quoteUnixPath(String path) {
  if (path == '~') return r'"$HOME"';
  if (path.startsWith('~/')) {
    return r'"$HOME"/' + _quoteUnixLiteral(path.substring(2));
  }
  return _quoteUnixLiteral(path);
}

String _unixFramedCommand(String marker, String command) =>
    '''
printf '%s\\n' ${_quoteUnixLiteral(marker)}
{
$command
} | sed 's/^/${ScriptConstants.dataPrefix}/'
''';

String _powerShellFramedCommand(String marker, String command) =>
    '''
Write-Output ${_quotePowerShellLiteral(marker)}
& {
$command
} | ForEach-Object {
    ([string]\$_).Replace("`r", "").Split("`n") | ForEach-Object {
        Write-Output "${ScriptConstants.dataPrefix}\$_"
    }
}
''';

/// Abstract base class for platform-specific script builders
sealed class ScriptBuilder {
  const ScriptBuilder();

  /// Generate a complete script for all shell functions
  String buildScript(
    Map<String, String>? customCmds, [
    List<String>? disabledCmdTypes,
  ]);

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
    final dir = _powerShellPathExpression(scriptDir);
    final path = _powerShellPathExpression(scriptPath);
    return 'New-Item -ItemType Directory -Force -Path $dir | Out-Null; '
        '\$content = [System.Console]::In.ReadToEnd(); '
        'Set-Content -Path $path -Value \$content -Encoding UTF8';
  }

  @override
  String getExecCommand(String scriptPath, ShellFunc func) {
    final path = _powerShellPathExpression(scriptPath);
    return 'powershell -ExecutionPolicy Bypass -File $path -${func.flag}';
  }

  @override
  String getCustomCmdsString(ShellFunc func, Map<String, String>? customCmds) {
    if (func == ShellFunc.status &&
        customCmds != null &&
        customCmds.isNotEmpty) {
      final sb = StringBuffer();
      for (final e in customCmds.entries) {
        final cmdDivider = ScriptConstants.getCustomCmdSeparator(e.key);
        final framed = _powerShellFramedCommand(cmdDivider, e.value);
        for (final line in framed.trimRight().split('\n')) {
          sb.writeln('    $line');
        }
      }
      return '\n$sb';
    }
    return '';
  }

  @override
  String buildScript(
    Map<String, String>? customCmds, [
    List<String>? disabledCmdTypes,
  ]) {
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
  String _getWindowsCommand(
    ShellFunc func, [
    List<String>? disabledCmdTypes,
  ]) => switch (func) {
    ShellFunc.status => _getWindowsStatusCommand(
      disabledCmdTypes: disabledCmdTypes ?? [],
    ),
    ShellFunc.process =>
      r'''
$cpuByPid = @{}
try {
    Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop |
        Where-Object { $_.IDProcess -gt 0 } |
        ForEach-Object { $cpuByPid[[int]$_.IDProcess] = [double]$_.PercentProcessorTime }
} catch {}
Get-CimInstance Win32_Process | ForEach-Object {
    $process = $_
    $startId = $null
    try { $startId = $process.CreationDate.ToUniversalTime().Ticks } catch {}
    [PSCustomObject]@{
        ProcessName = $process.Name
        Id = $process.ProcessId
        CPUPercent = $cpuByPid[[int]$process.ProcessId]
        WorkingSet = $process.WorkingSetSize
        IOReadBytes = $process.ReadTransferCount
        IOWriteBytes = $process.WriteTransferCount
        StartId = $startId
        CommandLine = $process.CommandLine
    }
} | ConvertTo-Json -Compress''',
    ShellFunc.shutdown => 'Stop-Computer -Force',
    ShellFunc.reboot => 'Restart-Computer -Force',
    ShellFunc.suspend =>
      'Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Application]::SetSuspendState(\'Suspend\', \$false, \$false)',
  };

  /// Get Windows status command with command-specific separators
  String _getWindowsStatusCommand({required List<String> disabledCmdTypes}) {
    final cmdTypes = WindowsStatusCmdType.values.where(
      (e) => !disabledCmdTypes.contains(e.displayName),
    );
    return cmdTypes
        .map((e) => _powerShellFramedCommand(e.separator, e.cmd))
        .join('')
        .trimRight(); // Remove trailing divider
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
    final dir = _quoteUnixPath(scriptDir);
    final path = _quoteUnixPath(scriptPath);
    return '''
mkdir -p $dir
cat > $path
chmod 755 $path
''';
  }

  @override
  String getExecCommand(String scriptPath, ShellFunc func) {
    return 'sh ${_quoteUnixPath(scriptPath)} -${func.flag}';
  }

  @override
  String getCustomCmdsString(ShellFunc func, Map<String, String>? customCmds) {
    if (func == ShellFunc.status &&
        customCmds != null &&
        customCmds.isNotEmpty) {
      final sb = StringBuffer();
      for (final e in customCmds.entries) {
        final cmdDivider = ScriptConstants.getCustomCmdSeparator(e.key);
        sb.writeln(_unixFramedCommand(cmdDivider, e.value).trimRight());
      }
      return '\n$sb';
    }
    return '';
  }

  @override
  String buildScript(
    Map<String, String>? customCmds, [
    List<String>? disabledCmdTypes,
  ]) {
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
      ShellFunc.status => _getUnixStatusCommand(
        disabledCmdTypes: disabledCmdTypes ?? [],
      ),
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
    final linuxCommands = filteredLinuxCmdTypes
        .map((e) => _unixFramedCommand(e.separator, e.cmd))
        .join('')
        .trimRight();

    final filteredBsdCmdTypes = BSDStatusCmdType.values.where(
      (e) => !disabledCmdTypes.contains(e.displayName),
    );
    final bsdCommands = filteredBsdCmdTypes
        .map((e) => _unixFramedCommand(e.separator, e.cmd))
        .join('')
        .trimRight();

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
\t\tprintf 'PID USER %%CPU %%MEM VSZ RSS TTY STAT TIME START_ID READ_BYTES WRITE_BYTES COMMAND\\n'
\t\tps w | while IFS= read -r line; do
\t\t\tcase "\$line" in PID*) continue ;; esac
\t\t\tset -f
\t\t\tset -- \$line
\t\t\tset +f
\t\t\t[ "\$#" -ge 4 ] || continue
\t\t\tpid=\$1; user=\$2; time=\$3
\t\t\tshift 3
\t\t\tcmd=\$*
\t\t\tstart_id='-'
\t\t\tread_bytes='-'
\t\t\twrite_bytes='-'
\t\t\tif [ -r "/proc/\$pid/stat" ]; then
\t\t\t\tstart_id=\$(sed 's/^.*) //' "/proc/\$pid/stat" | awk '{print \$20}')
\t\t\t\t[ -n "\$start_id" ] || start_id='-'
\t\t\tfi
\t\t\tif [ -r "/proc/\$pid/io" ]; then
\t\t\t\tread_bytes=\$(awk '/^read_bytes:/ {print \$2}' "/proc/\$pid/io")
\t\t\t\twrite_bytes=\$(awk '/^write_bytes:/ {print \$2}' "/proc/\$pid/io")
\t\t\t\t[ -n "\$read_bytes" ] || read_bytes='-'
\t\t\t\t[ -n "\$write_bytes" ] || write_bytes='-'
\t\t\tfi
\t\t\tprintf '%s %s - - - - - - %s %s %s %s %s\\n' "\$pid" "\$user" "\$time" "\$start_id" "\$read_bytes" "\$write_bytes" "\$cmd"
\t\tdone
\telse
\t\tprintf 'PID USER %%CPU %%MEM VSZ RSS TTY STAT TIME START_ID READ_BYTES WRITE_BYTES COMMAND\\n'
\t\tps -axo pid=,user=,%cpu=,%mem=,vsz=,rss=,tty=,stat=,time=,args= | while IFS= read -r line; do
\t\t\tset -f
\t\t\tset -- \$line
\t\t\tset +f
\t\t\tpid=\$1; user=\$2; cpu=\$3; mem=\$4; vsz=\$5; rss=\$6; tty=\$7; stat=\$8; time=\$9
\t\t\tshift 9
\t\t\tcmd=\$*
\t\t\tstart_id='-'
\t\t\tread_bytes='-'
\t\t\twrite_bytes='-'
\t\t\tif [ -r "/proc/\$pid/stat" ]; then
\t\t\t\tstart_id=\$(sed 's/^.*) //' "/proc/\$pid/stat" | awk '{print \$20}')
\t\t\t\t[ -n "\$start_id" ] || start_id='-'
\t\t\tfi
\t\t\tif [ -r "/proc/\$pid/io" ]; then
\t\t\t\tread_bytes=\$(awk '/^read_bytes:/ {print \$2}' "/proc/\$pid/io")
\t\t\t\twrite_bytes=\$(awk '/^write_bytes:/ {print \$2}' "/proc/\$pid/io")
\t\t\tfi
\t\t\tprintf '%s %s %s %s %s %s %s %s %s %s %s %s %s\\n' "\$pid" "\$user" "\$cpu" "\$mem" "\$vsz" "\$rss" "\$tty" "\$stat" "\$time" "\$start_id" "\$read_bytes" "\$write_bytes" "\$cmd"
\t\tdone
\tfi
else
\tprintf 'PID USER %%CPU %%MEM VSZ RSS TTY STAT TIME START COMMAND\\n'
\tps -axo pid=,user=,%cpu=,%mem=,vsz=,rss=,tty=,state=,time=,start=,command=
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
