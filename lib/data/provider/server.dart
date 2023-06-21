import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../core/extension/order.dart';
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
  final StringOrder _serverOrder = [];
  StringOrder get serverOrder => _serverOrder;
  final List<String> _tags = [];
  List<String> get tags => _tags;

  final _limiter = TryLimiter();

  Timer? _timer;

  final _logger = Logger('SERVER');

  final _serverStore = locator<ServerStore>();
  final _settingStore = locator<SettingStore>();

  Future<void> loadLocalData() async {
    setBusyState(true);
    final infos = _serverStore.fetch();
    for (final info in infos) {
      _servers[info.id] = genServer(info);
    }
    final serverOrder_ = _settingStore.serverOrder.fetch();
    if (serverOrder_ != null) {
      _serverOrder.addAll(serverOrder_.toSet());
      if (_serverOrder.length != infos.length) {
        final missed = infos
            .where(
              (e) => !_serverOrder.contains(e.id),
            )
            .map((e) => e.id);
        _serverOrder.addAll(missed);
      }
    } else {
      _serverOrder.addAll(_servers.keys);
    }
    final surplus = _serverOrder.where(
      (e) => !_servers.containsKey(e),
    );
    _serverOrder.removeWhere((element) => surplus.contains(element));
    _settingStore.serverOrder.put(_serverOrder);
    _updateTags();
    setBusyState(false);
    notifyListeners();
  }

  void _updateTags() {
    _tags.clear();
    for (final s in _servers.values) {
      if (s.spi.tags == null) continue;
      for (final t in s.spi.tags!) {
        if (!_tags.contains(t)) {
          _tags.add(t);
        }
      }
    }
    _tags.sort();
    notifyListeners();
  }

  void renameTag(String old, String new_) {
    for (final s in _servers.values) {
      if (s.spi.tags == null) continue;
      for (var i = 0; i < s.spi.tags!.length; i++) {
        if (s.spi.tags![i] == old) {
          s.spi.tags![i] = new_;
        }
      }
      _serverStore.update(s.spi, s.spi);
    }
    _updateTags();
  }

  Server genServer(ServerPrivateInfo spi) {
    return Server(spi, initStatus, null, ServerState.disconnected);
  }

  Future<void> refreshData({
    ServerPrivateInfo? spi,
    bool onlyFailed = false,
  }) async {
    if (spi != null) {
      await _getData(spi);
      return;
    }
    await Future.wait(_servers.values.map((s) async {
      if (onlyFailed) {
        if (s.state != ServerState.failed) return;
        _limiter.resetTryTimes(s.spi.id);
      }
      return await _getData(s.spi);
    }));
  }

  Future<void> startAutoRefresh() async {
    final duration = _settingStore.serverStatusUpdateInterval.fetch()!;
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
    _serverStore.put(spi);
    _serverOrder.add(spi.id);
    _settingStore.serverOrder.put(_serverOrder);
    _updateTags();
    refreshData(spi: spi);
  }

  void delServer(String id) {
    _servers.remove(id);
    _serverOrder.remove(id);
    _settingStore.serverOrder.put(_serverOrder);
    _updateTags();
    notifyListeners();
    _serverStore.delete(id);
  }

  Future<void> updateServer(
    ServerPrivateInfo old,
    ServerPrivateInfo newSpi,
  ) async {
    if (old != newSpi) {
      _serverStore.update(old, newSpi);
      _servers[old.id]?.spi = newSpi;

      if (newSpi.id != old.id) {
        _servers[newSpi.id] = _servers[old.id]!;
        _servers[newSpi.id]?.spi = newSpi;
        _servers.remove(old.id);
        _serverOrder.update(old.id, newSpi.id);
        _settingStore.serverOrder.put(_serverOrder);
      }

      // Only reconnect if neccessary
      if (newSpi.shouldReconnect(old)) {
        _servers[newSpi.id]?.client = await genClient(newSpi);
        refreshData(spi: newSpi);
      }

      // Only update if [spi.tags] changed
      _updateTags();
    }
  }

  Future<void> _getData(ServerPrivateInfo spi) async {
    final sid = spi.id;
    final s = _servers[sid];
    if (s == null) return;

    var raw = '';
    var segments = <String>[];

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
      raw =
          await s.client!.run("sh $shellPath -${shellFuncStatus.flag}").string;
      segments = raw.split(seperator).map((e) => e.trim()).toList();
      if (raw.isEmpty || segments.length != CmdType.values.length) {
        s.state = ServerState.failed;
        if (s.status.failedInfo?.isEmpty ?? true) {
          s.status.failedInfo = 'Seperate segments failed, raw:\n$raw';
        }
        return;
      }
    } catch (e) {
      s.state = ServerState.failed;
      s.status.failedInfo = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }

    try {
      final req = ServerStatusUpdateReq(s.status, segments);
      s.status = await compute(getStatus, req);
      // Comment for debug
      // s.status = await getStatus(req);
    } catch (e) {
      s.state = ServerState.failed;
      s.status.failedInfo = 'Parse failed: $e\n\n$raw';
      rethrow;
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
