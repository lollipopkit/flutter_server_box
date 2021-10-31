import 'dart:async';

import 'package:logging/logging.dart';
import 'package:ssh2/ssh2.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/server/cpu_2_status.dart';
import 'package:toolbox/data/model/server/cpu_status.dart';
import 'package:toolbox/data/model/server/server_connection_state.dart';
import 'package:toolbox/data/model/server/disk_info.dart';
import 'package:toolbox/data/model/server/server.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/server_status.dart';
import 'package:toolbox/data/model/server/tcp_status.dart';
import 'package:toolbox/data/store/server.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/locator.dart';

class ServerProvider extends BusyProvider {
  List<ServerInfo> _servers = [];
  List<ServerInfo> get servers => _servers;

  final logger = Logger('ServerProvider');

  CpuStatus get emptyCpuStatus => CpuStatus('cpu', 0, 0, 0, 0, 0, 0, 0);

  Cpu2Status get emptyCpu2Status =>
      Cpu2Status([emptyCpuStatus], [emptyCpuStatus], '');

  ServerStatus get emptyStatus => ServerStatus(
      emptyCpu2Status,
      [100, 0],
      'Loading...',
      '',
      [DiskInfo('/', '/', 0, '0', '0', '0')],
      TcpStatus(0, 0, 0, 0));

  Future<void> loadLocalData() async {
    setBusyState(true);
    final infos = locator<ServerStore>().fetch();
    _servers = List.generate(infos.length, (index) => genInfo(infos[index]));
    setBusyState(false);
    notifyListeners();
  }

  ServerInfo genInfo(ServerPrivateInfo spi) {
    return ServerInfo(
        spi, emptyStatus, genClient(spi), ServerConnectionState.disconnected);
  }

  SSHClient genClient(ServerPrivateInfo spi) {
    return SSHClient(
        host: spi.ip,
        port: spi.port,
        username: spi.user,
        passwordOrKey: spi.authorization);
  }

