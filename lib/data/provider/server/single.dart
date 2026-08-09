import 'dart:async';

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
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/connection_stat.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/status_history.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/temp.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/data_source.dart';
import 'package:server_box/data/provider/server/monitor_http_source.dart';
import 'package:server_box/data/provider/server/ssh_source.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/persistent_shell.dart';
import 'package:server_box/data/ssh/session_manager.dart';

part 'single.g.dart';
part 'single.freezed.dart';

/// How often [ShellFunc.statusExt] runs, independent of the status poll.
///
/// It carries the commands kept out of the poll (`sbm_parser::commands::
/// EXTENDED`), chiefly smartctl: reading SMART reaches the disk itself, so at
/// the status interval a disk with spin-down configured would never stay spun
/// down. The values it collects (SMART, AMD GPU) don't change meaningfully
/// faster than this anyway.
const _extendedStatusInterval = Duration(minutes: 5);

// Individual server state, including connection and status information
@freezed
abstract class ServerState with _$ServerState {
  const factory ServerState({
    required Spi spi,
    required ServerStatus status,
    @Default(ServerConn.disconnected) ServerConn conn,
    SSHClient? client,
  }) = _ServerState;

  const ServerState._();

  /// What this server's connection method can do. The UI reads this instead of
  /// testing which transport is in use — see [ServerCapabilities].
  ServerCapabilities get capabilities =>
      ServerCapabilities.of(ServerConnectCredential.fromSpi(spi));
}

// Individual server state management
@Riverpod(keepAlive: true)
class ServerNotifier extends _$ServerNotifier {
  PersistentShell? _persistentShell;
  bool _usePersistentShellForStatus = true;
  int _operationGeneration = 0;

  /// Last [ShellFunc.statusExt] output, appended to every status refresh's raw
  /// output so its segments don't blank out on the polls in between — see
  /// [_extendedStatusInterval]
  String _extendedRaw = '';
  DateTime? _extendedFetchedAt;

  /// Reads status for whichever connection method this server uses. Rebuilt
  /// when the SPI's connection config changes.
  ServerDataSource? _source;

  @override
  ServerState build(String serverId) {
    ref.onDispose(() {
      unawaited(_disposePersistentShell());
      _source?.close();
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
      cpu: Cpus.copy(source.cpu),
      mem: source.mem,
      disk: source.disk.toList(),
      tcp: source.tcp,
      netSpeed: NetSpeed.copy(source.netSpeed),
      swap: source.swap,
      temps: Temperatures.copy(source.temps),
      system: system ?? source.system,
      diskIO: DiskIO.copy(source.diskIO),
      diskSmart: source.diskSmart.toList(),
      err: setErr ? err : source.err,
      nvidia: source.nvidia?.toList(),
      diskUsage: source.diskUsage,
      // Shared, unlike the rolling values above. It is append-only, so a
      // reader never sees it torn, and copying three hundred samples across
      // ten series every refresh would buy nothing.
      history: source.history,
    );
    status.amd = source.amd?.toList();
    status.batteries.addAll(source.batteries);
    status.more.addAll(source.more);
    status.sensors.addAll(source.sensors);
    status.customCmds.addAll(source.customCmds);
    return status;
  }

  // Update SSH client
  void _setClient(SSHClient? client) {
    if (!identical(state.client, client)) {
      unawaited(_disposePersistentShell());
      _usePersistentShellForStatus = true;
      // A new connection reinstalls the script, so drop the cache: the next
      // refresh re-runs the extended function against the current script
      _extendedRaw = '';
      _extendedFetchedAt = null;
    }
    state = state.copyWith(client: client);
  }

  void updateClient(SSHClient? client) {
    _operationGeneration++;
    _setClient(client);
  }

  // Update SPI configuration
  void updateSpi(Spi spi) {
    _operationGeneration++;
    unawaited(_disposePersistentShell());
    state.client?.close();
    _usePersistentShellForStatus = true;
    state = state.copyWith(
      spi: spi,
      client: null,
      conn: ServerConn.disconnected,
    );
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
    _operationGeneration++;
    unawaited(_disposePersistentShell());
    state.client?.close();
    state = state.copyWith(client: null, conn: ServerConn.disconnected);
  }

  // Refresh server status
  bool _isRefreshing = false;

  Future<void> refresh({bool interactive = false}) async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    final operation = _operationGeneration;
    try {
      await _getData(interactive: interactive, operation: operation);
    } finally {
      _isRefreshing = false;
    }
  }

