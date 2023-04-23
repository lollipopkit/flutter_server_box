import 'cpu_status.dart';
import 'disk_info.dart';
import 'memory.dart';
import 'net_speed.dart';
import 'server_status.dart';
import 'tcp_status.dart';

class ServerStatusUpdateReq {
  final ServerStatus ss;
  final List<String> segments;

  const ServerStatusUpdateReq(this.ss, this.segments);
}

Future<ServerStatus> getStatus(ServerStatusUpdateReq req) async {
  final net = parseNetSpeed(req.segments[0]);
  req.ss.netSpeed.update(net);
  final sys = _parseSysVer(req.segments[1]);
  if (sys != null) {
    req.ss.sysVer = sys;
  }
  final cpus = parseCPU(req.segments[2]);
  final cpuTemp = parseCPUTemp(req.segments[7], req.segments[8]);
  req.ss.cpu.update(cpus, cpuTemp);
  final tcp = parseTcp(req.segments[4]);
  if (tcp != null) {
    req.ss.tcp = tcp;
  }
  req.ss.disk = parseDisk(req.segments[5]);
  req.ss.mem = parseMem(req.segments[6]);
  final uptime = _parseUpTime(req.segments[3]);
  if (uptime != null) {
    req.ss.uptime = uptime;
  }
  req.ss.swap = parseSwap(req.segments[6]);
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