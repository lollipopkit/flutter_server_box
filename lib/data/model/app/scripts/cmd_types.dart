import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/server/system.dart';

/// Enum representing different command types for various systems
enum CmdTypeSys {
  linux('Linux'),
  bsd('BSD'),
  windows('Windows');

  final String sign;
  const CmdTypeSys(this.sign);

  IconData get icon {
    return switch (this) {
      CmdTypeSys.linux => MingCute.linux_line,
      CmdTypeSys.bsd => LineAwesome.freebsd,
      CmdTypeSys.windows => MingCute.windows_line,
    };
  }
}

/// Base class for all command type enums
sealed class ShellCmdType implements Enum {
  String get cmd;

  /// Get command-specific separator
  String get separator;

  /// Get command-specific divider (separator with echo and formatting)
  String get divider;

  /// Get corresponding system type
  CmdTypeSys get sysType;

  static Set<ShellCmdType> get all {
    return {...StatusCmdType.values, ...BSDStatusCmdType.values, ...WindowsStatusCmdType.values};
  }
}

extension ShellCmdTypeX on ShellCmdType {
  /// Display name of the command type
  String get displayName => '${sysType.sign}.$name';
}

/// Linux/Unix status commands
enum StatusCmdType implements ShellCmdType {
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

  /// Get battery information from Linux power supply subsystem
  ///
  /// Reads battery data from sysfs power supply interface:
  /// - Iterates through all power supply devices in /sys/class/power_supply/
  /// - Each device has a uevent file with key-value pairs of power supply properties
  /// - Includes battery level, status, technology type, and other attributes
  /// - Works with laptops, UPS devices, and other power supplies
  /// - Adds echo after each file to separate multiple power supplies
  /// - Returns empty if no power supplies are detected (e.g., desktop systems)
  battery('for f in /sys/class/power_supply/*/uevent; do cat "\$f"; echo; done'),

  /// Get NVIDIA GPU information using nvidia-smi in XML format
  /// Requires NVIDIA drivers and nvidia-smi utility to be installed
  nvidia('nvidia-smi -q -x'),

  /// Get AMD GPU information using multiple fallback methods
  ///
  /// This command tries three different AMD monitoring tools in order of preference:
  /// 1. amd-smi: Modern AMD System Management Interface (ROCm 5.0+)
  ///    - Uses 'amd-smi list --json' to get GPU list
  ///    - Uses 'amd-smi metric --json' to get performance metrics
  /// 2. rocm-smi: ROCm System Management Interface (older versions)
  ///    - First tries '--json' output format if supported
  ///    - Falls back to human-readable format with comprehensive metrics
  /// 3. radeontop: Real-time GPU usage monitor for older AMD cards
  ///    - Uses 2-second timeout to avoid hanging
  ///    - Skips header line with 'tail -n +2'
  ///    - Outputs single line of usage data
  ///
  /// If none of these tools are available, outputs error message
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

  /// Get SMART disk health information for all storage devices
  ///
  /// Uses a combination of lsblk and smartctl to collect disk health data:
  /// - lsblk -dn -o KNAME lists all block devices (kernel names only, no dependencies)
  /// - For each device, runs smartctl with -a (all info) and -j (JSON output)
  /// - Targets raw device nodes in /dev/ (e.g., /dev/sda, /dev/nvme0n1)
  /// - Adds echo after each device to separate output blocks
  /// - May require elevated privileges for some drives
  /// - smartctl must be installed (part of smartmontools package)
  diskSmart('for d in \$(lsblk -dn -o KNAME); do smartctl -a -j /dev/\$d; echo; done'),
  cpuBrand('cat /proc/cpuinfo | grep "model name"');

  @override
  final String cmd;

  const StatusCmdType(this.cmd);

  @override
  String get separator => ScriptConstants.getCmdSeparator(name);

  @override
  String get divider => ScriptConstants.getCmdDivider(name);

  @override
  CmdTypeSys get sysType => CmdTypeSys.linux;
}

/// BSD/macOS status commands
enum BSDStatusCmdType implements ShellCmdType {
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

  @override
  String get separator => ScriptConstants.getCmdSeparator(name);

  @override
  String get divider => ScriptConstants.getCmdDivider(name);

  @override
  CmdTypeSys get sysType => CmdTypeSys.bsd;
}

/// Windows PowerShell status commands
enum WindowsStatusCmdType implements ShellCmdType {
  echo('echo ${SystemType.windowsSign}'),
  time('[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()'),

