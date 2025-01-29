import 'dart:async';
// import 'dart:io';

import 'package:computer/computer.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/core/utils/ssh_auth.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/shell_func.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/res/store.dart';

import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/server_status_update_req.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/res/status.dart';

class ServerProvider extends Provider {
  const ServerProvider._();
  static const instance = ServerProvider._();

  static final Map<String, VNode<Server>> servers = {};
  static final serverOrder = <String>[].vn;
  static final _tags = <String>{}.vn;
  static VNode<Set<String>> get tags => _tags;

  static Timer? _timer;

  static final _manualDisconnectedIds = <String>{};

  @override
  Future<void> load() async {
    super.load();
    // #147
    // Clear all servers because of restarting app will cause duplicate servers
    final oldServers = Map<String, VNode<Server>>.from(servers);
    servers.clear();
    serverOrder.value.clear();

    final spis = Stores.server.fetch();
    for (int idx = 0; idx < spis.length; idx++) {
      final spi = spis[idx];
      final originServer = oldServers[spi.id];
      final newServer = genServer(spi);

      /// #258
      /// If not [shouldReconnect], then keep the old state.
      if (originServer != null &&
          !originServer.value.spi.shouldReconnect(spi)) {
        newServer.conn = originServer.value.conn;
      }
      servers[spi.id] = newServer.vn;
    }
    final serverOrder_ = Stores.setting.serverOrder.fetch();
    if (serverOrder_.isNotEmpty) {
      spis.reorder(
        order: serverOrder_,
        finder: (n, id) => n.id == id,
      );
      serverOrder.value.addAll(spis.map((e) => e.id));
    } else {
      serverOrder.value.addAll(servers.keys);
    }
    // Must use [equals] to compare [Order] here.
    if (!serverOrder.value.equals(serverOrder_)) {
      Stores.setting.serverOrder.put(serverOrder.value);
    }
    _updateTags();
    // Must notify here, or the UI will not be updated.
    serverOrder.notify();
  }

  /// Get a [Server] by [spi] or [id].
  ///
  /// Priority: [spi] > [id]
  static VNode<Server>? pick({Spi? spi, String? id}) {
    if (spi != null) {
      return servers[spi.id];
    }
    if (id != null) {
      return servers[id];
    }
    return null;
  }

  static void _updateTags() {
    final tags = <String>{};
    for (final s in servers.values) {
      final spiTags = s.value.spi.tags;
      if (spiTags == null) continue;
      for (final t in spiTags) {
        tags.add(t);
      }
    }
    _tags.value = tags;
  }

  static Server genServer(Spi spi) {
    return Server(spi, InitStatus.status, ServerConn.disconnected);
  }

  /// if [spi] is specificed then only refresh this server
  /// [onlyFailed] only refresh failed servers
  static Future<void> refresh({
    Spi? spi,
    bool onlyFailed = false,
  }) async {
    if (spi != null) {
      _manualDisconnectedIds.remove(spi.id);
      await _getData(spi);
      return;
    }

    await Future.wait(servers.values.map((val) async {
      final s = val.value;
      if (onlyFailed) {
        if (s.conn != ServerConn.failed) return;
        TryLimiter.reset(s.spi.id);
      }

      if (_manualDisconnectedIds.contains(s.spi.id)) return;

      if (s.conn == ServerConn.disconnected && !s.spi.autoConnect) {
        return;
      }

      return await _getData(s.spi);
    }));
  }

  static Future<void> startAutoRefresh() async {
    var duration = Stores.setting.serverStatusUpdateInterval.fetch();
    stopAutoRefresh();
    if (duration == 0) return;
    if (duration < 0 || duration > 10 || duration == 1) {
      duration = 3;
      Loggers.app.warning('Invalid duration: $duration, use default 3');
    }
    _timer = Timer.periodic(Duration(seconds: duration), (_) async {
      await refresh();
    });
  }

  static void stopAutoRefresh() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  static bool get isAutoRefreshOn => _timer != null;

  static void setDisconnected() {
    for (final s in servers.values) {
      s.value.conn = ServerConn.disconnected;
      s.notify();
    }
    //TryLimiter.clear();
  }

  static void closeServer({String? id}) {
    if (id == null) {
      for (final s in servers.values) {
        _closeOneServer(s.value.spi.id);
      }
      return;
    }
    _closeOneServer(id);
  }

