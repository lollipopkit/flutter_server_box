import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/server.dart';
import 'package:server_box/data/res/build_data.dart';

enum ShellFunc {
  status,
  //docker,
  process,
  shutdown,
  reboot,
  suspend;

  static const seperator = 'SrvBoxSep';

  /// The suffix `\t` is for formatting
  static const cmdDivider = '\necho $seperator\n\t';

  /// Cached Linux status commands string
  static final _linuxStatusCmds = StatusCmdType.values.map((e) => e.cmd).join(cmdDivider);

  /// Cached BSD status commands string
  static final _bsdStatusCmds = BSDStatusCmdType.values.map((e) => e.cmd).join(cmdDivider);

  /// Cached Windows status commands string
  static final _windowsStatusCmds = WindowsStatusCmdType.values.map((e) => e.cmd).join(cmdDivider);

  /// srvboxm -> ServerBox Mobile
  static const scriptFile = 'srvboxm_v${BuildData.script}.sh';
  static const scriptFileWindows = 'srvboxm_v${BuildData.script}.ps1';
  static const scriptDirHome = '~/.config/server_box';
  static const scriptDirTmp = '/tmp/server_box';
  static const scriptDirHomeWindows = '%USERPROFILE%/.config/server_box';
  static const scriptDirTmpWindows = '%TEMP%/server_box';

  static final _scriptDirMap = <String, String>{};

  /// Get the script directory for the given [id].
  ///
  /// Default is [scriptDirTmp]/[scriptFile], if this path is not accessible,
  /// it will be changed to [scriptDirHome]/[scriptFile].
  static String getScriptDir(String id) {
    final customScriptDir = ServerProvider.pick(id: id)?.value.spi.custom?.scriptDir;
    if (customScriptDir != null) return customScriptDir;
    _scriptDirMap[id] ??= scriptDirTmp;
    return _scriptDirMap[id]!;
  }

  static void switchScriptDir(String id) => switch (_scriptDirMap[id]) {
    scriptDirTmp => _scriptDirMap[id] = scriptDirHome,
    scriptDirHome => _scriptDirMap[id] = scriptDirTmp,
    _ => _scriptDirMap[id] = scriptDirHome,
  };

  static String getScriptPath(String id, {SystemType? systemType}) {
    final dir = getScriptDir(id);
    final fileName = systemType == SystemType.windows ? scriptFileWindows : scriptFile;
    return '$dir/$fileName';
  }

  static String getInstallShellCmd(String id, {SystemType? systemType}) {
    final scriptDir = getScriptDir(id);
    final fileName = systemType == SystemType.windows ? scriptFileWindows : scriptFile;
    final scriptPath = '$scriptDir/$fileName';
    
    if (systemType == SystemType.windows) {
      return '''
New-Item -ItemType Directory -Force -Path "$scriptDir"
Set-Content -Path "$scriptPath" -Value \$input
''';
    } else {
      return '''
mkdir -p $scriptDir
cat > $scriptPath
chmod 755 $scriptPath
''';
    }
  }

  String get flag => switch (this) {
    ShellFunc.process => 'p',
    ShellFunc.shutdown => 'sd',
    ShellFunc.reboot => 'r',
    ShellFunc.suspend => 'sp',
    ShellFunc.status => 's',
    // ShellFunc.docker=> 'd',
  };

  String exec(String id, {SystemType? systemType}) {
    final scriptPath = getScriptPath(id, systemType: systemType);
    if (systemType == SystemType.windows) {
      return 'powershell -ExecutionPolicy Bypass -File "$scriptPath" -$flag';
    } else {
      return 'sh $scriptPath -$flag';
    }
  }

  /// Legacy exec method that tries to execute both script types
  /// Used when system type is unknown
  String execLegacy(String id) {
    final unixPath = getScriptPath(id, systemType: SystemType.linux);
    final windowsPath = getScriptPath(id, systemType: SystemType.windows);
    return 'if [ -f "$windowsPath" ]; then powershell -ExecutionPolicy Bypass -File "$windowsPath" -$flag; else sh $unixPath -$flag; fi';
  }

  String get name => switch (this) {
    ShellFunc.status => 'status',
    ShellFunc.process => 'process',
    ShellFunc.shutdown => 'ShutDown',
    ShellFunc.reboot => 'Reboot',
    ShellFunc.suspend => 'Suspend',
  };