  Future<void> refreshData({int? idx}) async {
    if (idx != null) {
      final singleData = await _getData(_servers[idx].info, idx);
      if (singleData != null) {
        _servers[idx].status = singleData;
        notifyListeners();
      }
      return;
    }
    try {
      await Future.wait(_servers.map((s) async {
        final idx = _servers.indexOf(s);
        final status = await _getData(s.info, idx);
        if (status != null) {
          _servers[idx].status = status;
          notifyListeners();
        }
      }));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> startAutoRefresh() async {
    final duration =
        locator<SettingStore>().serverStatusUpdateInterval.fetch()!;
    if (duration == 0) return;
    Timer.periodic(Duration(seconds: duration), (_) async {
      await refreshData();
    });
  }

  void addServer(ServerPrivateInfo info) {
    _servers.add(genInfo(info));
    locator<ServerStore>().put(info);
    notifyListeners();
    refreshData(idx: _servers.length - 1);
  }

  void delServer(ServerPrivateInfo info) {
    _servers.removeWhere((e) => e.info == info);
    locator<ServerStore>().delete(info);
    notifyListeners();
  }

  void updateServer(ServerPrivateInfo old, ServerPrivateInfo newInfo) {
    final idx = _servers.indexWhere((e) => e.info == old);
    _servers[idx].info = newInfo;
    _servers[idx].client = genClient(newInfo);
    locator<ServerStore>().update(old, newInfo);
    notifyListeners();
    refreshData(idx: idx);
  }

  Future<ServerStatus?> _getData(ServerPrivateInfo info, int idx) async {
    final client = _servers[idx].client;
    final connected = await client.isConnected();
    final state = _servers[idx].connectionState;
    if (!connected || state == ServerConnectionState.failed || state == ServerConnectionState.disconnected) {
      _servers[idx].connectionState = ServerConnectionState.connecting;
      notifyListeners();
      final time1 = DateTime.now();
      try {
        await client.connect();
        final time2 = DateTime.now();
        logger.info(
            'Connected to [${info.name}] in [${time2.difference(time1).toString()}].');
        _servers[idx].connectionState = ServerConnectionState.connected;
        notifyListeners();
      } catch (e) {
        _servers[idx].connectionState = ServerConnectionState.failed;
        notifyListeners();
        logger.warning(e);
      }
    }
    try {
      final cpu = await client.execute("cat /proc/stat | grep cpu") ?? '';
      final cpuTemp = await client.execute(
              r"paste <(cat /sys/class/thermal/thermal_zone*/type) <(cat /sys/class/thermal/thermal_zone*/temp) | column -s $'\t' -t | sed 's/\(.\)..$/.\1°C/'") ??
          '';
      final mem = await client.execute('free -m') ?? '';
      final sysVer =
          await client.execute('cat /etc/os-release | grep PRETTY_NAME') ?? '';
      final upTime = await client.execute('uptime') ?? '';
      final disk = await client.execute('df -h') ?? '';
      final tcp = await client.execute('cat /proc/net/snmp') ?? '';

      return ServerStatus(
          _getCPU(cpu, _servers[idx].status.cpu2Status, cpuTemp),
          _getMem(mem),
          _getSysVer(sysVer),
          _getUpTime(upTime),
          _getDisk(disk),
          _getTcp(tcp));
    } catch (e) {
      _servers[idx].connectionState = ServerConnectionState.failed;
      notifyListeners();
      logger.warning(e);
      return null;
    }
  }

  String _getSysVer(String raw) {
    final s = raw.split('=');
    if (s.length == 2) {
      return s[1].replaceAll('"', '').replaceFirst('\n', '');
    }
    return '';
  }

  String _getCPUTemp(String raw) {
    final split = raw.split('\n');
    for (var item in split) {
      if (item.contains('x86_pkg_temp') || item.contains('cpu_thermal')) {
        return item.split(' ').last;
      }
    }
    return '';
  }

  Cpu2Status _getCPU(String raw, Cpu2Status old, String temp) {
    final List<CpuStatus> cpus = [];

    for (var item in raw.split('\n')) {
      if (item == '') break;
      final id = item.split(' ').first;
      final matches = item.replaceFirst(id, '').trim().split(' ');
      cpus.add(CpuStatus(
          id,
          int.parse(matches[0]),
          int.parse(matches[1]),
          int.parse(matches[2]),
          int.parse(matches[3]),
          int.parse(matches[4]),
          int.parse(matches[5]),
          int.parse(matches[6])));
    }
    if (cpus.isEmpty) {
      return emptyCpu2Status;
    }

    return old.update(cpus, _getCPUTemp(temp));
  }

  String _getUpTime(String raw) {
    return raw.split('up ')[1].split(', ')[0];
  }

  TcpStatus _getTcp(String raw) {
    final lines = raw.split('\n');
    int idx = 0;
    for (var item in lines) {
      if (item.contains('Tcp:')) {
        idx++;
      }
      if (idx == 2) {
        final vals = item.split(RegExp(r'\s{1,}'));
        return TcpStatus(vals[5].i, vals[6].i, vals[7].i, vals[8].i);
      }
    }
    return TcpStatus(0, 0, 0, 0);
  }

  List<DiskInfo> _getDisk(String disk) {
    final list = <DiskInfo>[];
    final items = disk.split('\n');
    for (var item in items) {
      if (items.indexOf(item) == 0 || item.isEmpty) {
        continue;
      }
      final vals = item.split(RegExp(r'\s{1,}'));
      list.add(DiskInfo(vals[0], vals[5],
          int.parse(vals[4].replaceFirst('%', '')), vals[2], vals[1], vals[3]));
    }
    return list;
  }

  List<int> _getMem(String mem) {
    for (var item in mem.split('\n')) {
      if (item.contains('Mem:')) {
        return RegExp(r'[1-9][0-9]*')
            .allMatches(item)
            .map((e) => int.parse(item.substring(e.start, e.end)))
            .toList();
      }
    }
    return [];
  }
}
