import 'dart:async';
import 'dart:convert';

import 'package:computer/computer.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_gbk2utf8/flutter_gbk2utf8.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/core/utils/ssh_auth.dart';
import 'package:server_box/data/helper/system_detector.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/server_status_update_req.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/session_manager.dart';

part 'server.freezed.dart';
part 'server.g.dart';

@freezed
abstract class ServerState with _$ServerState {
  const factory ServerState({
    @Default({}) Map<String, Spi> servers, // Only store server configuration information
    @Default([]) List<String> serverOrder,
    @Default(<String>{}) Set<String> tags,
    @Default(<String>{}) Set<String> manualDisconnectedIds,
    Timer? autoRefreshTimer,
  }) = _ServerState;
}

// Individual server state, including connection and status information
@freezed
abstract class IndividualServerState with _$IndividualServerState {
  const factory IndividualServerState({
    required Spi spi,
    required ServerStatus status,
    @Default(ServerConn.disconnected) ServerConn conn,
    SSHClient? client,
    Future<void>? updateFuture,
  }) = _IndividualServerState;
}

// Individual server state management
@riverpod
class IndividualServerNotifier extends _$IndividualServerNotifier {
  @override
  IndividualServerState build(String serverId) {
    final serverNotifier = ref.read(serverNotifierProvider);
    final spi = serverNotifier.servers[serverId];
    if (spi == null) {
      throw StateError('Server $serverId not found');
    }

    return IndividualServerState(spi: spi, status: InitStatus.status);
  }

  // Update connection status
  void updateConnection(ServerConn conn) {
    state = state.copyWith(conn: conn);
  }

  // Update server status
  void updateStatus(ServerStatus status) {
    state = state.copyWith(status: status);
  }

  // Update SSH client
  void updateClient(SSHClient? client) {
    state = state.copyWith(client: client);
  }

  // Update SPI configuration
  void updateSpi(Spi spi) {
    state = state.copyWith(spi: spi);
  }

  // Close connection
  void closeConnection() {
    final client = state.client;
    client?.close();
    state = state.copyWith(client: null, conn: ServerConn.disconnected);
  }

  // Refresh server status
  Future<void> refresh() async {
    if (state.updateFuture != null) {
      await state.updateFuture;
      return;
    }

    final updateFuture = _updateServer();
    state = state.copyWith(updateFuture: updateFuture);

    try {
      await updateFuture;
    } finally {
      state = state.copyWith(updateFuture: null);
    }
  }

  Future<void> _updateServer() async {
    await _getData();
  }

