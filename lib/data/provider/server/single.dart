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
import 'package:server_box/data/ssh/persistent_shell.dart';
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
  }) = _ServerState;
}

// Individual server state management
@Riverpod(keepAlive: true)
class ServerNotifier extends _$ServerNotifier {
  PersistentShell? _persistentShell;
  bool _usePersistentShellForStatus = true;

  @override
  ServerState build(String serverId) {
    ref.onDispose(() {
      unawaited(_disposePersistentShell());
    });

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

  ServerStatus _copyStatus(
    ServerStatus source, {
    Err? err,
    bool setErr = false,
    SystemType? system,
  }) {
    final status = ServerStatus(
      cpu: source.cpu,
      mem: source.mem,
      disk: source.disk.toList(),
      tcp: source.tcp,
      netSpeed: source.netSpeed,
      swap: source.swap,
      temps: source.temps,
      system: system ?? source.system,
      diskIO: source.diskIO,
      diskSmart: source.diskSmart.toList(),
      err: setErr ? err : source.err,
      nvidia: source.nvidia?.toList(),
      diskUsage: source.diskUsage,
    );
    status.amd = source.amd?.toList();
    status.batteries.addAll(source.batteries);
    status.more.addAll(source.more);
    status.sensors.addAll(source.sensors);
    status.customCmds.addAll(source.customCmds);
    return status;
  }

  // Update SSH client
  void updateClient(SSHClient? client) {
    if (!identical(state.client, client)) {
      unawaited(_disposePersistentShell());
      _usePersistentShellForStatus = true;
    }
    state = state.copyWith(client: client);
  }

  // Update SPI configuration
  void updateSpi(Spi spi) {
    state = state.copyWith(spi: spi);
  }

  void _setFailedState(ServerStatus status, {bool closeClient = false}) {
    final client = state.client;
    unawaited(_disposePersistentShell());
    if (closeClient) {
      client?.close();
    }
    state = state.copyWith(
      status: status,
      client: closeClient ? null : client,
      conn: ServerConn.failed,
    );
  }

  // Close connection
  void closeConnection() {
    unawaited(_disposePersistentShell());
    state.client?.close();
    state = state.copyWith(client: null, conn: ServerConn.disconnected);
  }

  // Refresh server status
  bool _isRefreshing = false;

  Future<void> refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    try {
      await _updateServer();
    } finally {
      _isRefreshing = false;
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

    final newStatus = _copyStatus(
      state.status,
      err: null,
      setErr: true,
    ); // Clear previous error
    updateStatus(newStatus);

    if (state.conn < ServerConn.connecting ||
        (state.client?.isClosed ?? true)) {
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

      final time1 = DateTime.now();
      try {
        final client = await genClient(
          spi,
          timeout: Duration(seconds: Stores.setting.timeout.fetch()),
          onKeyboardInteractive: (_) => KeybordInteractive.defaultHandle(spi),
        );
        updateClient(client);

        final time2 = DateTime.now();
        final spentTime = time2.difference(time1).inMilliseconds;
        if (spi.resolvedJumpIds.isEmpty) {
          Loggers.app.info('Connected to ${spi.name} in $spentTime ms.');
        } else {
          Loggers.app.info('Jump to ${spi.name} in $spentTime ms.');
        }

        try {
          await Stores.connectionStats.recordConnection(
            ConnectionStat(
              serverId: spi.id,
              serverName: spi.name,
              timestamp: time1,
              result: ConnectionResult.success,
              durationMs: spentTime,
            ),
          );
        } catch (e) {
          Loggers.app.warning('Failed to record connection success', e);
        }

        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.add(
          id: sessionId,
          spi: spi,
          startTimeMs: time1.millisecondsSinceEpoch,
          disconnect: () =>
              ref.read(serversProvider.notifier).closeOneServer(spi.id),
          status: TermSessionStatus.connecting,
          setAsActive: false,
        );
        TermSessionManager.setActive(sessionId, hasTerminal: false);
      } catch (e) {
        TryLimiter.inc(sid);

        final durationMs = DateTime.now().difference(time1).inMilliseconds;

        ConnectionResult failureResult;
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('timed out') || errStr.contains('timeout')) {
          failureResult = ConnectionResult.timeout;
        } else if (errStr.contains('auth') ||
            errStr.contains('authentication') ||
            errStr.contains('permission denied') ||
            errStr.contains('access denied')) {
          failureResult = ConnectionResult.authFailed;
        } else if (errStr.contains('connection refused') ||
            errStr.contains('no route to host') ||
            errStr.contains('network') ||
            errStr.contains('socket')) {
          failureResult = ConnectionResult.networkError;
        } else {
          failureResult = ConnectionResult.unknownError;
        }

        try {
          await Stores.connectionStats.recordConnection(
            ConnectionStat(
              serverId: spi.id,
              serverName: spi.name,
              timestamp: time1,
              result: failureResult,
              errorMessage: e.toString(),
              durationMs: durationMs,
            ),
          );
        } catch (recErr) {
          Loggers.app.warning('Failed to record connection failure', recErr);
        }

        final newStatus = _copyStatus(
          state.status,
          err: SSHErr(type: SSHErrType.connect, message: e.toString()),
          setErr: true,
        );
        _setFailedState(newStatus, closeClient: true);

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
        final detectedSystemType = await SystemDetector.detect(
          state.client!,
          spi,
        );
        final newStatus = _copyStatus(state.status, system: detectedSystemType);
        updateStatus(newStatus);

        Loggers.app.info(
          'Writing script for ${spi.name} (${detectedSystemType.name})',
        );

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
          Loggers.app.info(
            'Script write stdout for ${spi.name}: $stdoutResult',
          );
        }

        if (writeScriptResult.isNotEmpty) {
          Loggers.app.warning(
            'Script write stderr for ${spi.name}: $writeScriptResult',
          );
          if (detectedSystemType != SystemType.windows) {
            ShellFuncManager.switchScriptDir(
              spi.id,
              systemType: detectedSystemType,
            );
            throw writeScriptResult;
          }
        } else {
          Loggers.app.info('Script written successfully for ${spi.name}');
        }
      } on SSHAuthAbortError catch (e) {
        TryLimiter.inc(sid);
        final err = SSHErr(type: SSHErrType.auth, message: e.toString());
        final newStatus = _copyStatus(state.status, err: err, setErr: true);
        Loggers.app.warning(err);
        _setFailedState(newStatus, closeClient: true);

        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.updateStatus(
          sessionId,
          TermSessionStatus.disconnected,
        );
        return;
      } on SSHAuthFailError catch (e) {
        TryLimiter.inc(sid);
        final err = SSHErr(type: SSHErrType.auth, message: e.toString());
        final newStatus = _copyStatus(state.status, err: err, setErr: true);
        Loggers.app.warning(err);
        _setFailedState(newStatus, closeClient: true);

        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.updateStatus(
          sessionId,
          TermSessionStatus.disconnected,
        );
        return;
      } catch (e) {
        final err = SSHErr(type: SSHErrType.writeScript, message: e.toString());
        final newStatus = _copyStatus(state.status, err: err, setErr: true);
        Loggers.app.warning(err);
        _setFailedState(newStatus, closeClient: true);

        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.updateStatus(
          sessionId,
          TermSessionStatus.disconnected,
        );
        return;
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
      final statusCmd = ShellFunc.status.exec(
        spi.id,
        systemType: state.status.system,
        customDir: spi.custom?.scriptDir,
      );
      // Loggers.app.info('Running status command for ${spi.name} (${state.status.system.name}): $statusCmd');
      raw = await _runStatusCommand(statusCmd);

      if (raw.isEmpty) {
        TryLimiter.inc(sid);
        final newStatus = _copyStatus(
          state.status,
          err: SSHErr(
            type: SSHErrType.segements,
            message: 'Empty response from server',
          ),
          setErr: true,
        );
        _setFailedState(newStatus);

        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.updateStatus(
          sessionId,
          TermSessionStatus.disconnected,
        );
        return;
      }

      segments = raw
          .split(ScriptConstants.separator)
          .map((e) => e.trim())
          .toList();
      if (segments.isEmpty) {
        if (Stores.setting.keepStatusWhenErr.fetch()) {
          // Keep previous server status when error occurs
          if (state.conn != ServerConn.failed && state.status.more.isNotEmpty) {
            return;
          }
        }
        TryLimiter.inc(sid);
        final newStatus = _copyStatus(
          state.status,
          err: SSHErr(
            type: SSHErrType.segements,
            message: 'Separate segments failed, raw:\n$raw',
          ),
          setErr: true,
        );
        _setFailedState(newStatus);

        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.updateStatus(
          sessionId,
          TermSessionStatus.disconnected,
        );
        return;
      }
    } on TimeoutException catch (e, s) {
      final newStatus = _copyStatus(
        state.status,
        err: SSHErr(type: SSHErrType.getStatus, message: e.toString()),
        setErr: true,
      );
      updateStatus(newStatus);
      if (state.client != null && state.conn != ServerConn.finished) {
        updateConnection(ServerConn.connected);
      }
      Loggers.app.warning('Get status from ${spi.name} timed out', e, s);

      final sessionId = 'ssh_${spi.id}';
      TermSessionManager.updateStatus(sessionId, TermSessionStatus.connected);
      return;
    } catch (e) {
      TryLimiter.inc(sid);
      final newStatus = _copyStatus(
        state.status,
        err: SSHErr(type: SSHErrType.getStatus, message: e.toString()),
        setErr: true,
      );
      _setFailedState(newStatus);
      Loggers.app.warning('Get status from ${spi.name} failed', e);

      final sessionId = 'ssh_${spi.id}';
      TermSessionManager.updateStatus(
        sessionId,
        TermSessionStatus.disconnected,
      );
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
        tempDivisor: spi.custom?.tempIsCelsius == true ? 1.0 : 1000.0,
      );
      final newStatus = await Computer.shared.start(
        getStatus,
        req,
        taskName: 'StatusUpdateReq<${spi.id}>',
      );
      updateStatus(newStatus);
    } catch (e, trace) {
      TryLimiter.inc(sid);
      final newStatus = _copyStatus(
        state.status,
        err: SSHErr(
          type: SSHErrType.getStatus,
          message: 'Parse failed: $e\n\n$raw',
        ),
        setErr: true,
      );
      _setFailedState(newStatus);
      Loggers.app.warning('Server status', e, trace);

      final sessionId = 'ssh_${spi.id}';
      TermSessionManager.updateStatus(
        sessionId,
        TermSessionStatus.disconnected,
      );
      return;
    }

