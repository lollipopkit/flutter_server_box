import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
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
import 'package:server_box/data/model/server/windows_parser.dart';

class ServerStatusUpdateReq {
  final ServerStatus ss;
  final Map<String, String> parsedOutput;
  final SystemType system;
  final Map<String, String> customCmds;

  const ServerStatusUpdateReq({
    required this.system,
    required this.ss,
    required this.parsedOutput,
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
  final parsedOutput = req.parsedOutput;

  final time =
      int.tryParse(StatusCmdType.time.findInMap(parsedOutput)) ??
      DateTime.now().millisecondsSinceEpoch ~/ 1000;

  try {
    final net = NetSpeed.parse(StatusCmdType.net.findInMap(parsedOutput), time);
    req.ss.netSpeed.update(net);
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final sys = _parseSysVer(StatusCmdType.sys.findInMap(parsedOutput));
    if (sys != null) {
      req.ss.more[StatusCmdType.sys] = sys;
    }
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final host = _parseHostName(StatusCmdType.host.findInMap(parsedOutput));
    if (host != null) {
      req.ss.more[StatusCmdType.host] = host;
    }
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final cpus = SingleCpuCore.parse(StatusCmdType.cpu.findInMap(parsedOutput));
    req.ss.cpu.update(cpus);
    final brand = CpuBrand.parse(StatusCmdType.cpuBrand.findInMap(parsedOutput));
    req.ss.cpu.brand.clear();
    req.ss.cpu.brand.addAll(brand);
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.temps.parse(
      StatusCmdType.tempType.findInMap(parsedOutput),
      StatusCmdType.tempVal.findInMap(parsedOutput),
    );
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final tcp = Conn.parse(StatusCmdType.conn.findInMap(parsedOutput));
    if (tcp != null) {
      req.ss.tcp = tcp;
    }
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.disk = Disk.parse(StatusCmdType.disk.findInMap(parsedOutput));
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.diskUsage = DiskUsage.parse(req.ss.disk);
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.mem = Memory.parse(StatusCmdType.mem.findInMap(parsedOutput));
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final uptime = _parseUpTime(StatusCmdType.uptime.findInMap(parsedOutput));
    if (uptime != null) {
      req.ss.more[StatusCmdType.uptime] = uptime;
    }
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.swap = Swap.parse(StatusCmdType.mem.findInMap(parsedOutput));
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final diskio = DiskIO.parse(StatusCmdType.diskio.findInMap(parsedOutput), time);
    req.ss.diskIO.update(diskio);
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final smarts = DiskSmart.parse(StatusCmdType.diskSmart.findInMap(parsedOutput));
    req.ss.diskSmart = smarts;
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.nvidia = NvidiaSmi.fromXml(StatusCmdType.nvidia.findInMap(parsedOutput));
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.amd = AmdSmi.fromJson(StatusCmdType.amd.findInMap(parsedOutput));
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final battery = StatusCmdType.battery.findInMap(parsedOutput);

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
    final sensors = SensorItem.parse(StatusCmdType.sensors.findInMap(parsedOutput));
    if (sensors.isNotEmpty) {
      req.ss.sensors.clear();
      req.ss.sensors.addAll(sensors);
    }
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    for (final entry in req.customCmds.entries) {
      final key = entry.key;
      final value = req.parsedOutput[key] ?? '';
      req.ss.customCmds[key] = value;
    }
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  return req.ss;
}

// Same as above, wrap with try-catch
Future<ServerStatus> _getBsdStatus(ServerStatusUpdateReq req) async {
  final parsedOutput = req.parsedOutput;

  try {
    final time = int.parse(BSDStatusCmdType.time.findInMap(parsedOutput));
    final net = NetSpeed.parseBsd(BSDStatusCmdType.net.findInMap(parsedOutput), time);
    req.ss.netSpeed.update(net);
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.more[StatusCmdType.sys] = BSDStatusCmdType.sys.findInMap(parsedOutput);
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.cpu = parseBsdCpu(BSDStatusCmdType.cpu.findInMap(parsedOutput));
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.mem = parseBsdMemory(BSDStatusCmdType.mem.findInMap(parsedOutput));
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    final uptime = _parseUpTime(BSDStatusCmdType.uptime.findInMap(parsedOutput));
    if (uptime != null) {
      req.ss.more[StatusCmdType.uptime] = uptime;
    }
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }

  try {
    req.ss.disk = Disk.parse(BSDStatusCmdType.disk.findInMap(parsedOutput));
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
        if (timePart.contains(':') && !timePart.contains('user') && !timePart.contains('load')) {
          return '$firstPart, $timePart';
        }
      }
      return firstPart;
    }

    // Case 2: "2:34" (hours:minutes) - already in good format
    if (firstPart.contains(':') && !firstPart.contains('user') && !firstPart.contains('load')) {
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
  if (raw.contains(ScriptConstants.scriptFile)) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}

// Windows status parsing implementation
Future<ServerStatus> _getWindowsStatus(ServerStatusUpdateReq req) async {
  final parsedOutput = req.parsedOutput;
  final time =
      int.tryParse(WindowsStatusCmdType.time.findInMap(parsedOutput)) ??
      DateTime.now().millisecondsSinceEpoch ~/ 1000;

  // Parse all different resource types using helper methods
  _parseWindowsNetworkData(req, parsedOutput, time);
  _parseWindowsSystemData(req, parsedOutput);
  _parseWindowsHostData(req, parsedOutput);
  _parseWindowsCpuData(req, parsedOutput);
  _parseWindowsMemoryData(req, parsedOutput);
  _parseWindowsDiskData(req, parsedOutput);
  _parseWindowsUptimeData(req, parsedOutput);
  _parseWindowsDiskIOData(req, parsedOutput, time);
  _parseWindowsConnectionData(req, parsedOutput);
  _parseWindowsBatteryData(req, parsedOutput);
  _parseWindowsTemperatureData(req, parsedOutput);
  _parseWindowsGpuData(req, parsedOutput);
  WindowsParser.parseCustomCommands(req.ss, req.parsedOutput, req.customCmds);

  return req.ss;
}

/// Parse Windows network data
void _parseWindowsNetworkData(ServerStatusUpdateReq req, Map<String, String> parsedOutput, int time) {
  try {
    final netRaw = WindowsStatusCmdType.net.findInMap(parsedOutput);
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
void _parseWindowsSystemData(ServerStatusUpdateReq req, Map<String, String> parsedOutput) {
  try {
    final sys = WindowsStatusCmdType.sys.findInMap(parsedOutput);
    if (sys.isNotEmpty) {
      req.ss.more[StatusCmdType.sys] = sys;
    }
  } catch (e, s) {
    Loggers.app.warning('Windows system parsing failed: $e', s);
  }
}

/// Parse Windows host information
void _parseWindowsHostData(ServerStatusUpdateReq req, Map<String, String> parsedOutput) {
  try {
    final host = _parseHostName(WindowsStatusCmdType.host.findInMap(parsedOutput));
    if (host != null) {
      req.ss.more[StatusCmdType.host] = host;
    }
  } catch (e, s) {
    Loggers.app.warning('Windows host parsing failed: $e', s);
  }
}

/// Parse Windows CPU data and brand information
void _parseWindowsCpuData(ServerStatusUpdateReq req, Map<String, String> parsedOutput) {
  try {
    // Windows CPU parsing - JSON format from PowerShell
    final cpuRaw = WindowsStatusCmdType.cpu.findInMap(parsedOutput);
    if (cpuRaw.isNotEmpty && cpuRaw != 'null' && !cpuRaw.contains('error') && !cpuRaw.contains('Exception')) {
      final cpuResult = WindowsParser.parseCpu(cpuRaw, req.ss);
      if (cpuResult.cores.isNotEmpty) {
        req.ss.cpu.update(cpuResult.cores);
        final brandRaw = WindowsStatusCmdType.cpuBrand.findInMap(parsedOutput);
        if (brandRaw.isNotEmpty && brandRaw != 'null') {
          req.ss.cpu.brand.clear();
          final brandLines = brandRaw.trim().split('\n');
          final uniqueBrands = <String>{};
          for (final line in brandLines) {
            final trimmedLine = line.trim();
            if (trimmedLine.isNotEmpty) {
              uniqueBrands.add(trimmedLine);
            }
          }
          if (uniqueBrands.isNotEmpty) {
            final brandName = uniqueBrands.first;
            req.ss.cpu.brand[brandName] = cpuResult.coreCount;
          }
        }
      }
    }
  } catch (e, s) {
    Loggers.app.warning('Windows CPU parsing failed: $e', s);
  }
}

/// Parse Windows memory data
void _parseWindowsMemoryData(ServerStatusUpdateReq req, Map<String, String> parsedOutput) {
  try {
    final memRaw = WindowsStatusCmdType.mem.findInMap(parsedOutput);
    if (memRaw.isNotEmpty && memRaw != 'null' && !memRaw.contains('error') && !memRaw.contains('Exception')) {
      final memory = WindowsParser.parseMemory(memRaw);
      if (memory != null) {
        req.ss.mem = memory;
      }
    }
  } catch (e, s) {
    Loggers.app.warning('Windows memory parsing failed: $e', s);
  }
}

/// Parse Windows disk data
void _parseWindowsDiskData(ServerStatusUpdateReq req, Map<String, String> parsedOutput) {
  try {
    final diskRaw = WindowsStatusCmdType.disk.findInMap(parsedOutput);
    if (diskRaw.isNotEmpty && diskRaw != 'null') {
      final disks = WindowsParser.parseDisks(diskRaw);
      req.ss.disk = disks;
      req.ss.diskUsage = DiskUsage.parse(disks);
    }
  } catch (e, s) {
    Loggers.app.warning('Windows disk parsing failed: $e', s);
  }
}

/// Parse Windows uptime data
void _parseWindowsUptimeData(ServerStatusUpdateReq req, Map<String, String> parsedOutput) {
  try {
    final uptimeRaw = WindowsStatusCmdType.uptime.findInMap(parsedOutput);
    if (uptimeRaw.isNotEmpty && uptimeRaw != 'null') {
      // PowerShell now returns pre-formatted uptime string (e.g., "28 days, 5:00" or "5:00")
      // No parsing needed - use it directly
      final uptime = uptimeRaw.trim();
      req.ss.more[StatusCmdType.uptime] = uptime;
    }
  } catch (e, s) {
    Loggers.app.warning('Windows uptime parsing failed: $e', s);
  }
}

/// Parse Windows disk I/O data
void _parseWindowsDiskIOData(ServerStatusUpdateReq req, Map<String, String> parsedOutput, int time) {
  try {
    final diskIOraw = WindowsStatusCmdType.diskio.findInMap(parsedOutput);
    if (diskIOraw.isNotEmpty && diskIOraw != 'null') {
      final diskio = _parseWindowsDiskIO(diskIOraw, time);
      req.ss.diskIO.update(diskio);
    }
  } catch (e, s) {
    Loggers.app.warning('Windows disk I/O parsing failed: $e', s);
  }
}

/// Parse Windows connection data
void _parseWindowsConnectionData(ServerStatusUpdateReq req, Map<String, String> parsedOutput) {
  try {
    final connStr = WindowsStatusCmdType.conn.findInMap(parsedOutput);
    final connCount = int.tryParse(connStr.trim());
    if (connCount != null) {
      req.ss.tcp = Conn(maxConn: 0, active: connCount, passive: 0, fail: 0);
    }
  } catch (e, s) {
    Loggers.app.warning('Windows connection parsing failed: $e', s);
  }
}

/// Parse Windows battery data
void _parseWindowsBatteryData(ServerStatusUpdateReq req, Map<String, String> parsedOutput) {
  try {
    final batteryRaw = WindowsStatusCmdType.battery.findInMap(parsedOutput);
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
void _parseWindowsTemperatureData(ServerStatusUpdateReq req, Map<String, String> parsedOutput) {
  try {
    final tempRaw = WindowsStatusCmdType.temp.findInMap(parsedOutput);
    if (tempRaw.isNotEmpty && tempRaw != 'null') {
      _parseWindowsTemperatures(req.ss.temps, tempRaw);
    }
  } catch (e, s) {
    Loggers.app.warning('Windows temperature parsing failed: $e', s);
  }
}

/// Parse Windows GPU data (NVIDIA/AMD)
void _parseWindowsGpuData(ServerStatusUpdateReq req, Map<String, String> parsedOutput) {
  try {
    req.ss.nvidia = NvidiaSmi.fromXml(WindowsStatusCmdType.nvidia.findInMap(parsedOutput));
  } catch (e, s) {
    Loggers.app.warning('Windows NVIDIA GPU parsing failed: $e', s);
  }

  try {
    req.ss.amd = AmdSmi.fromJson(WindowsStatusCmdType.amd.findInMap(parsedOutput));
  } catch (e, s) {
    Loggers.app.warning('Windows AMD GPU parsing failed: $e', s);
  }
}

List<Battery> _parseWindowsBatteries(String raw) {
  try {
    final dynamic jsonData = json.decode(raw);
    final List<Battery> batteries = [];

    final batteryList = jsonData is List ? jsonData : [jsonData];

    for (final batteryData in batteryList) {
      final chargeRemaining = batteryData['EstimatedChargeRemaining'] as int? ?? 0;
      final batteryStatus = batteryData['BatteryStatus'] as int? ?? 0;

      // Windows battery status: 1=Other, 2=Unknown, 3=Full, 4=Low,
      // 5=Critical, 6=Charging, 7=ChargingAndLow, 8=ChargingAndCritical,
      // 9=Undefined, 10=PartiallyCharged
      final isCharging = batteryStatus == 6 || batteryStatus == 7 || batteryStatus == 8;

      batteries.add(
        Battery(
          name: 'Battery',
          percent: chargeRemaining,
          status: isCharging ? BatteryStatus.charging : BatteryStatus.discharging,
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

    if (jsonData is List && jsonData.length >= 2) {
      var sample1 = jsonData[jsonData.length - 2];
      var sample2 = jsonData[jsonData.length - 1];
      if (sample1 is Map && sample1.containsKey('value')) {
        sample1 = sample1['value'];
      }
      if (sample2 is Map && sample2.containsKey('value')) {
        sample2 = sample2['value'];
      }
      if (sample1 is List && sample2 is List && sample1.length == sample2.length) {
        for (int i = 0; i < sample1.length; i++) {
          final s1 = sample1[i];
          final s2 = sample2[i];
          final name = s1['Name']?.toString() ?? '';
          if (name.isEmpty || name == '_Total') continue;
          final rx1 = (s1['BytesReceivedPersec'] as num?)?.toDouble() ?? 0;
          final rx2 = (s2['BytesReceivedPersec'] as num?)?.toDouble() ?? 0;
          final tx1 = (s1['BytesSentPersec'] as num?)?.toDouble() ?? 0;
          final tx2 = (s2['BytesSentPersec'] as num?)?.toDouble() ?? 0;
          final time1 = (s1['Timestamp_Sys100NS'] as num?)?.toDouble() ?? 0;
          final time2 = (s2['Timestamp_Sys100NS'] as num?)?.toDouble() ?? 0;
          final timeDelta = (time2 - time1) / 10000000;
          if (timeDelta <= 0) continue;
          final rxDelta = rx2 - rx1;
          final txDelta = tx2 - tx1;
          if (rxDelta < 0 || txDelta < 0) continue;
          final rxSpeed = rxDelta / timeDelta;
          final txSpeed = txDelta / timeDelta;
          netParts.add(
            NetSpeedPart(name, BigInt.from(rxSpeed.toInt()), BigInt.from(txSpeed.toInt()), currentTime),
          );
        }
      }
    }

    return netParts;
  } catch (e) {
    return [];
  }
}

List<DiskIOPiece> _parseWindowsDiskIO(String raw, int currentTime) {
  try {
    final dynamic jsonData = json.decode(raw);
    final List<DiskIOPiece> diskParts = [];

    if (jsonData is List && jsonData.length >= 2) {
      var sample1 = jsonData[jsonData.length - 2];
      var sample2 = jsonData[jsonData.length - 1];
      if (sample1 is Map && sample1.containsKey('value')) {
        sample1 = sample1['value'];
      }
      if (sample2 is Map && sample2.containsKey('value')) {
        sample2 = sample2['value'];
      }
      if (sample1 is List && sample2 is List && sample1.length == sample2.length) {
        for (int i = 0; i < sample1.length; i++) {
          final s1 = sample1[i];
          final s2 = sample2[i];
          final name = s1['Name']?.toString() ?? '';
          if (name.isEmpty || name == '_Total') continue;
          final read1 = (s1['DiskReadBytesPersec'] as num?)?.toDouble() ?? 0;
          final read2 = (s2['DiskReadBytesPersec'] as num?)?.toDouble() ?? 0;
          final write1 = (s1['DiskWriteBytesPersec'] as num?)?.toDouble() ?? 0;
          final write2 = (s2['DiskWriteBytesPersec'] as num?)?.toDouble() ?? 0;
          final time1 = (s1['Timestamp_Sys100NS'] as num?)?.toDouble() ?? 0;
          final time2 = (s2['Timestamp_Sys100NS'] as num?)?.toDouble() ?? 0;
          final timeDelta = (time2 - time1) / 10000000;
          if (timeDelta <= 0) continue;
          final readDelta = read2 - read1;
          final writeDelta = write2 - write1;
          if (readDelta < 0 || writeDelta < 0) continue;
          final readSpeed = readDelta / timeDelta;
          final writeSpeed = writeDelta / timeDelta;
          final sectorsRead = (readSpeed / 512).round();
          final sectorsWrite = (writeSpeed / 512).round();

          diskParts.add(
            DiskIOPiece(
              dev: name,
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

void _parseWindowsTemperatures(Temperatures temps, String raw) {
  try {
    // Handle error output
    if (raw.contains('Error') || raw.contains('Exception') || raw.contains('The term')) {
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