  Future<void> _getData() async {
    final spi = state.spi;
    final sid = spi.id;

    if (!TryLimiter.canTry(sid)) {
      if (state.conn != ServerConn.failed) {
        updateConnection(ServerConn.failed);
      }
      return;
    }

    final newStatus = state.status..err = null; // Clear previous error
    updateStatus(newStatus);

    if (state.conn < ServerConn.connecting || (state.client?.isClosed ?? true)) {
      updateConnection(ServerConn.connecting);

      // Wake on LAN
      final wol = spi.wolCfg;
      if (wol != null) {
        try {
          await wol.wake();
        } catch (e) {
          Loggers.app.warning('Wake on lan failed', e);
        }
      }

      try {
        final time1 = DateTime.now();
        final client = await genClient(
          spi,
          timeout: Duration(seconds: Stores.setting.timeout.fetch()),
          onKeyboardInteractive: (_) => KeybordInteractive.defaultHandle(spi),
        );
        updateClient(client);

        final time2 = DateTime.now();
        final spentTime = time2.difference(time1).inMilliseconds;
        if (spi.jumpId == null) {
          Loggers.app.info('Connected to ${spi.name} in $spentTime ms.');
        } else {
          Loggers.app.info('Jump to ${spi.name} in $spentTime ms.');
        }

        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.add(
          id: sessionId,
          spi: spi,
          startTimeMs: time1.millisecondsSinceEpoch,
          disconnect: () => ref.read(serverNotifierProvider.notifier)._closeOneServer(spi.id),
          status: TermSessionStatus.connecting,
        );
        TermSessionManager.setActive(sessionId, hasTerminal: false);
      } catch (e) {
        TryLimiter.inc(sid);
        final newStatus = state.status..err = SSHErr(type: SSHErrType.connect, message: e.toString());
        updateStatus(newStatus);
        updateConnection(ServerConn.failed);

        // Remove SSH session when connection fails
        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.remove(sessionId);

        Loggers.app.warning('Connect to ${spi.name} failed', e);
        return;
      }

      updateConnection(ServerConn.connected);

      // Update SSH session status to connected
      final sessionId = 'ssh_${spi.id}';
      TermSessionManager.updateStatus(sessionId, TermSessionStatus.connected);

      try {
        // Detect system type
        final detectedSystemType = await SystemDetector.detect(state.client!, spi);
        final newStatus = state.status..system = detectedSystemType;
        updateStatus(newStatus);

        final (_, writeScriptResult) = await state.client!.exec(
          (session) async {
            final scriptRaw = ShellFuncManager.allScript(
              spi.custom?.cmds,
              systemType: detectedSystemType,
              disabledCmdTypes: spi.disabledCmdTypes,
            ).uint8List;
            session.stdin.add(scriptRaw);
            session.stdin.close();
          },
          entry: ShellFuncManager.getInstallShellCmd(
            spi.id,
            systemType: detectedSystemType,
            customDir: spi.custom?.scriptDir,
          ),
        );
        if (writeScriptResult.isNotEmpty && detectedSystemType != SystemType.windows) {
          ShellFuncManager.switchScriptDir(spi.id, systemType: detectedSystemType);
          throw writeScriptResult;
        }
      } on SSHAuthAbortError catch (e) {
        TryLimiter.inc(sid);
        final err = SSHErr(type: SSHErrType.auth, message: e.toString());
        final newStatus = state.status..err = err;
        updateStatus(newStatus);
        Loggers.app.warning(err);
        updateConnection(ServerConn.failed);

        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.updateStatus(sessionId, TermSessionStatus.disconnected);
        return;
      } on SSHAuthFailError catch (e) {
        TryLimiter.inc(sid);
        final err = SSHErr(type: SSHErrType.auth, message: e.toString());
        final newStatus = state.status..err = err;
        updateStatus(newStatus);
        Loggers.app.warning(err);
        updateConnection(ServerConn.failed);

        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.updateStatus(sessionId, TermSessionStatus.disconnected);
        return;
      } catch (e) {
        final err = SSHErr(type: SSHErrType.writeScript, message: e.toString());
        final newStatus = state.status..err = err;
        updateStatus(newStatus);
        Loggers.app.warning(err);
        updateConnection(ServerConn.failed);

        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.updateStatus(sessionId, TermSessionStatus.disconnected);
      }
    }

    if (state.conn == ServerConn.connecting) return;

    // Keep finished status to prevent UI from refreshing to loading state
    if (state.conn != ServerConn.finished) {
      updateConnection(ServerConn.loading);
    }

    List<String>? segments;
    String? raw;

    try {
      final execResult = await state.client?.run(
        ShellFunc.status.exec(spi.id, systemType: state.status.system, customDir: spi.custom?.scriptDir),
      );
      if (execResult != null) {
        String? rawStr;
        bool needGbk = false;
        try {
          rawStr = utf8.decode(execResult, allowMalformed: true);
          // If there are unparseable characters, try fallback to GBK decoding
          if (rawStr.contains('�')) {
            Loggers.app.warning('UTF8 decoding failed, use GBK decoding');
            needGbk = true;
          }
        } catch (e) {
          Loggers.app.warning('UTF8 decoding failed, use GBK decoding', e);
          needGbk = true;
        }
        if (needGbk) {
          try {
            rawStr = gbk.decode(execResult);
          } catch (e2) {
            Loggers.app.warning('GBK decoding failed', e2);
            rawStr = null;
          }
        }
        if (rawStr == null) {
          Loggers.app.warning('Decoding failed, execResult: $execResult');
        }
        raw = rawStr;
      } else {
        raw = execResult.toString();
      }

      if (raw == null || raw.isEmpty) {
        TryLimiter.inc(sid);
        final newStatus = state.status
          ..err = SSHErr(type: SSHErrType.segements, message: 'decode or split failed, raw:\n$raw');
        updateStatus(newStatus);
        updateConnection(ServerConn.failed);

        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.updateStatus(sessionId, TermSessionStatus.disconnected);
        return;
      }

      segments = raw.split(ScriptConstants.separator).map((e) => e.trim()).toList();
      if (raw.isEmpty || segments.isEmpty) {
        if (Stores.setting.keepStatusWhenErr.fetch()) {
          // Keep previous server status when error occurs
          if (state.conn != ServerConn.failed && state.status.more.isNotEmpty) {
            return;
          }
        }
        TryLimiter.inc(sid);
        final newStatus = state.status
          ..err = SSHErr(type: SSHErrType.segements, message: 'Seperate segments failed, raw:\n$raw');
        updateStatus(newStatus);
        updateConnection(ServerConn.failed);

        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.updateStatus(sessionId, TermSessionStatus.disconnected);
        return;
      }
    } catch (e) {
      TryLimiter.inc(sid);
      final newStatus = state.status..err = SSHErr(type: SSHErrType.getStatus, message: e.toString());
      updateStatus(newStatus);
      updateConnection(ServerConn.failed);
      Loggers.app.warning('Get status from ${spi.name} failed', e);

      final sessionId = 'ssh_${spi.id}';
      TermSessionManager.updateStatus(sessionId, TermSessionStatus.disconnected);
      return;
    }

    try {
      // Parse script output into command-specific mappings
      final parsedOutput = ScriptConstants.parseScriptOutput(raw);

      final req = ServerStatusUpdateReq(
        ss: state.status,
        parsedOutput: parsedOutput,
        system: state.status.system,
        customCmds: spi.custom?.cmds ?? {},
      );
      final newStatus = await Computer.shared.start(getStatus, req, taskName: 'StatusUpdateReq<${spi.id}>');
      updateStatus(newStatus);
    } catch (e, trace) {
      TryLimiter.inc(sid);
      final newStatus = state.status
        ..err = SSHErr(type: SSHErrType.getStatus, message: 'Parse failed: $e\n\n$raw');
      updateStatus(newStatus);
      updateConnection(ServerConn.failed);
      Loggers.app.warning('Server status', e, trace);

      final sessionId = 'ssh_${spi.id}';
      TermSessionManager.updateStatus(sessionId, TermSessionStatus.disconnected);
      return;
    }

    // Set Server.isBusy to false each time this method is called
    updateConnection(ServerConn.finished);
    // Reset retry count only after successful preparation
    TryLimiter.reset(sid);
  }
}

