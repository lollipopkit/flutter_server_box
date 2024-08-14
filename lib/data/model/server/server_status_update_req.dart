import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/battery.dart';
import 'package:server_box/data/model/server/nvdia.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/system.dart';

import 'package:server_box/data/model/app/shell_func.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/conn.dart';

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
    final sys = _parseSysVer(
      StatusCmdType.sys.find(segments),
    );
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
    req.ss.nvidia = NvidiaSmi.fromXml(StatusCmdType.nvidia.find(segments));
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

  // try {
  //   req.ss.mem = parseBsdMem(BSDStatusCmdType.mem.find(segments));
  // } catch (e, s) {
  //   Loggers.app.warning(e, s);
  // }

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
String? _parseUpTime(String raw) {
  final splitedUp = raw.split('up ');
  if (splitedUp.length == 2) {
    final splitedComma = splitedUp[1].split(', ');
    if (splitedComma.length >= 2) {
      return splitedComma[0];
    }
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
