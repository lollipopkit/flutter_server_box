import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:toolbox/data/res/misc.dart';

import '../../core/extension/uint8list.dart';
import '../../core/provider_base.dart';
import '../../core/utils/server.dart';
import '../../locator.dart';
import '../model/server/cpu_status.dart';
import '../model/server/disk_info.dart';
import '../model/server/memory.dart';
import '../model/server/net_speed.dart';
import '../model/server/server.dart';
import '../model/server/server_private_info.dart';
import '../model/server/snippet.dart';
import '../model/server/tcp_status.dart';
import '../res/server_cmd.dart';
import '../res/status.dart';
import '../store/server.dart';
import '../store/setting.dart';

class ServerProvider extends BusyProvider {
  List<Server> _servers = [];
  List<Server> get servers => _servers;
  final _TryLimiter _limiter = _TryLimiter();

  Timer? _timer;

  final logger = Logger('SERVER');

  Future<void> loadLocalData() async {
    setBusyState(true);
    final infos = locator<ServerStore>().fetch();
    _servers = List.generate(infos.length, (index) => genServer(infos[index]));
    setBusyState(false);
    notifyListeners();
  }

  Server genServer(ServerPrivateInfo spi) {
    return Server(spi, initStatus, null, ServerConnectionState.disconnected);
  }