@Riverpod(keepAlive: true)
class ServerNotifier extends _$ServerNotifier {
  @override
  ServerState build() {
    // Initialize with empty state, load data asynchronously
    Future.microtask(() => _load());
    return const ServerState();
  }

  Future<void> _load() async {
    final spis = Stores.server.fetch();
    final newServers = <String, Spi>{};
    final newServerOrder = <String>[];

    for (final spi in spis) {
      newServers[spi.id] = spi;
    }

    final serverOrder_ = Stores.setting.serverOrder.fetch();
    if (serverOrder_.isNotEmpty) {
      spis.reorder(order: serverOrder_, finder: (n, id) => n.id == id);
      newServerOrder.addAll(spis.map((e) => e.id));
    } else {
      newServerOrder.addAll(newServers.keys);
    }

    // Must use [equals] to compare [Order] here.
    if (!newServerOrder.equals(serverOrder_)) {
      Stores.setting.serverOrder.put(newServerOrder);
    }

    final newTags = _calculateTags(newServers);

    state = state.copyWith(servers: newServers, serverOrder: newServerOrder, tags: newTags);
  }

  Set<String> _calculateTags(Map<String, Spi> servers) {
    final tags = <String>{};
    for (final spi in servers.values) {
      final spiTags = spi.tags;
      if (spiTags == null) continue;
      for (final t in spiTags) {
        tags.add(t);
      }
    }
    return tags;
  }

  /// Get a [Spi] by [spi] or [id].
  ///
  /// Priority: [spi] > [id]
  Spi? pick({Spi? spi, String? id}) {
    if (spi != null) {
      return state.servers[spi.id];
    }
    if (id != null) {
      return state.servers[id];
    }
    return null;
  }

  /// if [spi] is specificed then only refresh this server
  /// [onlyFailed] only refresh failed servers
  Future<void> refresh({Spi? spi, bool onlyFailed = false}) async {
    if (spi != null) {
      final newManualDisconnected = Set<String>.from(state.manualDisconnectedIds)..remove(spi.id);
      state = state.copyWith(manualDisconnectedIds: newManualDisconnected);
      final serverNotifier = ref.read(individualServerNotifierProvider(spi.id).notifier);
      await serverNotifier.refresh();
      return;
    }

    await Future.wait(
      state.servers.entries.map((entry) async {
        final serverId = entry.key;
        final spi = entry.value;

        if (onlyFailed) {
          final serverState = ref.read(individualServerNotifierProvider(serverId));
          if (serverState.conn != ServerConn.failed) return;
          TryLimiter.reset(serverId);
        }

        if (state.manualDisconnectedIds.contains(serverId)) return;

        final serverState = ref.read(individualServerNotifierProvider(serverId));
        if (serverState.conn == ServerConn.disconnected && !spi.autoConnect) {
          return;
        }

        final serverNotifier = ref.read(individualServerNotifierProvider(serverId).notifier);
        await serverNotifier.refresh();
      }),
    );
  }