  String get _windowsCmd => switch (this) {
    ShellFunc.status => _windowsStatusCmds,
    ShellFunc.process => 'Get-Process | Select-Object ProcessName, Id, CPU, WorkingSet | ConvertTo-Json',
    ShellFunc.shutdown => 'Stop-Computer -Force',
    ShellFunc.reboot => 'Restart-Computer -Force',
    ShellFunc.suspend => 'Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Application]::SetSuspendState(\'Suspend\', \$false, \$false)',
  };

  String get _unixCmd => switch (this) {
    ShellFunc.status =>
      '''
if [ "\$macSign" = "" ] && [ "\$bsdSign" = "" ]; then
\t$_linuxStatusCmds
else
\t$_bsdStatusCmds
fi''',
    ShellFunc.process =>
      '''
if [ "\$macSign" = "" ] && [ "\$bsdSign" = "" ]; then
\tif [ "\$isBusybox" != "" ]; then
\t\tps w
\telse
\t\tps -aux
\tfi
else
\tps -ax
fi
''',
    ShellFunc.shutdown =>
      '''
if [ "\$userId" = "0" ]; then
\tshutdown -h now
else
\tsudo -S shutdown -h now
fi''',
    ShellFunc.reboot =>
      '''
if [ "\$userId" = "0" ]; then
\treboot
else
\tsudo -S reboot
fi''',
    ShellFunc.suspend =>
      '''
if [ "\$userId" = "0" ]; then
\tsystemctl suspend
else
\tsudo -S systemctl suspend
fi''',
  };