  static void _closeOneServer(String id) {
    final s = servers[id];
    final item = s?.value;
    item?.client?.close();
    item?.client = null;
    item?.conn = ServerConn.disconnected;
    _manualDisconnectedIds.add(id);
    s?.notify();
  }

  static void addServer(Spi spi) {
    servers[spi.id] = genServer(spi).vn;
    Stores.server.put(spi);
    serverOrder.value.add(spi.id);
    serverOrder.notify();
    Stores.setting.serverOrder.put(serverOrder.value);
    _updateTags();
    refresh(spi: spi);
    bakSync.sync(milliDelay: 1000);
  }

  static void delServer(String id) {
    servers.remove(id);
    serverOrder.value.remove(id);
    serverOrder.notify();
    Stores.setting.serverOrder.put(serverOrder.value);
    Stores.server.delete(id);
    _updateTags();
    bakSync.sync(milliDelay: 1000);
  }

  static void deleteAll() {
    servers.clear();
    serverOrder.value.clear();
    serverOrder.notify();
    Stores.setting.serverOrder.put(serverOrder.value);
    Stores.server.deleteAll();
    _updateTags();
    bakSync.sync(milliDelay: 1000);
  }

  static Future<void> updateServer(Spi old, Spi newSpi) async {
    if (old != newSpi) {
      Stores.server.update(old, newSpi);
      servers[old.id]?.value.spi = newSpi;

      if (newSpi.id != old.id) {
        servers[newSpi.id] = servers[old.id]!;
        servers.remove(old.id);
        serverOrder.value.update(old.id, newSpi.id);
        Stores.setting.serverOrder.put(serverOrder.value);
        serverOrder.notify();
      }

      // Only reconnect if neccessary
      if (newSpi.shouldReconnect(old)) {
        // Use [newSpi.id] instead of [old.id] because [old.id] may be changed
        TryLimiter.reset(newSpi.id);
        refresh(spi: newSpi);
      }
    }
    _updateTags();
    bakSync.sync(milliDelay: 1000);
  }

  static void _setServerState(VNode<Server> s, ServerConn ss) {
    s.value.conn = ss;
    s.notify();
  }