  Future<void> startAutoRefresh() async {
    var duration = Stores.setting.serverStatusUpdateInterval.fetch();
    stopAutoRefresh();
    if (duration == 0) return;
    if (duration < 0 || duration > 10 || duration == 1) {
      duration = 3;
      Loggers.app.warning('Invalid duration: $duration, use default 3');
    }
    final timer = Timer.periodic(Duration(seconds: duration), (_) async {
      await refresh();
    });
    state = state.copyWith(autoRefreshTimer: timer);
  }

  void stopAutoRefresh() {
    final timer = state.autoRefreshTimer;
    if (timer != null) {
      timer.cancel();
      state = state.copyWith(autoRefreshTimer: null);
    }
  }

  bool get isAutoRefreshOn => state.autoRefreshTimer != null;

  void setDisconnected() {
    for (final serverId in state.servers.keys) {
      final serverNotifier = ref.read(individualServerNotifierProvider(serverId).notifier);
      serverNotifier.updateConnection(ServerConn.disconnected);

      // Update SSH session status to disconnected
      final sessionId = 'ssh_$serverId';
      TermSessionManager.updateStatus(sessionId, TermSessionStatus.disconnected);
    }
    //TryLimiter.clear();
  }

  void closeServer({String? id}) {
    if (id == null) {
      for (final serverId in state.servers.keys) {
        _closeOneServer(serverId);
      }
      return;
    }
    _closeOneServer(id);
  }

  void _closeOneServer(String id) {
    final spi = state.servers[id];
    if (spi == null) {
      Loggers.app.warning('Server with id $id not found');
      return;
    }

    final serverNotifier = ref.read(individualServerNotifierProvider(id).notifier);
    serverNotifier.closeConnection();

    final newManualDisconnected = Set<String>.from(state.manualDisconnectedIds)..add(id);
    state = state.copyWith(manualDisconnectedIds: newManualDisconnected);

    // Remove SSH session when server is manually closed
    final sessionId = 'ssh_$id';
    TermSessionManager.remove(sessionId);
  }

  void addServer(Spi spi) {
    final newServers = Map<String, Spi>.from(state.servers);
    newServers[spi.id] = spi;

    final newOrder = List<String>.from(state.serverOrder)..add(spi.id);
    final newTags = _calculateTags(newServers);

    state = state.copyWith(servers: newServers, serverOrder: newOrder, tags: newTags);

    Stores.server.put(spi);
    Stores.setting.serverOrder.put(newOrder);
    refresh(spi: spi);
    bakSync.sync(milliDelay: 1000);
  }

  void delServer(String id) {
    final newServers = Map<String, Spi>.from(state.servers);
    newServers.remove(id);

    final newOrder = List<String>.from(state.serverOrder)..remove(id);
    final newTags = _calculateTags(newServers);

    state = state.copyWith(servers: newServers, serverOrder: newOrder, tags: newTags);

    Stores.setting.serverOrder.put(newOrder);
    Stores.server.delete(id);

    // Remove SSH session when server is deleted
    final sessionId = 'ssh_$id';
    TermSessionManager.remove(sessionId);

    bakSync.sync(milliDelay: 1000);
  }

  void deleteAll() {
    // Remove all SSH sessions before clearing servers
    for (final id in state.servers.keys) {
      final sessionId = 'ssh_$id';
      TermSessionManager.remove(sessionId);
    }

    state = const ServerState();

    Stores.setting.serverOrder.put([]);
    Stores.server.clear();
    bakSync.sync(milliDelay: 1000);
  }

  Future<void> updateServer(Spi old, Spi newSpi) async {
    if (old != newSpi) {
      Stores.server.update(old, newSpi);

      final newServers = Map<String, Spi>.from(state.servers);
      final newOrder = List<String>.from(state.serverOrder);

      if (newSpi.id != old.id) {
        newServers[newSpi.id] = newSpi;
        newServers.remove(old.id);
        newOrder.update(old.id, newSpi.id);
        Stores.setting.serverOrder.put(newOrder);

        // Update SSH session ID when server ID changes
        final oldSessionId = 'ssh_${old.id}';
        TermSessionManager.remove(oldSessionId);
        // Session will be re-added when reconnecting if necessary
      } else {
        newServers[old.id] = newSpi;
        // Update SPI in the corresponding IndividualServerNotifier
        final serverNotifier = ref.read(individualServerNotifierProvider(old.id).notifier);
        serverNotifier.updateSpi(newSpi);
      }

      final newTags = _calculateTags(newServers);
      state = state.copyWith(servers: newServers, serverOrder: newOrder, tags: newTags);

      // Only reconnect if neccessary
      if (newSpi.shouldReconnect(old)) {
        // Use [newSpi.id] instead of [old.id] because [old.id] may be changed
        TryLimiter.reset(newSpi.id);
        refresh(spi: newSpi);
      }
    }
    bakSync.sync(milliDelay: 1000);
  }
}
