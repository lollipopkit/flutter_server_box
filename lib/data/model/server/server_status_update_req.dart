import '../app/shell_func.dart';
import 'cpu.dart';
import 'disk.dart';
import 'memory.dart';
import 'net_speed.dart';
import 'server_status.dart';
import 'conn.dart';

class ServerStatusUpdateReq {
  final ServerStatus ss;
  final List<String> segments;

  const ServerStatusUpdateReq(this.ss, this.segments);
}

Future<ServerStatus> getStatus(ServerStatusUpdateReq req) async {
  final segments = req.segments;

  final time = int.parse(StatusCmdType.time.find(segments));

  final net = parseNetSpeed(StatusCmdType.net.find(segments), time);
  req.ss.netSpeed.update(net);

  final sys = _parseSysVer(
    StatusCmdType.sys.find(segments),
    StatusCmdType.host.find(segments),
    StatusCmdType.sysRhel.find(segments),
  );
  if (sys != null) {
    req.ss.sysVer = sys;
  }

  final cpus = parseCPU(StatusCmdType.cpu.find(segments));
  req.ss.cpu.update(cpus);

  req.ss.temps.parse(
    StatusCmdType.tempType.find(segments),
    StatusCmdType.tempVal.find(segments),
  );

  final tcp = parseConn(StatusCmdType.conn.find(segments));
  if (tcp != null) {
    req.ss.tcp = tcp;
  }

  req.ss.disk = parseDisk(StatusCmdType.disk.find(segments));

  req.ss.mem = parseMem(StatusCmdType.mem.find(segments));

  final uptime = _parseUpTime(StatusCmdType.uptime.find(segments));
  if (uptime != null) {
    req.ss.uptime = uptime;
  }

  req.ss.swap = parseSwap(StatusCmdType.mem.find(segments));
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
  try {
    final s = raw.split('=');
    if (s.length == 2) {
      return s[1].replaceAll('"', '').replaceFirst('\n', '');
    }
  } catch (e) {
    if (!rawRhel.contains('cat: /etc/redhat-release:')) {
      return rawRhel;
    }
    if (hostname.isNotEmpty) return hostname;
  }
  return null;
}
