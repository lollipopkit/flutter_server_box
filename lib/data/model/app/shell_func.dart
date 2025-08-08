import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/script_builders.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/server.dart';
import 'package:server_box/data/res/build_data.dart';

enum ShellFunc {
  status('SbStatus'),
  //docker,
  process('SbProcess'),
  shutdown('SbShutdown'),
  reboot('SbReboot'),
  suspend('SbSuspend');

  final String name;

  const ShellFunc(this.name);

  static const seperator = 'SrvBoxSep';

  /// The suffix `\t` is for formatting
  static const cmdDivider = '\necho $seperator\n\t';

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
  static String getScriptDir(String id, {SystemType? systemType}) {
    final customScriptDir = ServerProvider.pick(id: id)?.value.spi.custom?.scriptDir;
    if (customScriptDir != null) return customScriptDir;

    final defaultTmpDir = systemType == SystemType.windows ? scriptDirTmpWindows : scriptDirTmp;
    _scriptDirMap[id] ??= defaultTmpDir;
    return _scriptDirMap[id]!;
  }

  static void switchScriptDir(String id, {SystemType? systemType}) => switch (_scriptDirMap[id]) {
    scriptDirTmp => _scriptDirMap[id] = scriptDirHome,
    scriptDirTmpWindows => _scriptDirMap[id] = scriptDirHomeWindows,
    scriptDirHome => _scriptDirMap[id] = scriptDirTmp,
    scriptDirHomeWindows => _scriptDirMap[id] = scriptDirTmpWindows,
    _ => _scriptDirMap[id] = systemType == SystemType.windows ? scriptDirHomeWindows : scriptDirHome,
  };

  static String getScriptPath(String id, {SystemType? systemType}) {
    final dir = getScriptDir(id, systemType: systemType);
    final fileName = systemType == SystemType.windows ? scriptFileWindows : scriptFile;
    final separator = systemType == SystemType.windows ? '\\' : '/';
    return '$dir$separator$fileName';
  }

  static String getInstallShellCmd(String id, {SystemType? systemType}) {
    final scriptDir = getScriptDir(id, systemType: systemType);
    final isWindows = systemType == SystemType.windows;
    final builder = ScriptBuilderFactory.getBuilder(isWindows);
    final separator = isWindows ? '\\' : '/';
    final scriptPath = '$scriptDir$separator${builder.scriptFileName}';

    return builder.getInstallCommand(scriptDir, scriptPath);
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
    final isWindows = systemType == SystemType.windows;
    final builder = ScriptBuilderFactory.getBuilder(isWindows);
    
    return builder.getExecCommand(scriptPath, this);
  }



  /// Generate script based on system type
  static String allScript(Map<String, String>? customCmds, {SystemType? systemType}) {
    final isWindows = systemType == SystemType.windows;
    final builder = ScriptBuilderFactory.getBuilder(isWindows);
    
    return builder.buildScript(customCmds);
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
  disk._(
    'lsblk --bytes --json --output '
    'FSTYPE,PATH,NAME,KNAME,MOUNTPOINT,FSSIZE,FSUSED,FSAVAIL,FSUSE%,UUID',
  ),
  mem._("cat /proc/meminfo | grep -E 'Mem|Swap'"),
  tempType._('cat /sys/class/thermal/thermal_zone*/type'),
  tempVal._('cat /sys/class/thermal/thermal_zone*/temp'),
  host._('cat /etc/hostname'),
  diskio._('cat /proc/diskstats'),
  battery._('for f in /sys/class/power_supply/*/uevent; do cat "\$f"; echo; done'),
  nvidia._('nvidia-smi -q -x'),
  amd._(
    'if command -v amd-smi >/dev/null 2>&1; then '
    'amd-smi list --json && amd-smi metric --json; '
    'elif command -v rocm-smi >/dev/null 2>&1; then '
    'rocm-smi --json || rocm-smi --showunique --showuse --showtemp '
    '--showfan --showclocks --showmemuse --showpower; '
    'elif command -v radeontop >/dev/null 2>&1; then '
    'timeout 2s radeontop -d - -l 1 | tail -n +2; '
    'else echo "No AMD GPU monitoring tools found"; fi',
  ),
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
  time._('[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()'),
  net._(
    r'Get-Counter -Counter '
    r'"\\NetworkInterface(*)\\Bytes Received/sec", '
    r'"\\NetworkInterface(*)\\Bytes Sent/sec" '
    r'-SampleInterval 1 -MaxSamples 2 | ConvertTo-Json',
  ),
  sys._('(Get-ComputerInfo).OsName'),
  cpu._(
    'Get-WmiObject -Class Win32_Processor | '
    'Select-Object Name, LoadPercentage | ConvertTo-Json',
  ),
  uptime._('(Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime'),
  conn._('(netstat -an | findstr ESTABLISHED | Measure-Object -Line).Count'),
  disk._(
    'Get-WmiObject -Class Win32_LogicalDisk | '
    'Select-Object DeviceID, Size, FreeSpace, FileSystem | ConvertTo-Json',
  ),
  mem._(
    'Get-WmiObject -Class Win32_OperatingSystem | '
    'Select-Object TotalVisibleMemorySize, FreePhysicalMemory | ConvertTo-Json',
  ),
  temp._(
    'Get-CimInstance -ClassName MSAcpi_ThermalZoneTemperature '
    '-Namespace root/wmi -ErrorAction SilentlyContinue | '
    'Select-Object InstanceName, @{Name=\'Temperature\';'
    'Expression={[math]::Round((\$_.CurrentTemperature - 2732) / 10, 1)}} | '
    'ConvertTo-Json',
  ),
  host._(r'Write-Output $env:COMPUTERNAME'),
  diskio._(
    r'Get-Counter -Counter '
    r'"\\PhysicalDisk(*)\\Disk Read Bytes/sec", '
    r'"\\PhysicalDisk(*)\\Disk Write Bytes/sec" '
    r'-SampleInterval 1 -MaxSamples 2 | ConvertTo-Json',
  ),
  battery._(
    'Get-WmiObject -Class Win32_Battery | '
    'Select-Object EstimatedChargeRemaining, BatteryStatus | ConvertTo-Json',
  ),
  nvidia._(
    'if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) { '
    'nvidia-smi -q -x } else { echo "NVIDIA driver not found" }',
  ),
  amd._(
    'if (Get-Command amd-smi -ErrorAction SilentlyContinue) { '
    'amd-smi list --json } else { echo "AMD driver not found" }',
  ),
  sensors._(
    'Get-CimInstance -ClassName Win32_TemperatureProbe '
    '-ErrorAction SilentlyContinue | '
    'Select-Object Name, CurrentReading | ConvertTo-Json',
  ),
  diskSmart._(
    'Get-PhysicalDisk | Get-StorageReliabilityCounter | '
    'Select-Object DeviceId, Temperature, TemperatureMax, Wear, PowerOnHours | '
    'ConvertTo-Json',
  ),
  cpuBrand._('(Get-WmiObject -Class Win32_Processor).Name');

  final String cmd;

  const WindowsStatusCmdType._(this.cmd);
}

extension EnumX on Enum {
  /// Find out the required segment from [segments]
  String find(List<String> segments) {
    return segments[index];
  }
}
