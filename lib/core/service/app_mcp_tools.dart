import 'package:server_box/data/model/server/system.dart';

/// Fixed, non-interactive inspections. Only the host selector comes from MCP.
enum AppMcpInspection {
  machineStatus(
    'machine_status',
    'Read system uptime and load.',
    linux: 'uptime',
    windows:
        'powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).LastBootUpTime"',
  ),
  machineMetrics(
    'machine_metrics',
    'Read memory statistics.',
    linux: 'cat /proc/meminfo',
    windows:
        'powershell -NoProfile -Command "Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize,FreePhysicalMemory"',
  ),
  cpu(
    'cpu',
    'Read CPU counters or system load.',
    linux: 'head -n 1 /proc/stat',
    windows:
        'powershell -NoProfile -Command "Get-CimInstance Win32_Processor | Select-Object Name,LoadPercentage"',
  ),
  network(
    'network',
    'Read interface traffic counters.',
    linux: 'cat /proc/net/dev',
    windows: 'netstat -e',
  ),
  diskIo(
    'disk_io',
    'Read disk I/O counters.',
    linux: 'cat /proc/diskstats',
    windows:
        'powershell -NoProfile -Command "Get-CimInstance Win32_PerfRawData_PerfDisk_PhysicalDisk | Select-Object Name,DiskReadBytesPersec,DiskWriteBytesPersec"',
  ),
  images(
    'images',
    'List Docker image IDs, tags and sizes.',
    linux: 'docker image ls --no-trunc',
    windows: 'docker image ls --no-trunc',
  ),
  storage(
    'storage',
    'List mounted filesystems and their capacity.',
    linux: 'df -kP',
    windows:
        'powershell -NoProfile -Command "Get-PSDrive -PSProvider FileSystem | Select-Object Name,Used,Free"',
  ),
  processes(
    'processes',
    'List process IDs and executable names.',
    linux: 'sh -c \'ps -A -o pid,comm 2>/dev/null || ps -o pid,comm\'',
    windows: 'tasklist /fo csv /nh',
  ),
  services(
    'services',
    'List services reported by the system service manager.',
    linux: 'systemctl list-units --type=service --all --no-pager --no-legend',
    windows:
        'powershell -NoProfile -Command "Get-Service | Select-Object Name,Status"',
  ),
  containers(
    'containers',
    'List Docker containers, including stopped containers.',
    linux: 'docker ps -a --format "{{.ID}}\t{{.Names}}\t{{.Status}}"',
    windows: 'docker ps -a --format "{{.ID}}\t{{.Names}}\t{{.Status}}"',
  ),
  tmux('tmux', 'List tmux sessions on this host.', linux: 'tmux list-sessions');

  const AppMcpInspection(
    this.name,
    this.description, {
    required this.linux,
    this.windows,
  });
  final String name;
  final String description;
  final String linux;
  final String? windows;

  String? command(SystemType system) => switch (system) {
    SystemType.windows => windows,
    SystemType.linux => linux,
    SystemType.bsd => switch (this) {
      // Both Darwin and FreeBSD are classified as BSD by the App.
      machineMetrics =>
        'sh -c \'if command -v vm_stat >/dev/null; then vm_stat; else sysctl vm.stats.vm; fi\'',
      cpu => 'sysctl -n vm.loadavg',
      network => 'netstat -ibn',
      diskIo => 'iostat -d',
      services =>
        'sh -c \'if command -v launchctl >/dev/null; then launchctl list; else service -e; fi\'',
      _ => linux,
    },
  };
}
