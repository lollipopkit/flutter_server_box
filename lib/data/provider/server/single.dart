import 'dart:async';

import 'package:computer/computer.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/core/utils/ssh_auth.dart';
import 'package:server_box/data/helper/ssh_decoder.dart';
import 'package:server_box/data/helper/system_detector.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/connection_stat.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/server_status_update_req.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/session_manager.dart';

part 'single.g.dart';
part 'single.freezed.dart';

// Individual server state, including connection and status information
@freezed
abstract class ServerState with _$ServerState {
  const factory ServerState({
    required Spi spi,
    required ServerStatus status,
    @Default(ServerConn.disconnected) ServerConn conn,
    SSHClient? client,
    Future<void>? updateFuture,
  }) = _ServerState;
}

// Individual server state management
@Riverpod(keepAlive: true)
class ServerNotifier extends _$ServerNotifier {
  @override
  ServerState build(String serverId) {
    final serverNotifier = ref.read(serversProvider);
    final spi = serverNotifier.servers[serverId];
    if (spi == null) {
      throw StateError('Server $serverId not found');
    }

    return ServerState(spi: spi, status: InitStatus.status);
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

        // Record successful connection
        Stores.connectionStats.recordConnection(ConnectionStat(
          serverId: spi.id,
          serverName: spi.name,
          timestamp: time1,
          result: ConnectionResult.success,
          durationMs: spentTime,
        ));

        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.add(
          id: sessionId,
          spi: spi,
          startTimeMs: time1.millisecondsSinceEpoch,
          disconnect: () => ref.read(serversProvider.notifier).closeOneServer(spi.id),
          status: TermSessionStatus.connecting,
        );
        TermSessionManager.setActive(sessionId, hasTerminal: false);
      } catch (e) {
        TryLimiter.inc(sid);
        
        // Determine connection failure type
        ConnectionResult failureResult;
        if (e.toString().contains('timeout') || e.toString().contains('Timeout')) {
          failureResult = ConnectionResult.timeout;
        } else if (e.toString().contains('auth') || e.toString().contains('Authentication')) {
          failureResult = ConnectionResult.authFailed;
        } else if (e.toString().contains('network') || e.toString().contains('Network')) {
          failureResult = ConnectionResult.networkError;
        } else {
          failureResult = ConnectionResult.unknownError;
        }
        
        // Record failed connection
        Stores.connectionStats.recordConnection(ConnectionStat(
          serverId: spi.id,
          serverName: spi.name,
          timestamp: DateTime.now(),
          result: failureResult,
          errorMessage: e.toString(),
          durationMs: 0,
        ));
        
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

        Loggers.app.info('Writing script for ${spi.name} (${detectedSystemType.name})');
        
        final (stdoutResult, writeScriptResult) = await state.client!.execSafe(
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
          systemType: detectedSystemType,
          context: 'WriteScript<${spi.name}>',
        );
        
        if (stdoutResult.isNotEmpty) {
          Loggers.app.info('Script write stdout for ${spi.name}: $stdoutResult');
        }
        
        if (writeScriptResult.isNotEmpty) {
          Loggers.app.warning('Script write stderr for ${spi.name}: $writeScriptResult');
          if (detectedSystemType != SystemType.windows) {
            ShellFuncManager.switchScriptDir(spi.id, systemType: detectedSystemType);
            throw writeScriptResult;
          }
        } else {
          Loggers.app.info('Script written successfully for ${spi.name}');
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
      final statusCmd = ShellFunc.status.exec(spi.id, systemType: state.status.system, customDir: spi.custom?.scriptDir);
      Loggers.app.info('Running status command for ${spi.name} (${state.status.system.name}): $statusCmd');
      final execResult = await state.client?.run(statusCmd);
      if (execResult != null) {
        raw = SSHDecoder.decode(
          execResult,
          isWindows: state.status.system == SystemType.windows,
          context: 'GetStatus<${spi.name}>',
        );
        Loggers.app.info('Status response length for ${spi.name}: ${raw.length} bytes');
      } else {
        raw = '';
        Loggers.app.warning('No status result from ${spi.name}');
      }

      if (raw.isEmpty) {
        TryLimiter.inc(sid);
        final newStatus = state.status
          ..err = SSHErr(type: SSHErrType.segements, message: 'Empty response from server');
        updateStatus(newStatus);
        updateConnection(ServerConn.failed);

        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.updateStatus(sessionId, TermSessionStatus.disconnected);
        return;
      }

      segments = raw.split(ScriptConstants.separator).map((e) => e.trim()).toList();
      if (segments.isEmpty) {
        if (Stores.setting.keepStatusWhenErr.fetch()) {
          // Keep previous server status when error occurs
          if (state.conn != ServerConn.failed && state.status.more.isNotEmpty) {
            return;
          }
        }
        TryLimiter.inc(sid);
        final newStatus = state.status
          ..err = SSHErr(type: SSHErrType.segements, message: 'Separate segments failed, raw:\n$raw');
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

extension IndividualServerStateExtension on ServerState {
  bool get needGenClient => conn < ServerConn.connecting;

  bool get canViewDetails => conn == ServerConn.finished;

  String get id => spi.id;
}