  /// [interactive] only reaches the SSH path: it gates prompting the user for
  /// keyboard-interactive auth, which has no counterpart over monitor's HTTP
  /// API (credentials there are configured up front, never prompted for).
  /// Whether the refresh identified by [operation] is still the current one
  /// and still targets [spi].
  ///
  /// `_isRefreshing` stops two refreshes overlapping, but not one that outlives
  /// what started it: editing the server or closing the connection bumps the
  /// generation, and an in-flight refresh that then finishes would publish a
  /// status for a server that no longer exists in that form. Every `await` in
  /// the SSH path re-checks this.
  bool _isRefreshCurrent(int operation, Spi spi) =>
      operation == _operationGeneration && state.spi == spi;

  Future<void> _getData({
    required bool interactive,
    required int operation,
  }) async {
    switch (ServerConnectCredential.fromSpi(state.spi)) {
      case ServerConnectCredentialSsh():
        // Connecting is inseparable from fetching here (auth prompts, script
        // install, session bookkeeping), so the SSH path drives the state
        // machine itself and hands the reading half to SshDataSource
        await _getDataSsh(interactive: interactive, operation: operation);
      case ServerConnectCredentialMonitorHttp(:final monitor):
        await _getDataMonitorHttp(monitor, operation);
    }
  }

  /// The [ServerDataSource] for the current SPI.
  ///
  /// Only the monitor HTTP source is cached: it owns a `Dio` session and a
  /// login token, so reusing it across refreshes avoids re-authenticating, and
  /// it must be rebuilt when the connection config changes. [SshDataSource] is
  /// stateless — the connection it reads through belongs to this notifier — so
  /// the SSH path constructs one per refresh instead.
  ServerDataSource _resolveSource(ServerConnectCredential credential) {
    switch (credential) {
      case ServerConnectCredentialSsh():
        return SshDataSource(
          spi: state.spi,
          runScript: () => throw StateError(
            'SSH status output is supplied by _getDataSsh, which runs the '
            'script as part of its connect-and-fetch flow',
          ),
        );
      case ServerConnectCredentialMonitorHttp():
        final existing = _source;
        if (existing is MonitorHttpDataSource && existing.matches(credential)) {
          return existing;
        }
        existing?.close();
        return _source = MonitorHttpDataSource(credential);
    }
  }

  /// Status polling via a `monitor` instance's HTTP API instead of SSH+shell
  /// (see `Spi.monitorHttp`). Deliberately does NOT fall back to SSH on
  /// failure — a misconfigured/unreachable monitor should surface as an
  /// error, not silently switch data sources.
  Future<void> _getDataMonitorHttp(
    MonitorHttpCredential monitor,
    int operation,
  ) async {
    final spi = state.spi;
    final sid = spi.id;

    if (!TryLimiter.canTry(sid)) {
      if (state.conn != ServerConn.failed) {
        updateConnection(ServerConn.failed);
      }
      return;
    }

    updateStatus(_copyStatus(state.status, err: null, setErr: true));
    if (state.conn < ServerConn.connecting) {
      updateConnection(ServerConn.connecting);
    }
    if (state.conn != ServerConn.finished) {
      updateConnection(ServerConn.loading);
    }

    final source = _resolveSource(
      ServerConnectCredentialMonitorHttp(spi: spi, monitor: monitor),
    );

    try {
      updateStatus(await source.fetchStatus(_copyStatus(state.status)));
      updateConnection(ServerConn.finished);
      TryLimiter.reset(sid);
    } catch (e, s) {
      TryLimiter.inc(sid);
      final err = e is MonitorHttpErr
          ? e
          : MonitorHttpErr(
              type: MonitorHttpErrType.unknown,
              message: e.toString(),
            );
      _setFailedState(_copyStatus(state.status, err: err, setErr: true));
      Loggers.app.warning('Get status via monitor for ${spi.name} failed', e, s);
    }
  }

  /// Prefills [ServerStatus.history] from whatever trend data the source
  /// already holds, so a freshly opened detail page shows a trend instead of
  /// building one up from scratch. A no-op for sources without
  /// [ServerCapabilities.storedHistory], and once live samples exist — see
  /// [StatusHistory.seed].
  Future<void> seedHistory({int minutes = 60}) async {
    final credential = ServerConnectCredential.fromSpi(state.spi);
    if (!ServerCapabilities.of(credential).storedHistory) return;
    try {
      final samples = await _resolveSource(
        credential,
      ).fetchHistory(minutes: minutes);
      if (samples.isEmpty) return;
      state.status.history.seed(samples);
      // history is mutated in place, so hand out a fresh ServerStatus to make
      // the watchers rebuild
      updateStatus(_copyStatus(state.status));
    } catch (e, s) {
      Loggers.app.warning('Seed history for ${state.spi.name}', e, s);
    }
  }

