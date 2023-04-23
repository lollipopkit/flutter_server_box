import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../core/build_mode.dart';
import '../../core/extension/uint8list.dart';
import '../../core/provider_base.dart';
import '../../core/utils/server.dart';
import '../../locator.dart';
import '../model/server/server.dart';
import '../model/server/server_private_info.dart';
import '../model/server/server_status_update_req.dart';
import '../model/server/snippet.dart';
import '../model/server/try_limiter.dart';
import '../res/server_cmd.dart';
import '../res/status.dart';
import '../store/server.dart';
import '../store/setting.dart';

typedef ServersMap = Map<String, Server>;

class ServerProvider extends BusyProvider {
  final ServersMap _servers = {};
  ServersMap get servers => _servers;
  final _limiter = TryLimiter();

  Timer? _timer;

  final _logger = Logger('SERVER');

  Future<void> loadLocalData() async {
    setBusyState(true);
    final infos = locator<ServerStore>().fetch();
    for (final info in infos) {
      _servers[info.id] = genServer(info);
    }
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
    final futures = _servers.values.map((s) async {
      if (onlyFailed) {
        if (s.state != ServerState.failed) return;
        _limiter.resetTryTimes(s.spi.id);
      }
      return await _getData(s.spi);
    });
    await Future.wait(futures);
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

  bool get isAutoRefreshOn => _timer != null;

  void setDisconnected() {
    for (final s in _servers.values) {
      s.state = ServerState.disconnected;
    }
    _limiter.clear();
    notifyListeners();
  }

  void closeServer({String? id}) {
    if (id == null) {
      for (final s in _servers.values) {
        _closeOneServer(s.spi.id);
      }
      return;
    }
    _closeOneServer(id);
  }

  void _closeOneServer(String id) {
    _servers[id]?.client?.close();
    _servers[id]?.client = null;
  }

  void addServer(ServerPrivateInfo spi) {
    _servers[spi.id] = genServer(spi);
    notifyListeners();
    locator<ServerStore>().put(spi);
    refreshData(spi: spi);
  }

  void delServer(String id) {
    _servers.remove(id);
    notifyListeners();
    locator<ServerStore>().delete(id);
  }

  Future<void> updateServer(
      ServerPrivateInfo old, ServerPrivateInfo newSpi) async {
    _servers.remove(old.id);
    locator<ServerStore>().update(old, newSpi);
    _servers[newSpi.id] = genServer(newSpi);
    _servers[newSpi.id]?.client = await genClient(newSpi);
    notifyListeners();
    refreshData(spi: newSpi);
  }

  Future<void> _getData(ServerPrivateInfo spi) async {
    final sid = spi.id;
    final s = _servers[sid];
    if (s == null) return;

    try {
      final state = s.state;
      if (state.shouldConnect) {
        if (!_limiter.shouldTry(sid)) {
          s.state = ServerState.failed;
          notifyListeners();
          return;
        }
        s.state = ServerState.connecting;
        notifyListeners();

        // try to connect
        final time1 = DateTime.now();
        s.client = await genClient(spi);
        final time2 = DateTime.now();
        final spentTime = time2.difference(time1).inMilliseconds;
        _logger.info('Connected to [$sid] in $spentTime ms.');

        // after connected
        s.state = ServerState.connected;
        notifyListeners();
        // write script to server
        final writeResult = await s.client!.run(installShellCmd).string;

        // if write failed
        if (writeResult.isNotEmpty) {
          throw Exception(writeResult);
        }
        // reset try times if connected successfully
        _limiter.resetTryTimes(sid);
      }

      if (s.client == null) return;
      // run script to get server status
      final raw = await s.client!.run("sh $shellPath").string;
      final segments = raw.split(seperator).map((e) => e.trim()).toList();
      if (raw.isEmpty || segments.length == 1) {
        s.state = ServerState.failed;
        if (s.status.failedInfo == null || s.status.failedInfo!.isEmpty) {
          s.status.failedInfo = 'Seperate segments failed, raw:\n$raw';
        }
        return;
      }
      // remove first empty segment
      // for `export xxx` in shell script
      segments.removeAt(0);

      final req = ServerStatusUpdateReq(s.status, segments);
      s.status = await compute(getStatus, req);
    } catch (e) {
      s.state = ServerState.failed;
      s.status.failedInfo = e.toString();
      _logger.warning(e);
      if (BuildMode.isDebug) {
        rethrow;
      }
    } finally {
      notifyListeners();
    }
  }

  Future<String?> runSnippet(String id, Snippet snippet) async {
    final client = _servers[id]?.client;
    if (client == null) {
      return null;
    }
    return await client.run(snippet.script).string;
  }
}
