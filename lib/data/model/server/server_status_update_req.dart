import 'package:toolbox/data/model/server/server.dart';
import 'package:toolbox/data/model/server/system.dart';
import 'package:toolbox/data/res/logger.dart';

import '../app/shell_func.dart';
import 'cpu.dart';
import 'disk.dart';
import 'memory.dart';
import 'net_speed.dart';
import 'conn.dart';

class ServerStatusUpdateReq {
  final ServerStatus ss;
  final List<String> segments;
  final SystemType system;

  const ServerStatusUpdateReq({
    required this.system,
    required this.ss,
    required this.segments,
  });
}

Future<ServerStatus> getStatus(ServerStatusUpdateReq req) async {
  switch (req.system) {
    case SystemType.linux:
      return _getLinuxStatus(req);
    case SystemType.bsd:
      return _getBsdStatus(req);
  }
}

// Wrap each operation with a try-catch, so that if one operation fails,
// the following operations can still be executed.
Future<ServerStatus> _getLinuxStatus(ServerStatusUpdateReq req) async {
  final segments = req.segments;

  final time = int.tryParse(StatusCmdType.time.find(segments)) ??
      DateTime.now().millisecondsSinceEpoch ~/ 1000;

  try {
    final net = parseNetSpeed(StatusCmdType.net.find(segments), time);
    req.ss.netSpeed.update(net);
  } catch (e, s) {
    Loggers.parse.warning(e, s);
  }

  try {
    final sys = _parseSysVer(
      StatusCmdType.sys.find(segments),
      StatusCmdType.host.find(segments),
    );
    if (sys != null) {
      req.ss.sysVer = sys;
    }
  } catch (e, s) {
    Loggers.parse.warning(e, s);
  }

  try {
    final cpus = parseCPU(StatusCmdType.cpu.find(segments));
    req.ss.cpu.update(cpus);
    req.ss.temps.parse(
      StatusCmdType.tempType.find(segments),
      StatusCmdType.tempVal.find(segments),
    );
  } catch (e, s) {
    Loggers.parse.warning(e, s);
  }

  try {
    final tcp = parseConn(StatusCmdType.conn.find(segments));
    if (tcp != null) {
      req.ss.tcp = tcp;
    }
  } catch (e, s) {
    Loggers.parse.warning(e, s);
  }

  try {
    req.ss.disk = parseDisk(StatusCmdType.disk.find(segments));
  } catch (e, s) {
    Loggers.parse.warning(e, s);
  }

  try {
    req.ss.mem = parseMem(StatusCmdType.mem.find(segments));
  } catch (e, s) {
    Loggers.parse.warning(e, s);
  }

  try {
    final uptime = _parseUpTime(StatusCmdType.uptime.find(segments));
    if (uptime != null) {
      req.ss.uptime = uptime;
    }
  } catch (e, s) {
    Loggers.parse.warning(e, s);
  }

  try {
    req.ss.swap = parseSwap(StatusCmdType.mem.find(segments));
  } catch (e, s) {
    Loggers.parse.warning(e, s);
  }

  try {
    final diskio = DiskIO.parse(StatusCmdType.diskio.find(segments), time);
    req.ss.diskIO.update(diskio);
  } catch (e, s) {
    Loggers.parse.warning(e, s);
  }
  return req.ss;
}

// Same as above, wrap with try-catch
Future<ServerStatus> _getBsdStatus(ServerStatusUpdateReq req) async {
  final segments = req.segments;

  try {
    final time = int.parse(BSDStatusCmdType.time.find(segments));
    final net = parseBsdNetSpeed(BSDStatusCmdType.net.find(segments), time);
    req.ss.netSpeed.update(net);
  } catch (e, s) {
    Loggers.parse.warning(e, s);
  }

  try {
    req.ss.sysVer = BSDStatusCmdType.sys.find(segments);
  } catch (e, s) {
    Loggers.parse.warning(e, s);
  }

  try {
    req.ss.cpu = parseBsdCpu(BSDStatusCmdType.cpu.find(segments));
  } catch (e, s) {
    Loggers.parse.warning(e, s);
  }

  // try {
  //   req.ss.mem = parseBsdMem(BSDStatusCmdType.mem.find(segments));
  // } catch (e, s) {
  //   Loggers.parse.warning(e, s);
  // }

  try {
    final uptime = _parseUpTime(BSDStatusCmdType.uptime.find(segments));
    if (uptime != null) {
      req.ss.uptime = uptime;
    }
  } catch (e, s) {
    Loggers.parse.warning(e, s);
  }

  try {
    req.ss.disk = parseDisk(BSDStatusCmdType.disk.find(segments));
  } catch (e, s) {
    Loggers.parse.warning(e, s);
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

String? _parseSysVer(String raw, String hostname) {
  final s = raw.split('=');
  if (s.length == 2) {
    return s[1].replaceAll('"', '').replaceFirst('\n', '');
  }
  return hostname.isEmpty ? null : hostname;
}
