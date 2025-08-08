import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/system.dart';

/// Base class for all command type enums
abstract class CommandType {
  String get cmd;
}

/// Linux/Unix status commands
enum StatusCmdType implements CommandType {
  echo('echo ${SystemType.linuxSign}'),
  time('date +%s'),
  net('cat /proc/net/dev'),
  sys('cat /etc/*-release | grep ^PRETTY_NAME'),
  cpu('cat /proc/stat | grep cpu'),
  uptime('uptime'),
  conn('cat /proc/net/snmp'),
  disk(
    'lsblk --bytes --json --output '
    'FSTYPE,PATH,NAME,KNAME,MOUNTPOINT,FSSIZE,FSUSED,FSAVAIL,FSUSE%,UUID',
  ),
  mem("cat /proc/meminfo | grep -E 'Mem|Swap'"),
  tempType('cat /sys/class/thermal/thermal_zone*/type'),
  tempVal('cat /sys/class/thermal/thermal_zone*/temp'),
  host('cat /etc/hostname'),
  diskio('cat /proc/diskstats'),
  battery('for f in /sys/class/power_supply/*/uevent; do cat "\$f"; echo; done'),
  nvidia('nvidia-smi -q -x'),
  amd(
    'if command -v amd-smi >/dev/null 2>&1; then '
    'amd-smi list --json && amd-smi metric --json; '
    'elif command -v rocm-smi >/dev/null 2>&1; then '
    'rocm-smi --json || rocm-smi --showunique --showuse --showtemp '
    '--showfan --showclocks --showmemuse --showpower; '
    'elif command -v radeontop >/dev/null 2>&1; then '
    'timeout 2s radeontop -d - -l 1 | tail -n +2; '
    'else echo "No AMD GPU monitoring tools found"; fi',
  ),
  sensors('sensors'),
  diskSmart('for d in \$(lsblk -dn -o KNAME); do smartctl -a -j /dev/\$d; echo; done'),
  cpuBrand('cat /proc/cpuinfo | grep "model name"');

  @override
  final String cmd;

  const StatusCmdType(this.cmd);
}

/// BSD/macOS status commands
enum BSDStatusCmdType implements CommandType {
  echo('echo ${SystemType.bsdSign}'),
  time('date +%s'),
  net('netstat -ibn'),
  sys('uname -or'),
  cpu('top -l 1 | grep "CPU usage"'),
  uptime('uptime'),
  disk('df -k'), // Keep df -k for BSD systems as lsblk is not available on macOS/BSD
  mem('top -l 1 | grep PhysMem'),
  host('hostname'),
  cpuBrand('sysctl -n machdep.cpu.brand_string');

  @override
  final String cmd;

  const BSDStatusCmdType(this.cmd);
}

/// Windows PowerShell status commands
enum WindowsStatusCmdType implements CommandType {
  echo('echo ${SystemType.windowsSign}'),
  time('[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()'),
  net(
    r'Get-Counter -Counter '
    r'"\\NetworkInterface(*)\\Bytes Received/sec", '
    r'"\\NetworkInterface(*)\\Bytes Sent/sec" '
    r'-SampleInterval 1 -MaxSamples 2 | ConvertTo-Json',
  ),
  sys('(Get-ComputerInfo).OsName'),
  cpu(
    'Get-WmiObject -Class Win32_Processor | '
    'Select-Object Name, LoadPercentage | ConvertTo-Json',
  ),
  uptime('(Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime'),
  conn('(netstat -an | findstr ESTABLISHED | Measure-Object -Line).Count'),
  disk(
    'Get-WmiObject -Class Win32_LogicalDisk | '
    'Select-Object DeviceID, Size, FreeSpace, FileSystem | ConvertTo-Json',
  ),
  mem(
    'Get-WmiObject -Class Win32_OperatingSystem | '
    'Select-Object TotalVisibleMemorySize, FreePhysicalMemory | ConvertTo-Json',
  ),
  temp(
    'Get-CimInstance -ClassName MSAcpi_ThermalZoneTemperature '
    '-Namespace root/wmi -ErrorAction SilentlyContinue | '
    'Select-Object InstanceName, @{Name=\'Temperature\';'
    'Expression={[math]::Round((\$_.CurrentTemperature - 2732) / 10, 1)}} | '
    'ConvertTo-Json',
  ),
  host(r'Write-Output $env:COMPUTERNAME'),
  diskio(
    r'Get-Counter -Counter '
    r'"\\PhysicalDisk(*)\\Disk Read Bytes/sec", '
    r'"\\PhysicalDisk(*)\\Disk Write Bytes/sec" '
    r'-SampleInterval 1 -MaxSamples 2 | ConvertTo-Json',
  ),
  battery(
    'Get-WmiObject -Class Win32_Battery | '
    'Select-Object EstimatedChargeRemaining, BatteryStatus | ConvertTo-Json',
  ),
  nvidia(
    'if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) { '
    'nvidia-smi -q -x } else { echo "NVIDIA driver not found" }',
  ),
  amd(
    'if (Get-Command amd-smi -ErrorAction SilentlyContinue) { '
    'amd-smi list --json } else { echo "AMD driver not found" }',
  ),
  sensors(
    'Get-CimInstance -ClassName Win32_TemperatureProbe '
    '-ErrorAction SilentlyContinue | '
    'Select-Object Name, CurrentReading | ConvertTo-Json',
  ),
  diskSmart(
    'Get-PhysicalDisk | Get-StorageReliabilityCounter | '
    'Select-Object DeviceId, Temperature, TemperatureMax, Wear, PowerOnHours | '
    'ConvertTo-Json',
  ),
  cpuBrand('(Get-WmiObject -Class Win32_Processor).Name');

  @override
  final String cmd;

  const WindowsStatusCmdType(this.cmd);
}

/// Extensions for StatusCmdType
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

/// Generic extension for Enum types
extension EnumX on Enum {
  /// Find out the required segment from [segments]
  String find(List<String> segments) {
    return segments[index];
  }
}