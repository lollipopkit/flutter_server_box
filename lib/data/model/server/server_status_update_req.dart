import '../../res/server_cmd.dart';
import 'cpu_status.dart';
import 'disk_info.dart';
import 'memory.dart';
import 'net_speed.dart';
import 'server_status.dart';
import 'conn_status.dart';

class ServerStatusUpdateReq {
  final ServerStatus ss;
  final List<String> segments;

  const ServerStatusUpdateReq(this.ss, this.segments);
}

extension _SegmentsExt on List<String> {
  String at(CmdType t) {
    final index = t.index;
    if (index >= length) return '';
    return this[index];
  }
}

Future<ServerStatus> getStatus(ServerStatusUpdateReq req) async {
  final net = parseNetSpeed(req.segments.at(CmdType.net));
  req.ss.netSpeed.update(net);

  final sys = _parseSysVer(
    req.segments.at(CmdType.sys),
    req.segments.at(CmdType.host),
    req.segments.at(CmdType.sysRhel),
  );
  if (sys != null) {
    req.ss.sysVer = sys;
  }

  final cpus = parseCPU(req.segments.at(CmdType.cpu));
  req.ss.cpu.update(cpus);

  req.ss.temps.parse(
    req.segments.at(CmdType.tempType),
    req.segments.at(CmdType.tempVal),
  );

  final tcp = parseConn(req.segments.at(CmdType.conn));
  if (tcp != null) {
    req.ss.tcp = tcp;
  }

  req.ss.disk = parseDisk(req.segments.at(CmdType.disk));

  req.ss.mem = parseMem(req.segments.at(CmdType.mem));

  final uptime = _parseUpTime(req.segments.at(CmdType.uptime));
  if (uptime != null) {
    req.ss.uptime = uptime;
  }

  req.ss.swap = parseSwap(req.segments.at(CmdType.mem));
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

String? _parseSysVer(String raw, String hostname, String rawRhel) {
  if (!rawRhel.contains('No such file')) {
    return rawRhel;
  }
  final s = raw.split('=');
  if (s.length == 2) {
    return s[1].replaceAll('"', '').replaceFirst('\n', '');
  }
  if (hostname.isNotEmpty) return hostname;
  return null;
}
