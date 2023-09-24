import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:toolbox/core/utils/platform/path.dart';
import 'package:toolbox/data/model/app/shell_func.dart';
import 'package:toolbox/data/model/server/system.dart';
import 'package:toolbox/data/model/sftp/req.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/path.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/store.dart';

import '../../core/extension/order.dart';
import '../../core/extension/uint8list.dart';
import '../../core/utils/server.dart';
import '../model/server/server.dart';
import '../model/server/server_private_info.dart';
import '../model/server/server_status_update_req.dart';
import '../model/server/snippet.dart';
import '../model/server/try_limiter.dart';
import '../res/status.dart';

typedef ServersMap = Map<String, Server>;

class ServerProvider extends ChangeNotifier {
  final ServersMap _servers = {};
  Iterable<Server> get servers => _servers.values;
  final Order<String> _serverOrder = [];
  Order<String> get serverOrder => _serverOrder;
  final List<String> _tags = [];
  List<String> get tags => _tags;

  final _limiter = TryLimiter();

  Timer? _timer;

  Future<void> loadLocalData() async {
    // Issue #147
    // Clear all servers because of restarting app will cause duplicate servers
    _servers.clear();
    _serverOrder.clear();

    final spis = Stores.server.fetch();
    for (int idx = 0; idx < spis.length; idx++) {
      _servers[spis[idx].id] = genServer(spis[idx]);
    }
    final serverOrder_ = Stores.setting.serverOrder.fetch();
    if (serverOrder_.isNotEmpty) {
      spis.reorder(
        order: serverOrder_,
        finder: (n, id) => n.id == id,
      );
      _serverOrder.addAll(spis.map((e) => e.id));
    } else {
      _serverOrder.addAll(_servers.keys);
    }
    // Must use [equals] to compare [Order] here.
    if (!_serverOrder.equals(serverOrder_)) {
      Stores.setting.serverOrder.put(_serverOrder);
    }
    _updateTags();
    notifyListeners();
  }

