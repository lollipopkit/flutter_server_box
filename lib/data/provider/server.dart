import 'dart:async';

import 'package:logging/logging.dart';
import 'package:ssh2/ssh2.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/server_connection_state.dart';
import 'package:toolbox/data/model/disk_info.dart';
import 'package:toolbox/data/model/server.dart';
import 'package:toolbox/data/model/server_private_info.dart';
import 'package:toolbox/data/model/server_status.dart';
import 'package:toolbox/data/model/tcp_status.dart';
import 'package:toolbox/data/store/server.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/locator.dart';

class ServerProvider extends BusyProvider {
  List<ServerInfo> _servers = [];
  List<ServerInfo> get servers => _servers;

  final logger = Logger('ServerProvider');

  ServerStatus get emptyStatus => ServerStatus(
      cpuPercent: 0,
      memList: [100, 0],
      disk: [
        DiskInfo(
            mountLocation: '/',
            mountPath: '/',
            used: '0',
            size: '0',
            avail: '0',
            usedPercent: 0)
      ],
      sysVer: '',
      uptime: '',
      tcp: TcpStatus(maxConn: 0, active: 0, passive: 0, fail: 0));

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
        host: spi.ip!,
        port: spi.port!,
        username: spi.user!,
        passwordOrKey: spi.authorization);
  }

  Future<void> refreshData({int? idx}) async {
    if (idx != null) {
      final singleData = await _getData(_servers[idx].info, idx);
      if (singleData != null) {
        _servers[idx].status = singleData;
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
    if (!connected || state != ServerConnectionState.connected) {
      _servers[idx].connectionState = ServerConnectionState.connecting;
      final time1 = DateTime.now();
      try {
        await client.connect();
        final time2 = DateTime.now();
        logger.info(
            'Connected to [${info.name}] in [${time2.difference(time1).toString()}].');
        _servers[idx].connectionState = ServerConnectionState.connected;
      } catch (e) {
        _servers[idx].connectionState = ServerConnectionState.failed;
        logger.warning(e);
      }
    }

    try {
      final cpu = await client.execute("top -bn1 | grep Cpu") ?? '0';
      final mem = await client.execute('free -m') ?? '';
      final sysVer = await client.execute('cat /etc/issue.net') ?? 'Unkown';
      final upTime = await client.execute('uptime') ?? 'Failed';
      final disk = await client.execute('df -h') ?? 'Failed';
      final tcp = await client.execute('cat /proc/net/snmp') ?? 'Failed';

      return ServerStatus(
          cpuPercent: _getCPU(cpu),
          memList: _getMem(mem),
          sysVer: sysVer.trim(),
          disk: _getDisk(disk),
          uptime: _getUpTime(upTime),
          tcp: _getTcp(tcp));
    } catch (e) {
      _servers[idx].connectionState = ServerConnectionState.failed;
      logger.warning(e);
      return null;
    } finally {
      notifyListeners();
    }
  }

  double _getCPU(String raw) {
    final match = RegExp('[0-9]*\\.[0-9] id,').firstMatch(raw);
    if (match == null) {
      return 0;
    }
    return 100 -
        double.parse(
            raw.substring(match.start, match.end).replaceAll(' id,', ''));
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
        return TcpStatus(
            maxConn: vals[5].i,
            active: vals[6].i,
            passive: vals[7].i,
            fail: vals[8].i);
      }
    }
    return TcpStatus(maxConn: 0, active: 0, passive: 0, fail: 0);
  }

  List<DiskInfo> _getDisk(String disk) {
    final list = <DiskInfo>[];
    final items = disk.split('\n');
    for (var item in items) {
      if (items.indexOf(item) == 0 || item.isEmpty) {
        continue;
      }
      final vals = item.split(RegExp(r'\s{1,}'));
      list.add(DiskInfo(
          mountPath: vals[1],
          mountLocation: vals[5],
          usedPercent: double.parse(vals[4].replaceFirst('%', '')),
          used: vals[2],
          size: vals[1],
          avail: vals[3]));
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
