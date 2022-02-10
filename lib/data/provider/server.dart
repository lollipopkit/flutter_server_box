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
        username: spi.user,
        identities: await compute(loadIndentity, key.privateKey));
  }

  Future<void> refreshData({ServerPrivateInfo? spi}) async {
    if (spi != null) {
      _getData(spi);
      return;
    }
    try {
      await Future.wait(_servers.map((s) async {
        await _getData(s.info);
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

  void setDisconnected() {
    for (var i = 0; i < _servers.length; i++) {
      _servers[i].connectionState = ServerConnectionState.disconnected;
    }
  }

  void addServer(ServerPrivateInfo spi) {
    _servers.add(genInfo(spi));
    locator<ServerStore>().put(spi);
    notifyListeners();
    refreshData(spi: spi);
  }

  void delServer(ServerPrivateInfo info) {
    final idx = _servers.indexWhere((s) => s.info == info);
    _servers[idx].client?.close();
    _servers.removeAt(idx);
    notifyListeners();
    locator<ServerStore>().delete(info);
  }

  Future<void> updateServer(
      ServerPrivateInfo old, ServerPrivateInfo newSpi) async {
    final idx = _servers.indexWhere((e) => e.info == old);
    if (idx < 0) {
      throw RangeError.index(idx, _servers);
    }
    _servers[idx].info = newSpi;
    _servers[idx].client = await genClient(newSpi);
    locator<ServerStore>().update(old, newSpi);
    notifyListeners();
    refreshData(spi: newSpi);
  }

  Future<void> _getData(ServerPrivateInfo spi) async {
    final idx = _servers.indexWhere((element) => element.info == spi);
    final state = _servers[idx].connectionState;
    if (_servers[idx].client == null ||
        state == ServerConnectionState.failed ||
        state == ServerConnectionState.disconnected) {
      _servers[idx].connectionState = ServerConnectionState.connecting;
      notifyListeners();
      final time1 = DateTime.now();
      try {
        _servers[idx].client = await genClient(spi);
        final time2 = DateTime.now();
        logger.info(
            'Connected to [${spi.name}] in [${time2.difference(time1).toString()}].');
        _servers[idx].connectionState = ServerConnectionState.connected;
        notifyListeners();
      } catch (e) {
        _servers[idx].connectionState = ServerConnectionState.failed;
        _servers[idx].status.failedInfo = e.toString() + ' ## ';
        notifyListeners();
        logger.warning(e);
      }
    }
    final si = _servers[idx];
    try {
      if (si.client == null) return;
      final raw = utf8.decode(await si.client!.run(
          r"cat /proc/net/dev && date +%s && echo 'A====A' && cat /etc/os-release | grep PRETTY_NAME && echo 'A====A' && cat /proc/stat | grep cpu && echo 'A====A' && paste <(cat /sys/class/thermal/thermal_zone*/type) <(cat /sys/class/thermal/thermal_zone*/temp) | column -s $'\t' -t | sed 's/\(.\)..$/.\1°C/' && echo 'A====A' && uptime && echo 'A====A' && cat /proc/net/snmp && echo 'A====A' && df -h && echo 'A====A' && free -m"));
      final lines = raw.split('A====A').map((e) => e.trim()).toList();
      _getCPU(spi, lines[2], lines[3]);
      _getMem(spi, lines[7]);
      _getSysVer(spi, lines[1]);
      _getUpTime(spi, lines[4]);
      _getDisk(spi, lines[6]);
      _getTcp(spi, lines[5]);
      _getNetSpeed(spi, lines[0]);
    } catch (e) {
      _servers[idx].connectionState = ServerConnectionState.failed;
      servers[idx].status.failedInfo = e.toString();
      logger.warning(e);
    } finally {
      notifyListeners();
    }
  }

  /// [raw] example:
  /// Inter-|   Receive                                                |  Transmit
  ///   face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
  ///   lo: 45929941  269112    0    0    0     0          0         0 45929941  269112    0    0    0     0       0          0
  ///   eth0: 48481023  505772    0    0    0     0          0         0 36002262  202307    0    0    0     0       0          0
  /// 1635752901
  void _getNetSpeed(ServerPrivateInfo spi, String raw) {
    final info = _servers.firstWhere((e) => e.info == spi);
    final split = raw.split('\n');
    final deviceCount = split.length - 3;
    if (deviceCount < 1) return;
    final time = int.parse(split[split.length - 1]);
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
    info.status.netSpeed = info.status.netSpeed.update(results);
  }

  void _getSysVer(ServerPrivateInfo spi, String raw) {
    final info = _servers.firstWhere((e) => e.info == spi);
    final s = raw.split('=');
    if (s.length == 2) {
      info.status.sysVer = s[1].replaceAll('"', '').replaceFirst('\n', '');
    }
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

  void _getCPU(ServerPrivateInfo spi, String raw, String temp) {
    final info = _servers.firstWhere((e) => e.info == spi);
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
    if (cpus.isNotEmpty) {
      info.status.cpu2Status =
          info.status.cpu2Status.update(cpus, _getCPUTemp(temp));
    }
  }

  void _getUpTime(ServerPrivateInfo spi, String raw) {
    _servers.firstWhere((e) => e.info == spi).status.uptime =
        raw.split('up ')[1].split(', ')[0];
  }

  void _getTcp(ServerPrivateInfo spi, String raw) {
    final info = _servers.firstWhere((e) => e.info == spi);
    final lines = raw.split('\n');
    final idx = lines.lastWhere((element) => element.startsWith('Tcp:'),
        orElse: () => '');
    if (idx != '') {
      final vals = idx.split(RegExp(r'\s{1,}'));
      info.status.tcp = TcpStatus(vals[5].i, vals[6].i, vals[7].i, vals[8].i);
    }
  }

  void _getDisk(ServerPrivateInfo spi, String raw) {
    final info = _servers.firstWhere((e) => e.info == spi);
    final list = <DiskInfo>[];
    final items = raw.split('\n');
    for (var item in items) {
      if (items.indexOf(item) == 0 || item.isEmpty) {
        continue;
      }
      final vals = item.split(RegExp(r'\s{1,}'));
      list.add(DiskInfo(vals[0], vals[5],
          int.parse(vals[4].replaceFirst('%', '')), vals[2], vals[1], vals[3]));
    }
    info.status.disk = list;
  }

  void _getMem(ServerPrivateInfo spi, String raw) {
    final info = _servers.firstWhere((e) => e.info == spi);
    for (var item in raw.split('\n')) {
      if (item.contains('Mem:')) {
        final split = item.replaceFirst('Mem:', '').split(' ');
        split.removeWhere((e) => e == '');
        final memList = split.map((e) => int.parse(e)).toList();
        info.status.memory = Memory(
            total: memList[0],
            used: memList[1],
            free: memList[2],
            shared: memList[3],
            cache: memList[4],
            avail: memList[5]);
      }
    }
  }

  Future<String?> runSnippet(ServerPrivateInfo spi, Snippet snippet) async {
    final result = await _servers
        .firstWhere((element) => element.info == spi)
        .client!
        .run(snippet.script);
    return utf8.decode(result);
  }
}