  /// Get a [Server] by [spi] or [id].
  ///
  /// Priority: [spi] > [id]
  Server? pick({ServerPrivateInfo? spi, String? id}) {
    if (spi != null) {
      return _servers[spi.id];
    }
    if (id != null) {
      return _servers[id];
    }
    return null;
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
      Stores.server.update(s.spi, s.spi);
    }
    _updateTags();
  }

  Server genServer(ServerPrivateInfo spi) {
    return Server(spi, InitStatus.status, null, ServerState.disconnected);
  }

  /// if [spi] is specificed then only refresh this server
  /// [onlyFailed] only refresh failed servers
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

      /// If [spi.autoConnect] is false and server is disconnected, then skip.
      ///
      /// If [spi.autoConnect] is false and server is connected, then refresh.
      /// If no this, the server will only refresh once by clicking refresh button.
      ///
      /// If [spi.autoConnect] is true, then refresh.
      if (!(s.spi.autoConnect ?? true) && s.state == ServerState.disconnected) {
        return;
      }
      return await _getData(s.spi);
    }));
  }

  Future<void> startAutoRefresh() async {
    final duration = Stores.setting.serverStatusUpdateInterval.fetch();
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
    Stores.server.put(spi);
    _serverOrder.add(spi.id);
    Stores.setting.serverOrder.put(_serverOrder);
    _updateTags();
    refreshData(spi: spi);
  }

  void delServer(String id) {
    _servers.remove(id);
    _serverOrder.remove(id);
    Stores.setting.serverOrder.put(_serverOrder);
    _updateTags();
    notifyListeners();
    Stores.server.delete(id);
  }

  void deleteAll() {
    _servers.clear();
    _serverOrder.clear();
    Stores.setting.serverOrder.put(_serverOrder);
    _updateTags();
    notifyListeners();
    Stores.server.deleteAll();
  }

  Future<void> updateServer(
    ServerPrivateInfo old,
    ServerPrivateInfo newSpi,
  ) async {
    if (old != newSpi) {
      Stores.server.update(old, newSpi);
      _servers[old.id]?.spi = newSpi;

      if (newSpi.id != old.id) {
        _servers[newSpi.id] = _servers[old.id]!;
        _servers[newSpi.id]?.spi = newSpi;
        _servers.remove(old.id);
        _serverOrder.update(old.id, newSpi.id);
        Stores.setting.serverOrder.put(_serverOrder);
      }

      // Only reconnect if neccessary
      if (newSpi.shouldReconnect(old)) {
        _servers[newSpi.id]?.client = await genClient(
          newSpi,
          timeout: Stores.setting.timeoutD,
        );
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

    if (s.state.shouldConnect || (s.client?.isClosed ?? true)) {
      _setServerState(s, ServerState.connecting);

      final time1 = DateTime.now();

      try {
        s.client = await genClient(
          spi,
          timeout: Stores.setting.timeoutD,
        );
      } catch (e) {
        _limiter.inc(sid);
        s.status.failedInfo = e.toString();
        _setServerState(s, ServerState.failed);

        /// In order to keep privacy, print [spi.name] instead of [spi.id]
        Loggers.app.warning('Connect to ${spi.name} failed', e);
        return;
      }

      final time2 = DateTime.now();
      final spentTime = time2.difference(time1).inMilliseconds;
      Loggers.app.info('Connected to ${spi.name} in $spentTime ms.');

      _setServerState(s, ServerState.connected);

      try {
        final writeResult = await s.client?.run(installShellCmd).string;
        if (writeResult == null || writeResult.isNotEmpty) {
          throw Exception('$writeResult');
        }
      } catch (e) {
        var sftpFailed = false;
        try {
          Loggers.app.warning('Using SFTP to write script to ${spi.name}');
          final localPath = joinPath(await Paths.doc, 'install.sh');
          final file = File(localPath);
          file.writeAsString(ShellFunc.allScript);
          final sftp = Providers.sftp;
          final completer = Completer();
          sftp.add(
            SftpReq(spi, installShellPath, localPath, SftpReqType.upload),
            completer: completer,
          );
          await completer.future;
          await file.delete();
        } catch (_) {
          sftpFailed = true;
        }
        if (sftpFailed) {
          _limiter.inc(sid);
          s.status.failedInfo = e.toString();
          _setServerState(s, ServerState.failed);
          Loggers.app.warning('Write script to ${spi.name} failed', e);
          return;
        }
      }
    }

    /// Keep [finished] state, or the UI will be refreshed to [loading] state
    /// instead of the 'Temp & Uptime'.
    if (s.state != ServerState.finished) {
      _setServerState(s, ServerState.loading);
    }

    final raw = await s.client?.run(ShellFunc.status.exec).string;
    final segments = raw?.split(seperator).map((e) => e.trim()).toList();
    if (raw == null || raw.isEmpty || segments == null || segments.isEmpty) {
      _limiter.inc(sid);
      s.status.failedInfo = 'Seperate segments failed, raw:\n$raw';
      _setServerState(s, ServerState.failed);
      return;
    }

    final systemType = SystemType.parse(segments[0]);
    if (systemType == null || !systemType.isSegmentsLenMatch(segments.length)) {
      _limiter.inc(sid);
      s.status.failedInfo = 'Segments not match: ${segments.length}';
      _setServerState(s, ServerState.failed);
      return;
    }
    s.status.system = systemType;

    try {
      final req = ServerStatusUpdateReq(
        ss: s.status,
        segments: segments,
        system: systemType,
      );
      s.status = await compute(getStatus, req);
    } catch (e, trace) {
      _limiter.inc(sid);
      s.status.failedInfo = 'Parse failed: $e\n\n$raw';
      _setServerState(s, ServerState.failed);
      Loggers.parse.warning('Server status', e, trace);
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

  Future<List<String?>> runSnippetsMulti(
    List<String> ids,
    List<Snippet> snippets,
  ) async {
    return await Future.wait(ids.map((id) async => runSnippets(id, snippets)));
  }
}