    // Set Server.isBusy to false each time this method is called
    updateConnection(ServerConn.finished);
    // Reset retry count only after successful preparation
    TryLimiter.reset(sid);
  }

  Future<String> _runStatusCommand(String statusCmd) async {
    final client = state.client;
    final spi = state.spi;

    if (client == null) {
      Loggers.app.warning(
        'Client for ${spi.name} is null, skipping status fetch',
      );
      return '';
    }

    if (state.status.system == SystemType.windows) {
      return _runStatusCommandWithExec(client, statusCmd, isWindows: true);
    }

    if (!_usePersistentShellForStatus) {
      return _runStatusCommandWithExec(client, statusCmd);
    }

    try {
      final shell = await _getPersistentShell();
      final statusTimeoutSeconds = Stores.setting.timeout.fetch();
      final statusTimeout = Duration(
        seconds: statusTimeoutSeconds <= 0 ? 5 : statusTimeoutSeconds,
      );
      final result = await shell.run(statusCmd, timeout: statusTimeout);
      return result.output;
    } on TimeoutException catch (e, s) {
      _usePersistentShellForStatus = false;
      await _disposePersistentShell();
      Loggers.app.warning(
        'Persistent shell status command timed out for ${spi.name}; fallback to exec for this connection',
        e,
        s,
      );
      return _runStatusCommandWithExec(client, statusCmd);
    }
  }

  Future<String> _runStatusCommandWithExec(
    SSHClient client,
    String statusCmd, {
    bool isWindows = false,
  }) async {
    final spi = state.spi;
    final execResult = await client
        .run(statusCmd)
        .timeout(const Duration(seconds: 30));
    return SSHDecoder.decode(
      execResult,
      isWindows: isWindows,
      context: 'GetStatus<${spi.name}>',
    );
  }

  Future<PersistentShell> _getPersistentShell() async {
    final client = state.client;
    if (client == null) {
      throw StateError('SSH client is not connected');
    }

    final shell = _persistentShell;
    if (shell != null) {
      return shell;
    }

    final newShell = PersistentShell(client);
    _persistentShell = newShell;
    return newShell;
  }

  Future<void> _disposePersistentShell() async {
    final shell = _persistentShell;
    _persistentShell = null;
    await shell?.close();
  }
}

extension IndividualServerStateExtension on ServerState {
  bool get needGenClient => conn < ServerConn.connecting;

  bool get canViewDetails => conn == ServerConn.finished;

  String get id => spi.id;
}