  String get _sshSessionId => 'ssh_${state.spi.id}';

  /// The failure ritual every SSH branch repeated: count the attempt against
  /// the retry limiter, record the error on the status, drop to `failed`, and
  /// mark the terminal session dead. Nine copies of it made the actual control
  /// flow of `_getDataSsh` hard to see, and each copy was a chance to forget
  /// one of the four steps.
  ///
  /// [countAttempt] is false for the one case that must not burn a retry:
  /// a connection that only failed because keyboard-interactive auth needed a
  /// prompt this non-interactive refresh could not show.
  void _failSsh(
    SSHErrType type,
    Object e, {
    bool closeClient = false,
    bool countAttempt = true,
    String? message,
  }) {
    if (countAttempt) TryLimiter.inc(state.spi.id);
    final err = SSHErr(type: type, message: message ?? e.toString());
    _setFailedState(
      _copyStatus(state.status, err: err, setErr: true),
      closeClient: closeClient,
    );
    TermSessionManager.updateStatus(
      _sshSessionId,
      TermSessionStatus.disconnected,
    );
    Loggers.app.warning('SSH ${state.spi.name}', err);
  }

  Future<void> _getDataSsh({
    required bool interactive,
    required int operation,
  }) async {
    final spi = state.spi;
    final sid = spi.id;
    var keyboardInteractiveRequested = false;

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
          if (!_isRefreshCurrent(operation, spi)) return;
        } catch (e) {
          Loggers.app.warning('Wake on lan failed', e);
        }
        if (!_isRefreshCurrent(operation, spi)) return;
      }

      final time1 = DateTime.now();
      try {
        final client = await genClient(
          spi,
          timeout: Duration(seconds: Stores.setting.timeout.fetch()),
          onKeyboardInteractive: (server, request) {
            keyboardInteractiveRequested = true;
            if (!interactive) return null;
            return KeyboardInteractiveAuth.handle(server, request);
          },
        );
        await client.authenticated;
        if (!_isRefreshCurrent(operation, spi)) {
          client.close();
          return;
        }
        _setClient(client);

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
        if (!_isRefreshCurrent(operation, spi)) return;

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
        if (!_isRefreshCurrent(operation, spi)) return;
        if (!keyboardInteractiveRequested || interactive) {
          TryLimiter.inc(sid);
        }

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
        if (!_isRefreshCurrent(operation, spi)) return;

        final SSHErrType errType;
        if (keyboardInteractiveRequested && !interactive) {
          errType = SSHErrType.interactiveAuth;
        } else if (e is SSHAuthError) {
          errType = SSHErrType.auth;
        } else {
          errType = SSHErrType.connect;
        }
        _setFailedState(
          _copyStatus(
            state.status,
            err: SSHErr(type: errType, message: e.toString()),
            setErr: true,
          ),
          closeClient: true,
        );
        // Removed, not just marked dead: there is no session to reconnect to
        TermSessionManager.remove(_sshSessionId);
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
        if (!_isRefreshCurrent(operation, spi)) return;
        final newStatus = _copyStatus(state.status, system: detectedSystemType);
        updateStatus(newStatus);

        Loggers.app.info(
          'Writing script for ${spi.name} (${detectedSystemType.name})',
        );

        final writeScriptResult = await state.client!.execSafe(
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
        if (!_isRefreshCurrent(operation, spi)) return;

        if (writeScriptResult.stdout.isNotEmpty) {
          Loggers.app.info(
            'Script write stdout for ${spi.name}: ${writeScriptResult.stdout}',
          );
        }

        if (writeScriptResult.stderr.isNotEmpty) {
          Loggers.app.warning(
            'Script write stderr for ${spi.name}: ${writeScriptResult.stderr}',
          );
        }

        if (!writeScriptResult.succeeded) {
          if (spi.custom?.scriptDir == null) {
            ShellFuncManager.switchScriptDir(
              spi.id,
              systemType: detectedSystemType,
            );
          }
          final output = writeScriptResult.stderr.isNotEmpty
              ? writeScriptResult.stderr
              : writeScriptResult.stdout;
          throw 'Script installation exited with code '
              '${writeScriptResult.exitCode}: $output';
        } else {
          Loggers.app.info('Script written successfully for ${spi.name}');
        }
      } on SSHAuthAbortError catch (e) {
        _failSsh(SSHErrType.auth, e, closeClient: true);
        return;
      } on SSHAuthFailError catch (e) {
        _failSsh(SSHErrType.auth, e, closeClient: true);
        return;
      } catch (e) {
        _failSsh(SSHErrType.writeScript, e, closeClient: true);
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
      raw = await _runStatusCommand(statusCmd);
      if (!_isRefreshCurrent(operation, spi)) return;

      // Empty output is only a failure if the server was asked for anything.
      // A host with every status command disabled legitimately returns nothing.
      if (raw.isEmpty &&
          _hasEnabledStatusCommands(spi, state.status.system)) {
        _failSsh(
          SSHErrType.segments,
          '',
          message: 'Empty response from server',
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
        _failSsh(
          SSHErrType.segments,
          '',
          message: 'Separate segments failed, raw:\n$raw',
        );
        return;
      }
    } on TimeoutException catch (e, s) {
      // Not _failSsh: a timed-out status read leaves the connection itself
      // intact, so the session stays connected and the attempt isn't counted
      updateStatus(
        _copyStatus(
          state.status,
          err: SSHErr(type: SSHErrType.getStatus, message: e.toString()),
          setErr: true,
        ),
      );
      if (state.client != null && state.conn != ServerConn.finished) {
        updateConnection(ServerConn.connected);
      }
      Loggers.app.warning('Get status from ${spi.name} timed out', e, s);
      TermSessionManager.updateStatus(
        _sshSessionId,
        TermSessionStatus.connected,
      );
      return;
    } catch (e) {
      _failSsh(SSHErrType.getStatus, e);
      return;
    }

    try {
      // Segments the status function no longer carries, refreshed on their own
      // schedule and concatenated here: the parser splits by separator, so one
      // combined output parses exactly as the two runs would have
      final extended = await _refreshExtendedRaw(force: interactive);
      final combined = extended.isEmpty ? raw : '$raw\n$extended';

      // Same conversion contract as the monitor path: raw transport output in,
      // ServerStatus (plus a trend sample) out
      final source = SshDataSource(spi: spi, runScript: () async => combined);
      updateStatus(await source.fetchStatus(_copyStatus(state.status)));
    } catch (e, trace) {
      _failSsh(
        SSHErrType.getStatus,
        e,
        message: 'Parse failed: $e\n\n$raw',
      );
      Loggers.app.warning('Server status', e, trace);
      return;
    }

    // Set Server.isBusy to false each time this method is called
    updateConnection(ServerConn.finished);
    // Reset retry count only after successful preparation
    TryLimiter.reset(sid);
  }

  /// Runs [ShellFunc.statusExt] when [_extendedStatusInterval] has elapsed
  /// (or [force], for a user-initiated refresh) and returns its output,
  /// falling back to the last successful one.
  ///
  /// Deliberately on the exec path rather than the persistent shell: these
  /// commands can take seconds, and a timeout there would drop the whole
  /// connection to exec for good (see [_runStatusCommand]).
  Future<String> _refreshExtendedRaw({required bool force}) async {
    final fetchedAt = _extendedFetchedAt;
    final due =
        force ||
        fetchedAt == null ||
        DateTime.now().difference(fetchedAt) >= _extendedStatusInterval;
    final client = state.client;
    if (!due || client == null) return _extendedRaw;

    // Stamped before the run, so a remote that can't answer (an older script
    // without the function, until the next connect reinstalls it) is retried
    // on the extended schedule instead of on every poll
    _extendedFetchedAt = DateTime.now();
    final spi = state.spi;
    try {
      final cmd = ShellFunc.statusExt.exec(
        spi.id,
        systemType: state.status.system,
        customDir: spi.custom?.scriptDir,
      );
      final raw = await _runStatusCommandWithExec(
        client,
        cmd,
        isWindows: state.status.system == SystemType.windows,
      );
      if (raw.contains(ScriptConstants.separator)) _extendedRaw = raw;
    } catch (e, s) {
      Loggers.app.warning('Extended status for ${spi.name} failed', e, s);
    }
    return _extendedRaw;
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

  bool _hasEnabledStatusCommands(Spi spi, SystemType system) {
    if (spi.custom?.cmds?.isNotEmpty == true) return true;
    final disabled = spi.disabledCmdTypes?.toSet() ?? const <String>{};
    final Iterable<ShellCmdType> commands = switch (system) {
      SystemType.linux => StatusCmdType.values,
      SystemType.bsd => BSDStatusCmdType.values,
      SystemType.windows => WindowsStatusCmdType.values,
    };
    return commands.any((command) => !disabled.contains(command.displayName));
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
