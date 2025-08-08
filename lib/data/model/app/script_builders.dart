import 'package:server_box/data/model/app/shell_func.dart';
import 'package:server_box/data/res/build_data.dart';

/// Abstract base class for platform-specific script builders
abstract class ScriptBuilder {
  const ScriptBuilder();

  /// Generate a complete script for all shell functions
  String buildScript(Map<String, String>? customCmds);
  
  /// Get the script file name for this platform
  String get scriptFileName;
  
  /// Get the command to install the script
  String getInstallCommand(String scriptDir, String scriptPath);
  
  /// Get the execution command for a specific function
  String getExecCommand(String scriptPath, ShellFunc func);
  
  /// Get custom commands string for this platform
  String getCustomCmdsString(
    ShellFunc func, 
    Map<String, String>? customCmds,
  );
}

/// Windows PowerShell script builder
class WindowsScriptBuilder extends ScriptBuilder {
  const WindowsScriptBuilder();

  @override
  String get scriptFileName => 'srvboxm_v${BuildData.script}.ps1';

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
  String getCustomCmdsString(
    ShellFunc func, 
    Map<String, String>? customCmds,
  ) {
    if (func == ShellFunc.status && customCmds != null && customCmds.isNotEmpty) {
      return '\n${customCmds.values.map((cmd) => '\t$cmd').join('\n')}';
    }
    return '';
  }

  @override
  String buildScript(Map<String, String>? customCmds) {
    final sb = StringBuffer();
    sb.write('''
# PowerShell script for ServerBox app v1.0.${BuildData.build}
# DO NOT delete this file while app is running

\$ErrorActionPreference = "SilentlyContinue"

''');

    // Write each function
    for (final func in ShellFunc.values) {
      final customCmdsStr = getCustomCmdsString(func, customCmds);

      sb.write('''
function ${func.name} {
    ${_getWindowsCommand(func).split('\n').map((e) => e.isEmpty ? '' : '    $e').join('\n')}$customCmdsStr
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

  String _getWindowsCommand(ShellFunc func) => switch (func) {
    ShellFunc.status => WindowsStatusCmdType.values.map((e) => e.cmd).join(ShellFunc.cmdDivider),
    ShellFunc.process => 'Get-Process | Select-Object ProcessName, Id, CPU, WorkingSet | ConvertTo-Json',
    ShellFunc.shutdown => 'Stop-Computer -Force',
    ShellFunc.reboot => 'Restart-Computer -Force',
    ShellFunc.suspend => 
      'Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Application]::SetSuspendState(\'Suspend\', \$false, \$false)',
  };
}

/// Unix shell script builder  
class UnixScriptBuilder extends ScriptBuilder {
  const UnixScriptBuilder();

  @override
  String get scriptFileName => 'srvboxm_v${BuildData.script}.sh';

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
  String getCustomCmdsString(
    ShellFunc func, 
    Map<String, String>? customCmds,
  ) {
    if (func == ShellFunc.status && customCmds != null && customCmds.isNotEmpty) {
      return '${ShellFunc.cmdDivider}\n\t${customCmds.values.join(ShellFunc.cmdDivider)}';
    }
    return '';
  }

  @override
  String buildScript(Map<String, String>? customCmds) {
    final sb = StringBuffer();
    sb.write('''
#!/bin/sh
# Script for ServerBox app v1.0.${BuildData.build}
# DO NOT delete this file while app is running

export LANG=en_US.UTF-8

# If macSign & bsdSign are both empty, then it's linux
macSign=\$(uname -a 2>&1 | grep "Darwin")
bsdSign=\$(uname -a 2>&1 | grep "BSD")

# Link /bin/sh to busybox?
isBusybox=\$(ls -l /bin/sh | grep "busybox")

userId=\$(id -u)

exec 2>/dev/null

''');
    // Write each function
    for (final func in ShellFunc.values) {
      final customCmdsStr = getCustomCmdsString(func, customCmds);
      sb.write('''
${func.name}() {
${_getUnixCommand(func).split('\n').map((e) => '\t$e').join('\n')}
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

  String _getUnixCommand(ShellFunc func) {
    switch (func) {
      case ShellFunc.status:
        return '''
if [ "\$macSign" = "" ] && [ "\$bsdSign" = "" ]; then
\t${StatusCmdType.values.map((e) => e.cmd).join(ShellFunc.cmdDivider)}
else
\t${BSDStatusCmdType.values.map((e) => e.cmd).join(ShellFunc.cmdDivider)}
fi''';
      case ShellFunc.process:
        return '''
if [ "\$macSign" = "" ] && [ "\$bsdSign" = "" ]; then
\tif [ "\$isBusybox" != "" ]; then
\t\tps w
\telse
\t\tps -aux
\tfi
else
\tps -ax
fi
''';
      case ShellFunc.shutdown:
        return '''
if [ "\$userId" = "0" ]; then
\tshutdown -h now
else
\tsudo -S shutdown -h now
fi''';
      case ShellFunc.reboot:
        return '''
if [ "\$userId" = "0" ]; then
\treboot
else
\tsudo -S reboot
fi''';
      case ShellFunc.suspend:
        return '''
if [ "\$userId" = "0" ]; then
\tsystemctl suspend
else
\tsudo -S systemctl suspend
fi''';
    }
  }
}

/// Factory class to get appropriate script builder for platform
class ScriptBuilderFactory {
  const ScriptBuilderFactory._();

  static ScriptBuilder getBuilder(bool isWindows) {
    return isWindows ? const WindowsScriptBuilder() : const UnixScriptBuilder();
  }
}