  Future<void> refreshData({ServerPrivateInfo? spi}) async {
    if (spi != null) {
      await _getData(spi);
      return;
    }
    await Future.wait(_servers.map((s) async {
      await _getData(s.spi);
    }));
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
      _servers[i].cs = ServerConnectionState.disconnected;
    }
  }

  void closeServer({ServerPrivateInfo? spi}) {
    if (spi == null) {
      for (var i = 0; i < _servers.length; i++) {
        _servers[i].client?.close();
        _servers[i].client = null;
      }
      return;
    }
    final idx = _servers.indexWhere((e) => e.spi == spi);
    if (idx < 0) {
      throw RangeError.index(idx, _servers);
    }
    _servers[idx].client?.close();
  }

  void addServer(ServerPrivateInfo spi) {
    _servers.add(genServer(spi));
    locator<ServerStore>().put(spi);
    notifyListeners();
    refreshData(spi: spi);
  }

  void delServer(ServerPrivateInfo info) {
    final idx = _servers.indexWhere((s) => s.spi == info);
    if (idx == -1) return;
    _servers[idx].client?.close();
    _servers.removeAt(idx);
    notifyListeners();
    locator<ServerStore>().delete(info);
  }

  Future<void> updateServer(
      ServerPrivateInfo old, ServerPrivateInfo newSpi) async {
    final idx = _servers.indexWhere((e) => e.spi == old);
    if (idx < 0) {
      throw RangeError.index(idx, _servers);
    }
    _servers[idx].spi = newSpi;
    locator<ServerStore>().update(old, newSpi);
    _servers[idx].client = await genClient(newSpi);
    notifyListeners();
    refreshData(spi: newSpi);
  }

  Future<void> _getData(ServerPrivateInfo spi) async {
    final s = _servers.firstWhere((element) => element.spi == spi);
    final state = s.cs;
    if (state == ServerConnectionState.failed ||
        state == ServerConnectionState.disconnected) {
      if (!_limiter.shouldTry(spi.id)) {
        s.cs = ServerConnectionState.failed;
        notifyListeners();
        return;
      }
      s.cs = ServerConnectionState.connecting;
      notifyListeners();
      final time1 = DateTime.now();
      try {
        s.client = await genClient(spi);
        final time2 = DateTime.now();
        logger.info(
            'Connected to [${spi.name}] in [${time2.difference(time1).toString()}].');
        s.cs = ServerConnectionState.connected;
        final writeResult = await s.client!
            .run("echo '$shellCmd' > $shellPath && chmod +x $shellPath")
            .string;
        if (writeResult.isNotEmpty) {
          throw Exception(writeResult);
        }
        _limiter.resetTryTimes(spi.id);
      } catch (e) {
        s.cs = ServerConnectionState.failed;
        s.status.failedInfo = '$e ## ';
        logger.warning(e);
      } finally {
        notifyListeners();
      }
    }

    // if client is null, return
    if (s.client == null) return;
    final raw = await s.client!.run("sh $shellPath").string;
    final segments = raw.split(seperator).map((e) => e.trim()).toList();
    if (raw.isEmpty || segments.length == 1) {
      s.cs = ServerConnectionState.failed;
      if (s.status.failedInfo == null || s.status.failedInfo!.isEmpty) {
        s.status.failedInfo = 'No data received';
      }
      notifyListeners();
      return;
    }
    segments.removeAt(0);

    try {
      _getCPU(spi, segments[2], segments[7], segments[8]);
      _getMem(spi, segments[6]);
      _getSysVer(spi, segments[1]);
      _getUpTime(spi, segments[3]);
      _getDisk(spi, segments[5]);
      _getTcp(spi, segments[4]);
      _getNetSpeed(spi, segments[0]);
    } catch (e) {
      s.cs = ServerConnectionState.failed;
      s.status.failedInfo = e.toString();
      logger.warning(e);
      rethrow;
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
  Future<void> _getNetSpeed(ServerPrivateInfo spi, String raw) async {
    final info = _servers.firstWhere((e) => e.spi == spi);
    info.status.netSpeed.update(await compute(parseNetSpeed, raw));
  }

  void _getSysVer(ServerPrivateInfo spi, String raw) {
    final info = _servers.firstWhere((e) => e.spi == spi);
    final s = raw.split('=');
    if (s.length == 2) {
      info.status.sysVer = s[1].replaceAll('"', '').replaceFirst('\n', '');
    }
  }

  Future<void> _getCPU(ServerPrivateInfo spi, String raw, String tempType,
      String tempValue) async {
    final info = _servers.firstWhere((e) => e.spi == spi);
    final cpus = await compute(parseCPU, raw);

    if (cpus.isNotEmpty) {
      info.status.cpu
          .update(cpus, await compute(parseCPUTemp, [tempType, tempValue]));
    }
  }

  void _getUpTime(ServerPrivateInfo spi, String raw) {
    _servers.firstWhere((e) => e.spi == spi).status.uptime =
        raw.split('up ')[1].split(', ')[0];
  }

  Future<void> _getTcp(ServerPrivateInfo spi, String raw) async {
    final info = _servers.firstWhere((e) => e.spi == spi);
    final status = await compute(parseTcp, raw);
    if (status != null) {
      info.status.tcp = status;
    }
  }

  void _getDisk(ServerPrivateInfo spi, String raw) {
    final info = _servers.firstWhere((e) => e.spi == spi);
    final list = <DiskInfo>[];
    final items = raw.split('\n');
    for (var item in items) {
      if (items.indexOf(item) == 0 || item.isEmpty) {
        continue;
      }
      final vals = item.split(numReg);
      list.add(DiskInfo(vals[0], vals[5],
          int.parse(vals[4].replaceFirst('%', '')), vals[2], vals[1], vals[3]));
    }
    info.status.disk = list;
  }

  Future<void> _getMem(ServerPrivateInfo spi, String raw) async {
    final info = _servers.firstWhere((e) => e.spi == spi);
    final mem = await compute(parseMem, raw);
    info.status.mem = mem;
  }

  Future<String?> runSnippet(String id, Snippet snippet) async {
    final client =
        _servers.firstWhere((element) => element.spi.id == id).client;
    if (client == null) {
      return null;
    }
    return await client.run(snippet.script).string;
  }
}

class _TryLimiter {
  final Map<String, int> _triedTimes = {};

  bool shouldTry(String id) {
    final times = _triedTimes[id] ?? 0;
    if (times >= serverMaxTryTimes) {
      return false;
    }
    _triedTimes[id] = times + 1;
    return true;
  }

  void resetTryTimes(String id) {
    _triedTimes[id] = 0;
  }
}