  static Future<void> _getData(Spi spi) async {
    final sid = spi.id;
    final s = servers[sid];

    if (s == null) return;

    final sv = s.value;
    if (!TryLimiter.canTry(sid)) {
      if (sv.conn != ServerConn.failed) {
        _setServerState(s, ServerConn.failed);
      }
      return;
    }

    sv.status.err = null;

    if (sv.needGenClient || (sv.client?.isClosed ?? true)) {
      _setServerState(s, ServerConn.connecting);

      final wol = spi.wolCfg;
      if (wol != null) {
        try {
          await wol.wake();
        } catch (e) {
          // TryLimiter.inc(sid);
          // s.status.err = SSHErr(
          //   type: SSHErrType.connect,
          //   message: 'Wake on lan failed: $e',
          // );
          // _setServerState(s, ServerConn.failed);
          Loggers.app.warning('Wake on lan failed', e);
          // return;
        }
      }

      try {
        final time1 = DateTime.now();
        sv.client = await genClient(
          spi,
          timeout: Duration(seconds: Stores.setting.timeout.fetch()),
          onKeyboardInteractive: (_) => KeybordInteractive.defaultHandle(spi),
        );
        final time2 = DateTime.now();
        final spentTime = time2.difference(time1).inMilliseconds;
        if (spi.jumpId == null) {
          Loggers.app.info('Connected to ${spi.name} in $spentTime ms.');
        } else {
          Loggers.app.info('Jump to ${spi.name} in $spentTime ms.');
        }
      } catch (e) {
        TryLimiter.inc(sid);
        sv.status.err = SSHErr(type: SSHErrType.connect, message: e.toString());
        _setServerState(s, ServerConn.failed);

        /// In order to keep privacy, print [spi.name] instead of [spi.id]
        Loggers.app.warning('Connect to ${spi.name} failed', e);
        return;
      }

      _setServerState(s, ServerConn.connected);

      try {
        final (_, writeScriptResult) = await sv.client!.exec(
          (session) async {
            final scriptRaw = ShellFunc.allScript(spi.custom?.cmds).uint8List;
            session.stdin.add(scriptRaw);
            session.stdin.close();
          },
          entry: ShellFunc.getInstallShellCmd(spi.id),
        );
        if (writeScriptResult.isNotEmpty) {
          ShellFunc.switchScriptDir(spi.id);
          throw writeScriptResult;
        }
      } on SSHAuthAbortError catch (e) {
        TryLimiter.inc(sid);
        final err = SSHErr(type: SSHErrType.auth, message: e.toString());
        sv.status.err = err;
        Loggers.app.warning(err);
        _setServerState(s, ServerConn.failed);
        return;
      } on SSHAuthFailError catch (e) {
        TryLimiter.inc(sid);
        final err = SSHErr(type: SSHErrType.auth, message: e.toString());
        sv.status.err = err;
        Loggers.app.warning(err);
        _setServerState(s, ServerConn.failed);
        return;
      } catch (e) {
        // If max try times < 2 and can't write script, this will stop the status getting and etc.
        // TryLimiter.inc(sid);
        final err = SSHErr(type: SSHErrType.writeScript, message: e.toString());
        sv.status.err = err;
        Loggers.app.warning(err);
        _setServerState(s, ServerConn.failed);
      }
    }

    if (sv.conn == ServerConn.connecting) return;

    /// Keep [finished] state, or the UI will be refreshed to [loading] state
    /// instead of the '$Temp | $Uptime'.
    /// eg: '32C | 7 days'
    if (sv.conn != ServerConn.finished) {
      _setServerState(s, ServerConn.loading);
    }

    List<String>? segments;
    String? raw;

    try {
      raw = await sv.client?.run(ShellFunc.status.exec(spi.id)).string;
      segments = raw?.split(ShellFunc.seperator).map((e) => e.trim()).toList();
      if (raw == null || raw.isEmpty || segments == null || segments.isEmpty) {
        if (Stores.setting.keepStatusWhenErr.fetch()) {
          // Keep previous server status when err occurs
          if (sv.conn != ServerConn.failed && sv.status.more.isNotEmpty) {
            return;
          }
        }
        TryLimiter.inc(sid);
        sv.status.err = SSHErr(
          type: SSHErrType.segements,
          message: 'Seperate segments failed, raw:\n$raw',
        );
        _setServerState(s, ServerConn.failed);
        return;
      }
    } catch (e) {
      TryLimiter.inc(sid);
      sv.status.err = SSHErr(type: SSHErrType.getStatus, message: e.toString());
      _setServerState(s, ServerConn.failed);
      Loggers.app.warning('Get status from ${spi.name} failed', e);
      return;
    }

    final systemType = SystemType.parse(segments[0]);
    final customCmdLen = spi.custom?.cmds?.length ?? 0;
    if (!systemType.isSegmentsLenMatch(segments.length - customCmdLen)) {
      TryLimiter.inc(sid);
      if (raw.contains('Could not chdir to home directory /var/services/')) {
        sv.status.err = SSHErr(type: SSHErrType.chdir, message: raw);
        _setServerState(s, ServerConn.failed);
        return;
      }
      final expected = systemType.segmentsLen;
      final actual = segments.length;
      sv.status.err = SSHErr(
        type: SSHErrType.segements,
        message: 'Segments: expect $expected, got $actual, raw:\n\n$raw',
      );
      _setServerState(s, ServerConn.failed);
      return;
    }
    sv.status.system = systemType;

    try {
      final req = ServerStatusUpdateReq(
        ss: sv.status,
        segments: segments,
        system: systemType,
        customCmds: spi.custom?.cmds ?? {},
      );
      sv.status = await Computer.shared.start(
        getStatus,
        req,
        taskName: 'StatusUpdateReq<${sv.id}>',
      );
    } catch (e, trace) {
      TryLimiter.inc(sid);
      sv.status.err = SSHErr(
        type: SSHErrType.getStatus,
        message: 'Parse failed: $e\n\n$raw',
      );
      _setServerState(s, ServerConn.failed);
      Loggers.app.warning('Server status', e, trace);
      return;
    }

    /// Call this every time for setting [Server.isBusy] to false
    _setServerState(s, ServerConn.finished);
    // reset try times only after prepared successfully
    TryLimiter.reset(sid);
  }
}
