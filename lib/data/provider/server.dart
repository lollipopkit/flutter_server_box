import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

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

  final _logger = Logger('SERVER');

  Future<void> loadLocalData() async {
    setBusyState(true);
    final infos = locator<ServerStore>().fetch();
    _servers = List.generate(infos.length, (index) => genServer(infos[index]));
    setBusyState(false);
    notifyListeners();
  }

  Server genServer(ServerPrivateInfo spi) {
    return Server(spi, initStatus, null, ServerState.disconnected);
  }

  Future<void> refreshData(
      {ServerPrivateInfo? spi, bool onlyFailed = false}) async {
    if (spi != null) {
      await _getData(spi);
      return;
    }
    await Future.wait(_servers.map((s) async {
      if (onlyFailed) {
        if (s.cs != ServerState.failed) return;
        _limiter.resetTryTimes(s.spi.id);
      }
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
      _servers[i].cs = ServerState.disconnected;
    }
    _limiter.clear();
    notifyListeners();
  }

  void closeServer({ServerPrivateInfo? spi}) {
    if (spi == null) {
      for (var i = 0; i < _servers.length; i++) {
        _servers[i].client?.close();
        _servers[i].client = null;
      }
      return;
    }
    final idx = getServerIdx(spi.id);
    _servers[idx].client?.close();
    _servers[idx].client = null;
  }

  void addServer(ServerPrivateInfo spi) {
    _servers.add(genServer(spi));
    notifyListeners();
    locator<ServerStore>().put(spi);
    refreshData(spi: spi);
  }

  void delServer(String id) {
    final idx = getServerIdx(id);
    _servers[idx].client?.close();
    _servers.removeAt(idx);
    notifyListeners();
    locator<ServerStore>().delete(id);
  }

  Future<void> updateServer(
      ServerPrivateInfo old, ServerPrivateInfo newSpi) async {
    final idx = _servers.indexWhere((e) => e.spi.id == old.id);
    if (idx < 0) {
      throw RangeError.index(idx, _servers);
    }
    _servers[idx].spi = newSpi;
    locator<ServerStore>().update(old, newSpi);
    _servers[idx].client = await genClient(newSpi);
    notifyListeners();
    refreshData(spi: newSpi);
  }

  int getServerIdx(String id) {
    final idx = _servers.indexWhere((s) => s.spi.id == id);
    if (idx < 0) {
      throw Exception('Server not found: $id');
    }
    return idx;
  }

  Server getServer(String id) => _servers[getServerIdx(id)];

  Future<void> _getData(ServerPrivateInfo spi) async {
    final sid = spi.id;
    final s = getServer(sid);
    final state = s.cs;
    if (state.shouldConnect) {
      if (!_limiter.shouldTry(sid)) {
        s.cs = ServerState.failed;
        notifyListeners();
        return;
      }
      s.cs = ServerState.connecting;
      notifyListeners();

      try {
        // try to connect
        final time1 = DateTime.now();
        s.client = await genClient(spi);
        final time2 = DateTime.now();
        final spentTime = time2.difference(time1).inMilliseconds;
        _logger.info('Connected to [$sid] in $spentTime ms.');

        // after connected
        s.cs = ServerState.connected;
        final writeResult = await s.client!.run(installShellCmd).string;

        // if write failed
        if (writeResult.isNotEmpty) {
          throw Exception(writeResult);
        }
        _limiter.resetTryTimes(sid);
      } catch (e) {
        s.cs = ServerState.failed;
        s.status.failedInfo = '$e';
        _logger.warning(e);
      } finally {
        notifyListeners();
      }
    }

    if (s.client == null) return;
    // run script to get server status
    final raw = await s.client!.run("sh $shellPath").string;
    final segments = raw.split(seperator).map((e) => e.trim()).toList();
    if (raw.isEmpty || segments.length == 1) {
      s.cs = ServerState.failed;
      if (s.status.failedInfo == null || s.status.failedInfo!.isEmpty) {
        s.status.failedInfo = 'Seperate segments failed, raw:\n$raw';
      }
      notifyListeners();
      return;
    }
    // remove first empty segment
    segments.removeAt(0);

    try {
      _getCPU(sid, segments[2], segments[7], segments[8]);
      _getMem(sid, segments[6]);
      _getSysVer(sid, segments[1]);
      _getUpTime(sid, segments[3]);
      _getDisk(sid, segments[5]);
      _getTcp(sid, segments[4]);
      _getNetSpeed(sid, segments[0]);
    } catch (e) {
      s.cs = ServerState.failed;
      s.status.failedInfo = e.toString();
      _logger.warning(e);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _getNetSpeed(String id, String raw) async {
    final net = await compute(parseNetSpeed, raw);
    getServer(id).status.netSpeed.update(net);
  }

  void _getSysVer(String id, String raw) {
    final s = raw.split('=');
    if (s.length == 2) {
      final ver = s[1].replaceAll('"', '').replaceFirst('\n', '');
      getServer(id).status.sysVer = ver;
    }
  }

  Future<void> _getCPU(
      String id, String raw, String tempType, String tempValue) async {
    final cpus = await compute(parseCPU, raw);
    final temp = await compute(parseCPUTemp, [tempType, tempValue]);

    if (cpus.isNotEmpty) {
      getServer(id).status.cpu.update(cpus, temp);
    }
  }

  void _getUpTime(String id, String raw) {
    getServer(id).status.uptime = raw.split('up ')[1].split(', ')[0];
  }

  Future<void> _getTcp(String id, String raw) async {
    final status = await compute(parseTcp, raw);
    if (status != null) {
      getServer(id).status.tcp = status;
    }
  }

  Future<void> _getDisk(String id, String raw) async {
    getServer(id).status.disk = await compute(parseDisk, raw);
  }

  Future<void> _getMem(String id, String raw) async {
    final s = getServer(id);
    s.status.mem = await compute(parseMem, raw);
    s.status.swap = await compute(parseSwap, raw);
  }

  Future<String?> runSnippet(String id, Snippet snippet) async {
    final client = getServer(id).client;
    if (client == null) {
      return null;
    }
    return await client.run(snippet.script).string;
  }
}

class _TryLimiter {
  final Map<String, int> _triedTimes = {};

  bool shouldTry(String id) {
    final maxCount = locator<SettingStore>().maxRetryCount.fetch()!;
    if (maxCount <= 0) {
      return true;
    }
    final times = _triedTimes[id] ?? 0;
    if (times >= maxCount) {
      return false;
    }
    _triedTimes[id] = times + 1;
    return true;
  }

  void resetTryTimes(String id) {
    _triedTimes[id] = 0;
  }

  void clear() {
    _triedTimes.clear();
  }
}
