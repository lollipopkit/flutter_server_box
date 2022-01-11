import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/server/cpu_2_status.dart';
import 'package:toolbox/data/model/server/cpu_status.dart';
import 'package:toolbox/data/model/server/memory.dart';
import 'package:toolbox/data/model/server/net_speed.dart';
import 'package:toolbox/data/model/server/server_connection_state.dart';
import 'package:toolbox/data/model/server/disk_info.dart';
import 'package:toolbox/data/model/server/server.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/server_status.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/model/server/tcp_status.dart';
import 'package:toolbox/data/store/private_key.dart';
import 'package:toolbox/data/store/server.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/locator.dart';

/// Must put this func out of any Class.
/// Because of this function is called by [compute] in [ServerProvider.genClient].
/// https://stackoverflow.com/questions/51998995/invalid-arguments-illegal-argument-in-isolate-message-object-is-a-closure
List<SSHKeyPair> loadIndentity(String key) {
  return SSHKeyPair.fromPem(key);
}

class ServerProvider extends BusyProvider {
  List<ServerInfo> _servers = [];
  List<ServerInfo> get servers => _servers;

  Timer? _timer;

  final logger = Logger('ServerProvider');

  Memory get emptyMemory =>
      Memory(total: 1, used: 0, free: 1, shared: 0, cache: 0, avail: 1);

  NetSpeedPart get emptyNetSpeedPart => NetSpeedPart('', 0, 0, 0);

  NetSpeed get emptyNetSpeed =>
      NetSpeed([emptyNetSpeedPart], [emptyNetSpeedPart]);

  CpuStatus get emptyCpuStatus => CpuStatus('cpu', 0, 0, 0, 0, 0, 0, 0);

  Cpu2Status get emptyCpu2Status =>
      Cpu2Status([emptyCpuStatus], [emptyCpuStatus], '');

  ServerStatus get emptyStatus => ServerStatus(
      emptyCpu2Status,
      emptyMemory,
      'Loading...',
      '',
      [DiskInfo('/', '/', 0, '0', '0', '0')],
      TcpStatus(0, 0, 0, 0),
      emptyNetSpeed);

  Future<void> loadLocalData() async {
    setBusyState(true);
    final infos = locator<ServerStore>().fetch();
    _servers = List.generate(infos.length, (index) => genInfo(infos[index]));
    setBusyState(false);
    notifyListeners();
  }

  ServerInfo genInfo(ServerPrivateInfo spi) {
    return ServerInfo(
        spi, emptyStatus, null, ServerConnectionState.disconnected);
  }

