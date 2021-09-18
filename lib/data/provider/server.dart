import 'dart:async';

import 'package:ssh2/ssh2.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/disk_info.dart';
import 'package:toolbox/data/model/server.dart';
import 'package:toolbox/data/model/server_private_info.dart';
import 'package:toolbox/data/model/server_status.dart';
import 'package:toolbox/data/model/tcp_status.dart';
import 'package:toolbox/data/store/server.dart';
import 'package:toolbox/locator.dart';

class ServerProvider extends BusyProvider {
  List<ServerInfo> _servers = [];
  List<ServerInfo> get servers => _servers;

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
        spi,
        emptyStatus,
        SSHClient(
            host: spi.ip!,
            port: spi.port!,
            username: spi.user!,
            passwordOrKey: spi.authorization));
  }

  SSHClient genClient(ServerPrivateInfo spi) {
    return SSHClient(
        host: spi.ip!,
        port: spi.port!,
        username: spi.user!,
        passwordOrKey: spi.authorization);
  }

  Future<void> refreshData() async {
    final _serversStatus = await Future.wait(
        _servers.map((s) => _getData(s.info, _servers.indexOf(s))));
    int idx = 0;
    for (var item in _serversStatus) {
      _servers[idx].status = item;
      idx++;
    }
    notifyListeners();
  }

  Future<void> startAutoRefresh() async {
    Timer.periodic(const Duration(seconds: 3), (_) async {
      await refreshData();
    });
  }

  void addServer(ServerPrivateInfo info) {
    _servers.add(genInfo(info));
    locator<ServerStore>().put(info);
    notifyListeners();
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
  }

  Future<ServerStatus> _getData(ServerPrivateInfo info, int idx) async {
    final client = _servers[idx].client;
    if (!(await client.isConnected())) {
      await client.connect();
    }
    final cpu = await client.execute(
            "top -bn1 | grep load | awk '{printf \"%.2f\", \$(NF-2)}'") ??
        '0';
    final mem = await client.execute('free -m') ?? '';
    final sysVer = await client.execute('cat /etc/issue.net') ?? 'Unkown';
    final upTime = await client.execute('uptime') ?? 'Failed';
    final disk = await client.execute('df -h') ?? 'Failed';
    final tcp = await client.execute('cat /proc/net/snmp') ?? 'Failed';

    return ServerStatus(
        cpuPercent: double.parse(cpu.trim()),
        memList: _getMem(mem),
        sysVer: sysVer.trim(),
        disk: _getDisk(disk),
        uptime: _getUpTime(upTime),
        tcp: _getTcp(tcp));
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
