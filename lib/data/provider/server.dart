import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:toolbox/data/model/app/shell_func.dart';

import '../../core/extension/order.dart';
import '../../core/extension/uint8list.dart';
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

class ServerProvider extends ChangeNotifier {
  final ServersMap _servers = {};
  ServersMap get servers => _servers;
  final Order<String> _serverOrder = [];
  Order<String> get serverOrder => _serverOrder;
  final List<String> _tags = [];
  List<String> get tags => _tags;

  final _limiter = TryLimiter();

  Timer? _timer;

  final _logger = Logger('SERVER');

  final _serverStore = locator<ServerStore>();
  final _settingStore = locator<SettingStore>();

  Future<void> loadLocalData() async {
    final spis = _serverStore.fetch();
    for (final spi in spis) {
      _servers[spi.id] = genServer(spi);
    }
    final serverOrder_ = _settingStore.serverOrder.fetch();
    if (serverOrder_ != null) {
      spis.reorder(
        order: serverOrder_,
        finder: (n, id) => n.id == id,
      );
      _serverOrder.addAll(spis.map((e) => e.id));
    } else {
      _serverOrder.addAll(_servers.keys);
    }
    _settingStore.serverOrder.put(_serverOrder);
    _updateTags();
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
        _limiter.reset(s.spi.id);
      }
      return await _getData(s.spi);
    }));
  }

  Future<void> startAutoRefresh() async {
    final duration = _settingStore.serverStatusUpdateInterval.fetch()!;
    stopAutoRefresh();
    if (duration == 0) return;
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

  void deleteAll() {
    _servers.clear();
    _serverOrder.clear();
    _settingStore.serverOrder.put(_serverOrder);
    _updateTags();
    notifyListeners();
    _serverStore.deleteAll();
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

  void _setServerState(Server s, ServerState ss) {
    s.state = ss;
    notifyListeners();
  }

  Future<void> _getData(ServerPrivateInfo spi) async {
    final sid = spi.id;
    final s = _servers[sid];

    if (s == null) return;

    if (!_limiter.canTry(sid)) {
      if (s.state != ServerState.failed) {
        _setServerState(s, ServerState.failed);
      }
      return;
    }

    if (s.state.shouldConnect) {
      _setServerState(s, ServerState.connecting);

      final time1 = DateTime.now();

      try {
        s.client = await genClient(spi);
      } catch (e) {
        _limiter.inc(sid);
        s.status.failedInfo = e.toString();
        _setServerState(s, ServerState.failed);
        _logger.warning('Connect to $sid failed', e);
        return;
      }

      final time2 = DateTime.now();
      final spentTime = time2.difference(time1).inMilliseconds;
      _logger.info('Connected to $sid in $spentTime ms.');

      _setServerState(s, ServerState.connected);

      try {
        final writeResult = await s.client?.run(installShellCmd).string;
        if (writeResult == null || writeResult.isNotEmpty) {
          _limiter.inc(sid);
          s.status.failedInfo = writeResult;
          _setServerState(s, ServerState.failed);
          return;
        }
      } catch (e) {
        _limiter.inc(sid);
        s.status.failedInfo = e.toString();
        _setServerState(s, ServerState.failed);
        _logger.warning('Write script to $sid failed', e);
        return;
      }
    }

    if (s.client == null) return;

    if (s.state != ServerState.finished) {
      _setServerState(s, ServerState.loading);
    }

    final raw = await s.client?.run(AppShellFuncType.status.exec).string;
    final segments = raw?.split(seperator).map((e) => e.trim()).toList();
    if (raw == null ||
        raw.isEmpty ||
        segments == null ||
        segments.length != StatusCmdType.values.length) {
      _limiter.inc(sid);
      s.status.failedInfo = 'Seperate segments failed, raw:\n$raw';
      _setServerState(s, ServerState.failed);
      return;
    }

    try {
      final req = ServerStatusUpdateReq(s.status, segments);
      s.status = await compute(getStatus, req);
    } catch (e, trace) {
      _limiter.inc(sid);
      s.status.failedInfo = 'Parse failed: $e\n\n$raw';
      _setServerState(s, ServerState.failed);
      _logger.warning('Parse failed', e, trace);
      return;
    }

    if (s.state != ServerState.finished) {
      _setServerState(s, ServerState.finished);
    } else {
      notifyListeners();
    }
    // reset try times only after prepared successfully
    _limiter.reset(sid);
  }

  Future<String?> runSnippets(String id, List<Snippet> snippets) async {
    final client = _servers[id]?.client;
    if (client == null) {
      return null;
    }
    return await client.run(snippets.map((e) => e.script).join('&&')).string;
  }

  Future<List<String?>> runSnippetsOnMulti(
    List<String> ids,
    List<Snippet> snippets,
  ) async {
    return await Future.wait(ids.map((id) async => runSnippets(id, snippets)));
  }
}