  /// Get network interface statistics using Windows Performance Counters
  ///
  /// Uses Get-Counter to collect network I/O metrics from all network interfaces:
  /// - Collects bytes received and sent per second for all network interfaces
  /// - Takes 2 samples with 1 second interval to calculate rates
  /// - Outputs results in JSON format for easy parsing
  /// - Counter paths use double backslashes to escape PowerShell string literals
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

  /// Get system temperature using Windows Management Instrumentation (WMI)
  ///
  /// Queries the MSAcpi_ThermalZoneTemperature class from the WMI root/wmi namespace:
  /// - Uses Get-CimInstance to access ACPI thermal zone data
  /// - ErrorAction SilentlyContinue prevents errors on systems without thermal sensors
  /// - Converts temperature from 10ths of Kelvin to Celsius: (temp - 2732) / 10
  /// - Uses calculated property to perform the temperature conversion
  /// - Returns JSON with InstanceName and converted Temperature values
  /// - May return empty result on systems without ACPI thermal sensor support
  temp(
    'Get-CimInstance -ClassName MSAcpi_ThermalZoneTemperature '
    '-Namespace root/wmi -ErrorAction SilentlyContinue | '
    'Select-Object InstanceName, @{Name=\'Temperature\';'
    'Expression={[math]::Round((\$_.CurrentTemperature - 2732) / 10, 1)}} | '
    'ConvertTo-Json',
  ),
  host(r'Write-Output $env:COMPUTERNAME'),

  /// Get disk I/O statistics using Windows Performance Counters
  ///
  /// Uses Get-Counter to collect disk I/O metrics from all physical disks:
  /// - Monitors read and write bytes per second for all physical disks
  /// - Takes 2 samples with 1 second interval to calculate I/O rates
  /// - Physical disk counters provide hardware-level I/O statistics
  /// - Outputs results in JSON format for parsing
  /// - Counter names use wildcard (*) to capture all disk instances
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

  /// Get NVIDIA GPU information on Windows
  ///
  /// Checks if nvidia-smi is available before attempting to use it:
  /// - Uses Get-Command to test if nvidia-smi.exe exists in PATH
  /// - ErrorAction SilentlyContinue prevents PowerShell errors if not found
  /// - If available, runs nvidia-smi with -q (query) and -x (XML output) flags
  /// - If not available, outputs standard error message for consistent handling
  nvidia(
    'if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) { '
    'nvidia-smi -q -x } else { echo "NVIDIA driver not found" }',
  ),

  /// Get AMD GPU information on Windows
  ///
  /// Checks for AMD monitoring tools using similar pattern to Linux version:
  /// - Uses Get-Command to test if amd-smi.exe exists in PATH
  /// - ErrorAction SilentlyContinue prevents PowerShell errors if not found
  /// - If available, runs amd-smi list command with JSON output
  /// - If not available, outputs standard error message for consistent handling
  /// - Windows version is simpler than Linux due to fewer AMD tool variations
  amd(
    'if (Get-Command amd-smi -ErrorAction SilentlyContinue) { '
    'amd-smi list --json } else { echo "AMD driver not found" }',
  ),
  sensors(
    'Get-CimInstance -ClassName Win32_TemperatureProbe '
    '-ErrorAction SilentlyContinue | '
    'Select-Object Name, CurrentReading | ConvertTo-Json',
  ),

  /// Get SMART disk health information on Windows using Storage cmdlets
  ///
  /// Uses Windows PowerShell storage management cmdlets:
  /// - Get-PhysicalDisk retrieves all physical storage devices
  /// - Get-StorageReliabilityCounter gets SMART health data via pipeline
  /// - Selects key health metrics: DeviceId, Temperature, TemperatureMax, Wear, PowerOnHours
  /// - Outputs results in JSON format for consistent parsing
  /// - Works with NVMe, SATA, and other storage interfaces supported by Windows
  /// - May require elevated privileges on some systems
  diskSmart(
    'Get-PhysicalDisk | Get-StorageReliabilityCounter | '
    'Select-Object DeviceId, Temperature, TemperatureMax, Wear, PowerOnHours | '
    'ConvertTo-Json',
  ),
  cpuBrand('(Get-WmiObject -Class Win32_Processor).Name');

  @override
  final String cmd;

  const WindowsStatusCmdType(this.cmd);

  @override
  String get separator => ScriptConstants.getCmdSeparator(name);

  @override
  String get divider => ScriptConstants.getCmdDivider(name);

  @override
  CmdTypeSys get sysType => CmdTypeSys.windows;
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

/// Extension for CommandType to find content in parsed map
extension CommandTypeX on ShellCmdType {
  /// Find the command output from the parsed script output map
  String findInMap(Map<String, String> parsedOutput) {
    return parsedOutput[name] ?? '';
  }
}
