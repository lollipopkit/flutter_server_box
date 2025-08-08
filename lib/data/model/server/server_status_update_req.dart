import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:intl/intl.dart';
import 'package:server_box/data/model/app/shell_func.dart';
import 'package:server_box/data/model/server/amd.dart';
import 'package:server_box/data/model/server/battery.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/disk_smart.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/nvdia.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/temp.dart';

class ServerStatusUpdateReq {
  final ServerStatus ss;
  final List<String> segments;
  final SystemType system;
  final Map<String, String> customCmds;

  const ServerStatusUpdateReq({
    required this.system,
    required this.ss,
    required this.segments,
    required this.customCmds,
  });
}

Future<ServerStatus> getStatus(ServerStatusUpdateReq req) async {
  return switch (req.system) {
    SystemType.linux => _getLinuxStatus(req),
    SystemType.bsd => _getBsdStatus(req),
    SystemType.windows => _getWindowsStatus(req),
  };
}

// Wrap each operation with a try-catch, so that if one operation fails,
// the following operations can still be executed.
Future<ServerStatus> _getLinuxStatus(ServerStatusUpdateReq req) async {
  final segments = req.segments;

  final time = int.tryParse(StatusCmdType.time.find(segments)) ??
      DateTime.now().millisecondsSinceEpoch ~/ 1000;

  try {
    final net = NetSpeed.parse(StatusCmdType.net.find(segments), time);
    req.ss.netSpeed.update(net);
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final sys = _parseSysVer(StatusCmdType.sys.find(segments));
    if (sys != null) {
      req.ss.more[StatusCmdType.sys] = sys;
    }
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final host = _parseHostName(StatusCmdType.host.find(segments));
    if (host != null) {
      req.ss.more[StatusCmdType.host] = host;
    }
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final cpus = SingleCpuCore.parse(StatusCmdType.cpu.find(segments));
    req.ss.cpu.update(cpus);
    final brand = CpuBrand.parse(StatusCmdType.cpuBrand.find(segments));
    req.ss.cpu.brand.clear();
    req.ss.cpu.brand.addAll(brand);
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.temps.parse(
      StatusCmdType.tempType.find(segments),
      StatusCmdType.tempVal.find(segments),
    );
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final tcp = Conn.parse(StatusCmdType.conn.find(segments));
    if (tcp != null) {
      req.ss.tcp = tcp;
    }
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.disk = Disk.parse(StatusCmdType.disk.find(segments));
    req.ss.diskUsage = DiskUsage.parse(req.ss.disk);
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.mem = Memory.parse(StatusCmdType.mem.find(segments));
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final uptime = _parseUpTime(StatusCmdType.uptime.find(segments));
    if (uptime != null) {
      req.ss.more[StatusCmdType.uptime] = uptime;
    }
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.swap = Swap.parse(StatusCmdType.mem.find(segments));
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final diskio = DiskIO.parse(StatusCmdType.diskio.find(segments), time);
    req.ss.diskIO.update(diskio);
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final smarts = DiskSmart.parse(StatusCmdType.diskSmart.find(segments));
    req.ss.diskSmart = smarts;
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.nvidia = NvidiaSmi.fromXml(StatusCmdType.nvidia.find(segments));
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.amd = AmdSmi.fromJson(StatusCmdType.amd.find(segments));
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final battery = StatusCmdType.battery.find(segments);

    /// Only collect li-poly batteries
    final batteries = Batteries.parse(battery, true);
    req.ss.batteries.clear();
    if (batteries.isNotEmpty) {
      req.ss.batteries.addAll(batteries);
    }
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final sensors = SensorItem.parse(StatusCmdType.sensors.find(segments));
    if (sensors.isNotEmpty) {
      req.ss.sensors.clear();
      req.ss.sensors.addAll(sensors);
    }
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    for (int idx = 0; idx < req.customCmds.length; idx++) {
      final key = req.customCmds.keys.elementAt(idx);
      final value = req.segments[idx + req.system.segmentsLen];
      req.ss.customCmds[key] = value;
    }
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  return req.ss;
}

// Same as above, wrap with try-catch
Future<ServerStatus> _getBsdStatus(ServerStatusUpdateReq req) async {
  final segments = req.segments;

  try {
    final time = int.parse(BSDStatusCmdType.time.find(segments));
    final net = NetSpeed.parseBsd(BSDStatusCmdType.net.find(segments), time);
    req.ss.netSpeed.update(net);
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.more[StatusCmdType.sys] = BSDStatusCmdType.sys.find(segments);
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.cpu = parseBsdCpu(BSDStatusCmdType.cpu.find(segments));
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.mem = parseBsdMemory(BSDStatusCmdType.mem.find(segments));
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final uptime = _parseUpTime(BSDStatusCmdType.uptime.find(segments));
    if (uptime != null) {
      req.ss.more[StatusCmdType.uptime] = uptime;
    }
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.disk = Disk.parse(BSDStatusCmdType.disk.find(segments));
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }
  return req.ss;
}

// raw:
//  19:39:15 up 61 days, 18:16,  1 user,  load average: 0.00, 0.00, 0.00
//  19:39:15 up 1 day, 2:34,  1 user,  load average: 0.00, 0.00, 0.00
//  19:39:15 up 2:34,  1 user,  load average: 0.00, 0.00, 0.00
//  19:39:15 up 34 min,  1 user,  load average: 0.00, 0.00, 0.00
String? _parseUpTime(String raw) {
  final splitedUp = raw.split('up ');
  if (splitedUp.length == 2) {
    final uptimePart = splitedUp[1];
    final splitedComma = uptimePart.split(', ');

    if (splitedComma.isEmpty) return null;

    // Handle different uptime formats
    final firstPart = splitedComma[0].trim();

    // Case 1: "61 days" or "1 day" - need to get the time part from next segment
    if (firstPart.contains('day')) {
      if (splitedComma.length >= 2) {
        final timePart = splitedComma[1].trim();
        // Check if it's in HH:MM format
        if (timePart.contains(':') &&
            !timePart.contains('user') &&
            !timePart.contains('load')) {
          return '$firstPart, $timePart';
        }
      }
      return firstPart;
    }

    // Case 2: "2:34" (hours:minutes) - already in good format
    if (firstPart.contains(':') &&
        !firstPart.contains('user') &&
        !firstPart.contains('load')) {
      return firstPart;
    }

    // Case 3: "34 min" - already in good format
    if (firstPart.contains('min')) {
      return firstPart;
    }

    // Fallback: return first part
    return firstPart;
  }
  return null;
}

String? _parseSysVer(String raw) {
  final s = raw.split('=');
  if (s.length == 2) {
    return s[1].replaceAll('"', '').replaceFirst('\n', '');
  }
  return null;
}

String? _parseHostName(String raw) {
  if (raw.isEmpty) return null;
  if (raw.contains(ShellFunc.scriptFile)) return null;
  return raw;
}

// Windows status parsing implementation
Future<ServerStatus> _getWindowsStatus(ServerStatusUpdateReq req) async {
  final segments = req.segments;
  final time = int.tryParse(WindowsStatusCmdType.time.find(segments)) ??
      DateTime.now().millisecondsSinceEpoch ~/ 1000;

  // Parse all different resource types using helper methods
  _parseWindowsNetworkData(req, segments, time);
  _parseWindowsSystemData(req, segments);
  _parseWindowsHostData(req, segments);
  _parseWindowsCpuData(req, segments);
  _parseWindowsMemoryData(req, segments);
  _parseWindowsDiskData(req, segments);
  _parseWindowsUptimeData(req, segments);
  _parseWindowsDiskIOData(req, segments, time);
  _parseWindowsConnectionData(req, segments);
  _parseWindowsBatteryData(req, segments);
  _parseWindowsTemperatureData(req, segments);
  _parseWindowsGpuData(req, segments);
  _parseWindowsCustomCommands(req);

  return req.ss;
}

/// Parse Windows network data
void _parseWindowsNetworkData(ServerStatusUpdateReq req, List<String> segments, int time) {
  try {
    final netRaw = WindowsStatusCmdType.net.find(segments);
    if (netRaw.isNotEmpty &&
        netRaw != 'null' &&
        !netRaw.contains('network_error') &&
        !netRaw.contains('error') &&
        !netRaw.contains('Exception')) {
      final netParts = _parseWindowsNetwork(netRaw, time);
      if (netParts.isNotEmpty) {
        req.ss.netSpeed.update(netParts);
      }
    }
  } catch (e, s) {
    Loggers.app.warning('Windows network parsing failed: $e', s);
  }
}

/// Parse Windows system information
void _parseWindowsSystemData(ServerStatusUpdateReq req, List<String> segments) {
  try {
    final sys = WindowsStatusCmdType.sys.find(segments);
    if (sys.isNotEmpty) {
      req.ss.more[StatusCmdType.sys] = sys;
    }
  } catch (e, s) {
    Loggers.app.warning('Windows system parsing failed: $e', s);
  }
}

/// Parse Windows host information
void _parseWindowsHostData(ServerStatusUpdateReq req, List<String> segments) {
  try {
    final host = _parseHostName(WindowsStatusCmdType.host.find(segments));
    if (host != null) {
      req.ss.more[StatusCmdType.host] = host;
    }
  } catch (e, s) {
    Loggers.app.warning('Windows host parsing failed: $e', s);
  }
}

/// Parse Windows CPU data and brand information
void _parseWindowsCpuData(ServerStatusUpdateReq req, List<String> segments) {
  try {
    // Windows CPU parsing - JSON format from PowerShell
    final cpuRaw = WindowsStatusCmdType.cpu.find(segments);
    if (cpuRaw.isNotEmpty &&
        cpuRaw != 'null' &&
        !cpuRaw.contains('error') &&
        !cpuRaw.contains('Exception')) {
      final cpus = _parseWindowsCpu(cpuRaw, req.ss);
      if (cpus.isNotEmpty) {
        req.ss.cpu.update(cpus);
      }
    }

    // Windows CPU brand parsing
    final brandRaw = WindowsStatusCmdType.cpuBrand.find(segments);
    if (brandRaw.isNotEmpty && brandRaw != 'null') {
      req.ss.cpu.brand.clear();
      req.ss.cpu.brand[brandRaw.trim()] = 1;
    }
  } catch (e, s) {
    Loggers.app.warning('Windows CPU parsing failed: $e', s);
  }
}

/// Parse Windows memory data
void _parseWindowsMemoryData(ServerStatusUpdateReq req, List<String> segments) {
  try {
    final memRaw = WindowsStatusCmdType.mem.find(segments);
    if (memRaw.isNotEmpty &&
        memRaw != 'null' &&
        !memRaw.contains('error') &&
        !memRaw.contains('Exception')) {
      final memory = _parseWindowsMemory(memRaw);
      if (memory != null) {
        req.ss.mem = memory;
      }
    }
  } catch (e, s) {
    Loggers.app.warning('Windows memory parsing failed: $e', s);
  }
}

/// Parse Windows disk data
void _parseWindowsDiskData(ServerStatusUpdateReq req, List<String> segments) {
  try {
    final diskRaw = WindowsStatusCmdType.disk.find(segments);
    if (diskRaw.isNotEmpty && diskRaw != 'null') {
      final disks = _parseWindowsDisks(diskRaw);
      req.ss.disk = disks;
      req.ss.diskUsage = DiskUsage.parse(disks);
    }
  } catch (e, s) {
    Loggers.app.warning('Windows disk parsing failed: $e', s);
  }
}

/// Parse Windows uptime data
void _parseWindowsUptimeData(ServerStatusUpdateReq req, List<String> segments) {
  try {
    final uptime = _parseWindowsUpTime(WindowsStatusCmdType.uptime.find(segments));
    if (uptime != null) {
      req.ss.more[StatusCmdType.uptime] = uptime;
    }
  } catch (e, s) {
    Loggers.app.warning('Windows uptime parsing failed: $e', s);
  }
}

/// Parse Windows disk I/O data
void _parseWindowsDiskIOData(ServerStatusUpdateReq req, List<String> segments, int time) {
  try {
    final diskIOraw = WindowsStatusCmdType.diskio.find(segments);
    if (diskIOraw.isNotEmpty && diskIOraw != 'null') {
      final diskio = _parseWindowsDiskIO(diskIOraw, time);
      req.ss.diskIO.update(diskio);
    }
  } catch (e, s) {
    Loggers.app.warning('Windows disk I/O parsing failed: $e', s);
  }
}

/// Parse Windows connection data
void _parseWindowsConnectionData(ServerStatusUpdateReq req, List<String> segments) {
  try {
    final connStr = WindowsStatusCmdType.conn.find(segments);
    final connCount = int.tryParse(connStr.trim());
    if (connCount != null) {
      req.ss.tcp = Conn(maxConn: 0, active: connCount, passive: 0, fail: 0);
    }
  } catch (e, s) {
    Loggers.app.warning('Windows connection parsing failed: $e', s);
  }
}

/// Parse Windows battery data
void _parseWindowsBatteryData(ServerStatusUpdateReq req, List<String> segments) {
  try {
    final batteryRaw = WindowsStatusCmdType.battery.find(segments);
    if (batteryRaw.isNotEmpty && batteryRaw != 'null') {
      final batteries = _parseWindowsBatteries(batteryRaw);
      req.ss.batteries.clear();
      if (batteries.isNotEmpty) {
        req.ss.batteries.addAll(batteries);
      }
    }
  } catch (e, s) {
    Loggers.app.warning('Windows battery parsing failed: $e', s);
  }
}

/// Parse Windows temperature data
void _parseWindowsTemperatureData(ServerStatusUpdateReq req, List<String> segments) {
  try {
    final tempRaw = WindowsStatusCmdType.temp.find(segments);
    if (tempRaw.isNotEmpty && tempRaw != 'null') {
      _parseWindowsTemperatures(req.ss.temps, tempRaw);
    }
  } catch (e, s) {
    Loggers.app.warning('Windows temperature parsing failed: $e', s);
  }
}

/// Parse Windows GPU data (NVIDIA/AMD)
void _parseWindowsGpuData(ServerStatusUpdateReq req, List<String> segments) {
  try {
    req.ss.nvidia = NvidiaSmi.fromXml(WindowsStatusCmdType.nvidia.find(segments));
  } catch (e, s) {
    Loggers.app.warning('Windows NVIDIA GPU parsing failed: $e', s);
  }

  try {
    req.ss.amd = AmdSmi.fromJson(WindowsStatusCmdType.amd.find(segments));
  } catch (e, s) {
    Loggers.app.warning('Windows AMD GPU parsing failed: $e', s);
  }
}

/// Parse Windows custom commands
void _parseWindowsCustomCommands(ServerStatusUpdateReq req) {
  try {
    for (int idx = 0; idx < req.customCmds.length; idx++) {
      final key = req.customCmds.keys.elementAt(idx);
      final value = req.segments[idx + req.system.segmentsLen];
      req.ss.customCmds[key] = value;
    }
  } catch (e, s) {
    Loggers.app.warning('Windows custom commands parsing failed: $e', s);
  }
}

String? _parseWindowsUpTime(String raw) {
  try {
    // Clean the input - trim whitespace and get the first non-empty line
    final cleanedInput = raw.trim().split('\n')
        .where((line) => line.trim().isNotEmpty)
        .firstOrNull;
    
    if (cleanedInput == null || cleanedInput.isEmpty) {
      Loggers.app.warning('Windows uptime parsing: empty or null input');
      return null;
    }
    
    // Try multiple date formats to handle different Windows locale/version outputs
    final formatters = [
      DateFormat('EEEE, MMMM d, yyyy h:mm:ss a', 'en_US'), // Original format
      DateFormat('EEEE, MMMM dd, yyyy h:mm:ss a', 'en_US'), // Double-digit day
      DateFormat('EEE, MMM d, yyyy h:mm:ss a', 'en_US'), // Shortened format
      DateFormat('EEE, MMM dd, yyyy h:mm:ss a', 'en_US'), // Shortened with double-digit day
      DateFormat('M/d/yyyy h:mm:ss a', 'en_US'), // Short US format
      DateFormat('MM/dd/yyyy h:mm:ss a', 'en_US'), // Short US format with zero padding
      DateFormat('d/M/yyyy h:mm:ss a', 'en_US'), // Short European format
      DateFormat('dd/MM/yyyy h:mm:ss a', 'en_US'), // Short European format with zero padding
    ];
    
    DateTime? dateTime;
    for (final formatter in formatters) {
      dateTime = formatter.tryParseLoose(cleanedInput);
      if (dateTime != null) break;
    }
    
    if (dateTime == null) {
      Loggers.app.warning('Windows uptime parsing: could not parse date format for: $cleanedInput');
      return null;
    }
    
    final now = DateTime.now();
    final uptime = now.difference(dateTime);
    
    // Validate that the uptime is reasonable (not negative, not too far in the future)
    if (uptime.isNegative || uptime.inDays > 3650) { // More than 10 years seems unreasonable
      Loggers.app.warning('Windows uptime parsing: unreasonable uptime calculated: ${uptime.inDays} days for date: $cleanedInput');
      return null;
    }

    final days = uptime.inDays;
    final hours = uptime.inHours % 24;
    final minutes = uptime.inMinutes % 60;

    if (days > 0) {
      return '$days days, $hours:${minutes.toString().padLeft(2, '0')}';
    } else {
      return '$hours:${minutes.toString().padLeft(2, '0')}';
    }
  } catch (e, s) {
    Loggers.app.warning('Windows uptime parsing failed: $e for input: $raw', s);
    return null;
  }
}

List<SingleCpuCore> _parseWindowsCpu(String raw, ServerStatus serverStatus) {
  try {
    final dynamic jsonData = json.decode(raw);
    final List<SingleCpuCore> cpus = [];

    if (jsonData is List) {
      for (int i = 0; i < jsonData.length; i++) {
        final cpu = jsonData[i];
        final loadPercentage = cpu['LoadPercentage'] ?? 0;
        final usage = loadPercentage as int;
        final idle = 100 - usage;

        // Get previous CPU data to calculate cumulative values
        final prevCpus = serverStatus.cpu.now;
        final prevCpu = i < prevCpus.length ? prevCpus[i] : null;

        // LIMITATION: Windows CPU counters approach
        // PowerShell provides LoadPercentage as instantaneous percentage, not cumulative time.
        // We simulate cumulative counters by adding current percentages to previous totals.
        // This approach has limitations:
        // 1. Not as accurate as true cumulative time counters (Linux /proc/stat)
        // 2. May drift over time with variable polling intervals
        // 3. Results depend on consistent polling frequency
        // However, this allows compatibility with existing delta-based CPU calculation logic.
        final newUser = (prevCpu?.user ?? 0) + usage;
        final newIdle = (prevCpu?.idle ?? 0) + idle;

        cpus.add(
          SingleCpuCore(
            'cpu$i',
            newUser, // cumulative user time
            0, // sys (not available)
            0, // nice (not available)
            newIdle, // cumulative idle time
            0, // iowait (not available)
            0, // irq (not available)
            0, // softirq (not available)
          ),
        );
      }
    } else if (jsonData is Map) {
      // Single CPU core
      final loadPercentage = jsonData['LoadPercentage'] ?? 0;
      final usage = loadPercentage as int;
      final idle = 100 - usage;

      // Get previous CPU data to calculate cumulative values
      final prevCpus = serverStatus.cpu.now;
      final prevCpu = prevCpus.isNotEmpty ? prevCpus[0] : null;

      // LIMITATION: See comment above for Windows CPU counter limitations
      final newUser = (prevCpu?.user ?? 0) + usage;
      final newIdle = (prevCpu?.idle ?? 0) + idle;

      cpus.add(
        SingleCpuCore(
          'cpu0',
          newUser, // cumulative user time
          0, // sys
          0, // nice
          newIdle, // cumulative idle time
          0, // iowait
          0, // irq
          0, // softirq
        ),
      );
    }

    return cpus;
  } catch (e) {
    return [];
  }
}

Memory? _parseWindowsMemory(String raw) {
  try {
    final dynamic jsonData = json.decode(raw);
    final data = jsonData is List ? jsonData.first : jsonData;

    final totalKB = data['TotalVisibleMemorySize'] as int? ?? 0;
    final freeKB = data['FreePhysicalMemory'] as int? ?? 0;

    return Memory(
      total: totalKB,
      free: freeKB,
      avail: freeKB, // Windows doesn't distinguish between free and available
    );
  } catch (e) {
    return null;
  }
}

List<Disk> _parseWindowsDisks(String raw) {
  try {
    final dynamic jsonData = json.decode(raw);
    final List<Disk> disks = [];

    final diskList = jsonData is List ? jsonData : [jsonData];

    for (final diskData in diskList) {
      final deviceId = diskData['DeviceID']?.toString() ?? '';
      final size =
          BigInt.tryParse(diskData['Size']?.toString() ?? '0') ?? BigInt.zero;
      final freeSpace =
          BigInt.tryParse(diskData['FreeSpace']?.toString() ?? '0') ??
          BigInt.zero;
      final fileSystem = diskData['FileSystem']?.toString();

      if (deviceId.isEmpty || size == BigInt.zero) continue;

      final sizeKB = size ~/ BigInt.from(1024);
      final freeKB = freeSpace ~/ BigInt.from(1024);
      final usedKB = sizeKB - freeKB;
      final usedPercent = sizeKB > BigInt.zero
          ? ((usedKB * BigInt.from(100)) ~/ sizeKB).toInt()
          : 0;

      disks.add(
        Disk(
          path: deviceId,
          fsTyp: fileSystem,
          mount: deviceId,
          usedPercent: usedPercent,
          used: usedKB,
          size: sizeKB,
          avail: freeKB,
        ),
      );
    }

    return disks;
  } catch (e) {
    return [];
  }
}

List<Battery> _parseWindowsBatteries(String raw) {
  try {
    final dynamic jsonData = json.decode(raw);
    final List<Battery> batteries = [];

    final batteryList = jsonData is List ? jsonData : [jsonData];

    for (final batteryData in batteryList) {
      final chargeRemaining =
          batteryData['EstimatedChargeRemaining'] as int? ?? 0;
      final batteryStatus = batteryData['BatteryStatus'] as int? ?? 0;

      // Windows battery status: 1=Other, 2=Unknown, 3=Full, 4=Low, 
      // 5=Critical, 6=Charging, 7=ChargingAndLow, 8=ChargingAndCritical, 
      // 9=Undefined, 10=PartiallyCharged
      final isCharging = batteryStatus == 6 || 
          batteryStatus == 7 || 
          batteryStatus == 8;

      batteries.add(
        Battery(
          name: 'Battery',
          percent: chargeRemaining,
          status: isCharging
              ? BatteryStatus.charging
              : BatteryStatus.discharging,
        ),
      );
    }

    return batteries;
  } catch (e) {
    return [];
  }
}

List<NetSpeedPart> _parseWindowsNetwork(String raw, int currentTime) {
  try {
    final dynamic jsonData = json.decode(raw);
    final List<NetSpeedPart> netParts = [];

    // PowerShell Get-Counter returns a structure with CounterSamples
    if (jsonData is Map && jsonData.containsKey('CounterSamples')) {
      final samples = jsonData['CounterSamples'] as List?;
      if (samples != null && samples.length >= 2) {
        // We need 2 samples to calculate speed (interval between them)
        final Map<String, double> interfaceRx = {};
        final Map<String, double> interfaceTx = {};

        for (final sample in samples) {
          final path = sample['Path']?.toString() ?? '';
          final cookedValue = sample['CookedValue'] as num? ?? 0;

          if (path.contains('Bytes Received/sec')) {
            final interfaceName = _extractInterfaceName(path);
            if (interfaceName.isNotEmpty) {
              interfaceRx[interfaceName] = cookedValue.toDouble();
            }
          } else if (path.contains('Bytes Sent/sec')) {
            final interfaceName = _extractInterfaceName(path);
            if (interfaceName.isNotEmpty) {
              interfaceTx[interfaceName] = cookedValue.toDouble();
            }
          }
        }

        // Create NetSpeedPart for each interface
        for (final interfaceName in interfaceRx.keys) {
          final rx = interfaceRx[interfaceName] ?? 0;
          final tx = interfaceTx[interfaceName] ?? 0;

          netParts.add(
            NetSpeedPart(
              interfaceName,
              BigInt.from(rx.toInt()),
              BigInt.from(tx.toInt()),
              currentTime,
            ),
          );
        }
      }
    }

    return netParts;
  } catch (e) {
    return [];
  }
}

String _extractInterfaceName(String path) {
  // Extract interface name from path like 
  // "\\Computer\\NetworkInterface(Interface Name)\\..."
  final match = RegExp(r'\\NetworkInterface\(([^)]+)\)\\').firstMatch(path);
  return match?.group(1) ?? '';
}

List<DiskIOPiece> _parseWindowsDiskIO(String raw, int currentTime) {
  try {
    final dynamic jsonData = json.decode(raw);
    final List<DiskIOPiece> diskParts = [];

    // PowerShell Get-Counter returns a structure with CounterSamples
    if (jsonData is Map && jsonData.containsKey('CounterSamples')) {
      final samples = jsonData['CounterSamples'] as List?;
      if (samples != null) {
        final Map<String, double> diskReads = {};
        final Map<String, double> diskWrites = {};

        for (final sample in samples) {
          final path = sample['Path']?.toString() ?? '';
          final cookedValue = sample['CookedValue'] as num? ?? 0;

          if (path.contains('Disk Read Bytes/sec')) {
            final diskName = _extractDiskName(path);
            if (diskName.isNotEmpty) {
              diskReads[diskName] = cookedValue.toDouble();
            }
          } else if (path.contains('Disk Write Bytes/sec')) {
            final diskName = _extractDiskName(path);
            if (diskName.isNotEmpty) {
              diskWrites[diskName] = cookedValue.toDouble();
            }
          }
        }

        // Create DiskIOPiece for each disk - convert bytes to sectors 
        // (assuming 512 bytes per sector)
        for (final diskName in diskReads.keys) {
          final readBytes = diskReads[diskName] ?? 0;
          final writeBytes = diskWrites[diskName] ?? 0;
          final sectorsRead = (readBytes / 512).round();
          final sectorsWrite = (writeBytes / 512).round();

          diskParts.add(
            DiskIOPiece(
              dev: diskName,
              sectorsRead: sectorsRead,
              sectorsWrite: sectorsWrite,
              time: currentTime,
            ),
          );
        }
      }
    }

    return diskParts;
  } catch (e) {
    return [];
  }
}

String _extractDiskName(String path) {
  // Extract disk name from path like 
  // "\\Computer\\PhysicalDisk(Disk Name)\\..."
  final match = RegExp(r'\\PhysicalDisk\(([^)]+)\)\\').firstMatch(path);
  return match?.group(1) ?? '';
}

void _parseWindowsTemperatures(Temperatures temps, String raw) {
  try {
    // Handle error output
    if (raw.contains('Error') ||
        raw.contains('Exception') ||
        raw.contains('The term')) {
      return;
    }

    final dynamic jsonData = json.decode(raw);
    final tempList = jsonData is List ? jsonData : [jsonData];

    // Create fake type and value strings that the existing parse method can handle
    final typeLines = <String>[];
    final valueLines = <String>[];

    for (int i = 0; i < tempList.length; i++) {
      final item = tempList[i];
      final typeName = item['InstanceName']?.toString() ?? 'Unknown';
      final temperature = item['Temperature'] as num?;

      if (temperature != null) {
        // Convert to the format expected by the existing parse method
        typeLines.add('/sys/class/thermal/thermal_zone$i/$typeName');
        // Convert to millicelsius (multiply by 1000) 
        // as expected by Linux parsing
        valueLines.add((temperature * 1000).round().toString());
      }
    }

    if (typeLines.isNotEmpty && valueLines.isNotEmpty) {
      temps.parse(typeLines.join('\n'), valueLines.join('\n'));
    }
  } catch (e) {
    // If JSON parsing fails, ignore temperature data
  }
}