  /// Generate Windows PowerShell script
  static String windowsScript(Map<String, String>? customCmds) {
    final sb = StringBuffer();
    sb.write('''
# PowerShell script for ServerBox app v1.0.${BuildData.build}
# DO NOT delete this file while app is running

\$ErrorActionPreference = "SilentlyContinue"

''');
    
    // Write each func
    for (final func in values) {
      final customCmdsStr = () {
        if (func == ShellFunc.status && customCmds != null && customCmds.isNotEmpty) {
          return '\n${customCmds.values.map((cmd) => '\t$cmd').join('\n')}';
        }
        return '';
      }();
      
      sb.write('''
function ${func.name} {
    ${func._windowsCmd.split('\n').map((e) => e.isEmpty ? '' : '    $e').join('\n')}$customCmdsStr
}

''');
    }

    // Write switch case
    sb.write('''
switch (\$args[0]) {
''');
    for (final func in values) {
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

  /// Generate Unix shell script  
  static String unixScript(Map<String, String>? customCmds) {
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
    // Write each func
    for (final func in values) {
      final customCmdsStr = () {
        if (func == ShellFunc.status && customCmds != null && customCmds.isNotEmpty) {
          return '$cmdDivider\n\t${customCmds.values.join(cmdDivider)}';
        }
        return '';
      }();
      sb.write('''
${func.name}() {
${func._unixCmd.split('\n').map((e) => '\t$e').join('\n')}
$customCmdsStr
}

''');
    }

    // Write switch case
    sb.write('case \$1 in\n');
    for (final func in values) {
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

  /// Generate script based on system type
  static String allScript(Map<String, String>? customCmds, {SystemType? systemType}) {
    if (systemType == SystemType.windows) {
      return windowsScript(customCmds);
    } else {
      return unixScript(customCmds);
    }
  }
}

extension EnumX on Enum {
  /// Find out the required segment from [segments]
  String find(List<String> segments) {
    return segments[index];
  }
}

enum StatusCmdType {
  echo._('echo ${SystemType.linuxSign}'),
  time._('date +%s'),
  net._('cat /proc/net/dev'),
  sys._('cat /etc/*-release | grep ^PRETTY_NAME'),
  cpu._('cat /proc/stat | grep cpu'),
  uptime._('uptime'),
  conn._('cat /proc/net/snmp'),
  disk._('lsblk --bytes --json --output FSTYPE,PATH,NAME,KNAME,MOUNTPOINT,FSSIZE,FSUSED,FSAVAIL,FSUSE%,UUID'),
  mem._("cat /proc/meminfo | grep -E 'Mem|Swap'"),
  tempType._('cat /sys/class/thermal/thermal_zone*/type'),
  tempVal._('cat /sys/class/thermal/thermal_zone*/temp'),
  host._('cat /etc/hostname'),
  diskio._('cat /proc/diskstats'),
  battery._('for f in /sys/class/power_supply/*/uevent; do cat "\$f"; echo; done'),
  nvidia._('nvidia-smi -q -x'),
  amd._('if command -v amd-smi >/dev/null 2>&1; then amd-smi list --json && amd-smi metric --json; elif command -v rocm-smi >/dev/null 2>&1; then rocm-smi --json || rocm-smi --showunique --showuse --showtemp --showfan --showclocks --showmemuse --showpower; elif command -v radeontop >/dev/null 2>&1; then timeout 2s radeontop -d - -l 1 | tail -n +2; else echo "No AMD GPU monitoring tools found"; fi'),
  sensors._('sensors'),
  diskSmart._('for d in \$(lsblk -dn -o KNAME); do smartctl -a -j /dev/\$d; echo; done'),
  cpuBrand._('cat /proc/cpuinfo | grep "model name"');

  final String cmd;

  const StatusCmdType._(this.cmd);
}

enum BSDStatusCmdType {
  echo._('echo ${SystemType.bsdSign}'),
  time._('date +%s'),
  net._('netstat -ibn'),
  sys._('uname -or'),
  cpu._('top -l 1 | grep "CPU usage"'),
  uptime._('uptime'),
  // Keep df -k for BSD systems as lsblk is not available on macOS/BSD
  disk._('df -k'),
  mem._('top -l 1 | grep PhysMem'),
  //temp,
  host._('hostname'),
  cpuBrand._('sysctl -n machdep.cpu.brand_string');

  final String cmd;

  const BSDStatusCmdType._(this.cmd);
}

extension StatusCmdTypeX on StatusCmdType {
  String get i18n => switch (this) {
    StatusCmdType.sys => l10n.system,
    StatusCmdType.host => l10n.host,
    StatusCmdType.uptime => l10n.uptime,
    StatusCmdType.battery => l10n.battery,
    StatusCmdType.sensors => l10n.sensors,
    StatusCmdType.disk => l10n.disk,
    final val => val.name,
  };
}

enum WindowsStatusCmdType {
  echo._('echo ${SystemType.windowsSign}'),
  time._('powershell -c "[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()"'),
  net._('powershell -c "Get-NetAdapter | Where-Object {\$_.Status -eq \'Up\'} | ForEach-Object { Get-Counter -Counter \\"\\\\Network Interface(\$(\$_.Name))\\\\Bytes Received/sec\\", \\"\\\\Network Interface(\$(\$_.Name))\\\\Bytes Sent/sec\\" -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue } | ConvertTo-Json"'),
  sys._('powershell -c "(Get-ComputerInfo).OsName"'),
  cpu._('powershell -c "Get-WmiObject -Class Win32_Processor | Select-Object Name, LoadPercentage | ConvertTo-Json"'),
  uptime._('powershell -c "(Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime"'),
  conn._('powershell -c "netstat -an | findstr ESTABLISHED | measure-object -line | select-object -expandproperty count"'),
  disk._('powershell -c "Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, Size, FreeSpace, FileSystem | ConvertTo-Json"'),
  mem._('powershell -c "Get-WmiObject -Class Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory | ConvertTo-Json"'),
  tempType._('powershell -c "Get-WmiObject -Namespace root/OpenHardwareMonitor -Class Sensor | Where-Object {\$_.SensorType -eq \'Temperature\'} | Select-Object Name | ConvertTo-Json"'),
  tempVal._('powershell -c "Get-WmiObject -Namespace root/OpenHardwareMonitor -Class Sensor | Where-Object {\$_.SensorType -eq \'Temperature\'} | Select-Object Value | ConvertTo-Json"'),
  host._('powershell -c "\$env:COMPUTERNAME"'),
  diskio._('powershell -c "Get-Counter -Counter \\"\\\\PhysicalDisk(*)\\\\Disk Reads/sec\\", \\"\\\\PhysicalDisk(*)\\\\Disk Writes/sec\\" -SampleInterval 1 -MaxSamples 1 | ConvertTo-Json"'),
  battery._('powershell -c "Get-WmiObject -Class Win32_Battery | Select-Object EstimatedChargeRemaining, BatteryStatus | ConvertTo-Json"'),
  nvidia._('powershell -c "if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) { nvidia-smi -q -x } else { echo \'NVIDIA driver not found\' }"'),
  amd._('powershell -c "if (Get-Command amd-smi -ErrorAction SilentlyContinue) { amd-smi list --json } else { echo \'AMD driver not found\' }"'),
  sensors._('powershell -c "Get-WmiObject -Namespace root/OpenHardwareMonitor -Class Sensor | ConvertTo-Json"'),
  diskSmart._('powershell -c "Get-PhysicalDisk | Get-StorageReliabilityCounter | ConvertTo-Json"'),
  cpuBrand._('powershell -c "(Get-WmiObject -Class Win32_Processor).Name"');

  final String cmd;

  const WindowsStatusCmdType._(this.cmd);
}