  Future<SSHClient> genClient(ServerPrivateInfo spi) async {
    final socket = await SSHSocket.connect(spi.ip, spi.port);
    if (spi.pubKeyId == null) {
      return SSHClient(socket,
          username: spi.user,
          onPasswordRequest: () => spi.authorization as String);
    }
    final key = locator<PrivateKeyStore>().get(spi.pubKeyId!);
    return SSHClient(socket,
        username: spi.user, identities: await compute(loadIndentity, key.privateKey));
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
        if (idx == -1) return;
        final status = await _getData(s.info, idx);
        if (status != null) {
          _servers[idx].status = status;
          notifyListeners();
        }
      }));
    } catch (e) {
      if (e is! RangeError) {
        rethrow;
      }
    }
  }

  Future<void> startAutoRefresh() async {
    final duration =
        locator<SettingStore>().serverStatusUpdateInterval.fetch()!;
    if (duration == 0) return;
    stopAutoRefresh();
    _timer = Timer.periodic(Duration(seconds: duration), (_) async {
      await refreshData();
    });
  }

  void stopAutoRefresh() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  void addServer(ServerPrivateInfo info) {
    _servers.add(genInfo(info));
    locator<ServerStore>().put(info);
    notifyListeners();
    refreshData(idx: _servers.length - 1);
  }

  void delServer(ServerPrivateInfo info) {
    final idx = _servers.indexWhere((s) => s.info == info);
    _servers[idx].client?.close();
    _servers.removeAt(idx);
    notifyListeners();
    locator<ServerStore>().delete(info);
  }

  Future<void> updateServer(
      ServerPrivateInfo old, ServerPrivateInfo newInfo) async {
    final idx = _servers.indexWhere((e) => e.info == old);
    _servers[idx].info = newInfo;
    _servers[idx].client = await genClient(newInfo);
    locator<ServerStore>().update(old, newInfo);
    notifyListeners();
    refreshData(idx: idx);
  }

  Future<ServerStatus?> _getData(ServerPrivateInfo info, int idx) async {
    final client = _servers[idx].client;
    final connected = client != null;
    final state = _servers[idx].connectionState;
    if (!connected ||
        state == ServerConnectionState.failed ||
        state == ServerConnectionState.disconnected) {
      _servers[idx].connectionState = ServerConnectionState.connecting;
      notifyListeners();
      final time1 = DateTime.now();
      try {
        _servers[idx].client = await genClient(info);
        final time2 = DateTime.now();
        logger.info(
            'Connected to [${info.name}] in [${time2.difference(time1).toString()}].');
        _servers[idx].connectionState = ServerConnectionState.connected;
        notifyListeners();
      } catch (e) {
        _servers[idx].connectionState = ServerConnectionState.failed;
        _servers[idx].status.failedInfo = e.toString();
        notifyListeners();
        logger.warning(e);
      }
    }
    try {
      if (!connected) return null;
      final cpu = utf8.decode(await client!.run("cat /proc/stat | grep cpu"));
      final cpuTemp = utf8.decode(await client.run(
          r"paste <(cat /sys/class/thermal/thermal_zone*/type) <(cat /sys/class/thermal/thermal_zone*/temp) | column -s $'\t' -t | sed 's/\(.\)..$/.\1°C/'"));
      final mem = utf8.decode(await client.run('free -m'));
      final sysVer = utf8
          .decode(await client.run('cat /etc/os-release | grep PRETTY_NAME'));
      final upTime = utf8.decode(await client.run('uptime'));
      final disk = utf8.decode(await client.run('df -h'));
      final tcp = utf8.decode(await client.run('cat /proc/net/snmp'));
      final netSpeed =
          utf8.decode(await client.run('cat /proc/net/dev && date +%s'));

      return ServerStatus(
          _getCPU(cpu, _servers[idx].status.cpu2Status, cpuTemp),
          _getMem(mem),
          _getSysVer(sysVer),
          _getUpTime(upTime),
          _getDisk(disk),
          _getTcp(tcp),
          _getNetSpeed(netSpeed, _servers[idx].status.netSpeed));
    } catch (e) {
      _servers[idx].connectionState = ServerConnectionState.failed;
      notifyListeners();
      logger.warning(e);
      return null;
    }
  }

  /// [raw] example:
  /// Inter-|   Receive                                                |  Transmit
  ///   face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
  ///   lo: 45929941  269112    0    0    0     0          0         0 45929941  269112    0    0    0     0       0          0
  ///   eth0: 48481023  505772    0    0    0     0          0         0 36002262  202307    0    0    0     0       0          0
  /// 1635752901
  NetSpeed _getNetSpeed(String raw, NetSpeed old) {
    final split = raw.split('\n');
    final deviceCount = split.length - 3;
    if (deviceCount < 1) return emptyNetSpeed;
    final time = int.parse(split[split.length - 2]);
    final results = <NetSpeedPart>[];
    for (int idx = 2; idx < deviceCount; idx++) {
      final data = split[idx].trim().split(':');
      final device = data.first;
      final bytes = data.last.trim().split(' ');
      bytes.removeWhere((element) => element == '');
      final bytesIn = int.parse(bytes.first);
      final bytesOut = int.parse(bytes[8]);
      results.add(NetSpeedPart(device, bytesIn, bytesOut, time));
    }
    return old.update(results);
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

  Memory _getMem(String mem) {
    for (var item in mem.split('\n')) {
      if (item.contains('Mem:')) {
        final split = item.replaceFirst('Mem:', '').split(' ');
        split.removeWhere((e) => e == '');
        final memList = split.map((e) => int.parse(e)).toList();
        return Memory(
            total: memList[0],
            used: memList[1],
            free: memList[2],
            shared: memList[3],
            cache: memList[4],
            avail: memList[5]);
      }
    }
    return emptyMemory;
  }

  Future<String?> runSnippet(int idx, Snippet snippet) async {
    final result = await _servers[idx].client!.run(snippet.script);
    return utf8.decode(result);
  }
}
