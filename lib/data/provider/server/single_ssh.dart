part of 'single.dart';

/// Status over SSH: connect, install the script, read and apply it.
mixin _SshStatus on _ScriptStatus {
  PersistentShell? _persistentShell;
  bool _usePersistentShellForStatus = true;

  String get _sshSessionId => 'ssh_${state.spi.id}';

  /// The failure ritual every SSH branch repeated: count the attempt against
  /// the retry limiter, record the error on the status, drop to `failed`, and
  /// mark the terminal session dead. Nine copies of it made the actual control
  /// flow of `_refreshStatusSsh` hard to see, and each copy was a chance to forget
  /// one of the four steps.
  ///
  /// [countAttempt] is false for the one case that must not burn a retry:
  /// a connection that only failed because keyboard-interactive auth needed a
  /// prompt this non-interactive refresh could not show.
  ///
  /// [operation] is checked here rather than at each call site: a `catch` is
  /// reached by throwing out of an `await`, so it skips whatever currency
  /// check follows that await. Edit a server's address and the connection
  /// still being attempted against the old one eventually fails; without this
  /// it counted against the retry limiter and marked the server failed,
  /// undoing the refresh the corrected address had already completed.
  void _failSsh(
    SSHErrType type,
    Object? e, {
    StackTrace? stack,
    required int operation,
    bool closeClient = false,
    bool countAttempt = true,
    String? message,
  }) {
    if (!_isRefreshCurrent(operation, state.spi)) {
      Loggers.app.info('SSH ${state.spi.name}: dropping a superseded failure');
      return;
    }
    if (countAttempt) TryLimiter.inc(state.spi.id);
    final err = SSHErr(type: type, message: message ?? '$e', cause: e);
    _setFailedState(
      _copyStatus(state.status, err: err, setErr: true),
      closeClient: closeClient,
    );
    TermSessionManager.updateStatus(
      _sshSessionId,
      TermSessionStatus.disconnected,
    );
    Loggers.app.warning('SSH ${state.spi.name}: ${err.message}', e ?? err, stack);
  }

  /// Whether [client]'s server answers a keep-alive within the status timeout.
  Future<bool> _answersPing(SSHClient client) async {
    if (client.isClosed) return false;
    try {
      await client.ping().timeout(_timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// One SSH refresh: connect and install the script when there is no live
  /// client, then read the status and apply it. Each phase answers whether
  /// the refresh goes on; one that stops has already recorded why.
  Future<void> _refreshStatusSsh({
    required bool interactive,
    required int operation,
  }) async {
    final spi = state.spi;
    if (!_beginRefresh(spi)) return;

    if (state.conn < ServerConn.connecting || (state.client?.isClosed ?? true)) {
      updateConnection(ServerConn.connecting);
      if (!await _connectSsh(spi, interactive: interactive, operation: operation)) return;
      updateConnection(ServerConn.connected);
      TermSessionManager.updateStatus(_sshSessionId, TermSessionStatus.connected);
      if (!await _installScriptSsh(spi, operation: operation)) return;
    }

    if (state.conn == ServerConn.connecting) return;

    // Keep finished status to prevent UI from refreshing to loading state
    if (state.conn != ServerConn.finished) {
      updateConnection(ServerConn.loading);
    }

    final read = await _readStatusSsh(spi, operation: operation);
    if (read == null) return;
    if (!await _applyStatusSsh(spi, read.raw, latencyMs: read.latencyMs, interactive: interactive, operation: operation)) {
      return;
    }

    if (!_isRefreshCurrent(operation, spi)) return;
    // A successful refresh leaves the connection ready for the next poll.
    updateConnection(ServerConn.finished);
    // Reset retries only after status preparation succeeds.
    TryLimiter.reset(spi.id);
  }

  /// Wakes [spi] when it has a WOL config, connects, records the attempt and
  /// registers the terminal session. False when the refresh stops here.
  Future<bool> _connectSsh(Spi spi, {required bool interactive, required int operation}) async {
    var keyboardInteractiveRequested = false;

    final wol = spi.wolCfg;
    if (wol != null) {
      try {
        await wol.wake();
      } catch (e) {
        Loggers.app.warning('Wake on lan failed', e);
      }
      if (!_isRefreshCurrent(operation, spi)) return false;
    }

    // Two clocks on purpose. [startedAt] is when this happened and is stored
    // as such; [elapsed] is how long it took. Reading the wall clock twice and
    // subtracting gets the second answer wrong whenever the first one moves
    // — an NTP step during a connect is not rare, since a reconnect is what
    // a device does on waking, and it lands in `durationMs` as a negative.
    final startedAt = DateTime.now();
    final elapsed = Stopwatch()..start();
    try {
      final client = await genClient(
        spi,
        timeout: _timeout,
        onKeyboardInteractive: (server, request) {
          keyboardInteractiveRequested = true;
          if (!interactive) return null;
          return KeyboardInteractiveAuth.handle(server, request);
        },
      );
      await client.authenticated;
      if (!_isRefreshCurrent(operation, spi)) {
        client.close();
        return false;
      }
      _setClient(client);

      final spentTime = elapsed.elapsedMilliseconds;
      if (spi.resolvedJumpIds.isEmpty) {
        Loggers.app.info('Connected to ${spi.name} in $spentTime ms.');
      } else {
        Loggers.app.info('Jump to ${spi.name} in $spentTime ms.');
      }
      _recordConnection(spi, startedAt, ConnectionResult.success, durationMs: spentTime);
      if (!_isRefreshCurrent(operation, spi)) return false;

      TermSessionManager.add(
        id: _sshSessionId,
        title: spi.name,
        subtitle: spi.oldId,
        startTimeMs: startedAt.millisecondsSinceEpoch,
        disconnect: () => ref.read(serversProvider.notifier).closeOneServer(spi.id),
        status: TermSessionStatus.connecting,
        setAsActive: false,
      );
      TermSessionManager.setActive(_sshSessionId, hasTerminal: false);
      return true;
    } catch (e) {
      if (!_isRefreshCurrent(operation, spi)) return false;
      final needsPrompt = keyboardInteractiveRequested && !interactive;
      if (!needsPrompt) TryLimiter.inc(spi.id);

      _recordConnection(
        spi,
        startedAt,
        ConnectionResult.fromError(e),
        durationMs: elapsed.elapsedMilliseconds,
        error: e,
      );
      if (!_isRefreshCurrent(operation, spi)) return false;

      final errType = needsPrompt
          ? SSHErrType.interactiveAuth
          : e is SSHAuthError
          ? SSHErrType.auth
          : SSHErrType.connect;
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
      return false;
    }
  }

  void _recordConnection(
    Spi spi,
    DateTime at,
    ConnectionResult result, {
    required int durationMs,
    Object? error,
  }) {
    try {
      Stores.connectionStats.recordConnection(
        ConnectionStat(
          serverId: spi.id,
          serverName: spi.name,
          timestamp: at,
          result: result,
          errorMessage: error?.toString() ?? '',
          durationMs: durationMs,
        ),
      );
    } catch (e) {
      Loggers.app.warning('Failed to record the connection', e);
    }
  }

  /// Detects the system, writes the status script and the custom commands.
  /// False when the refresh stops here.
  Future<bool> _installScriptSsh(Spi spi, {required int operation}) async {
    try {
        // Detect system type
        final detectedSystemType = await SystemDetector.detect(
          state.client!,
          spi,
        );
        if (!_isRefreshCurrent(operation, spi)) return false;
        final newStatus = _copyStatus(state.status, system: detectedSystemType);
        updateStatus(newStatus);

        Loggers.app.info(
          'Writing script for ${spi.name} (${detectedSystemType.name})',
        );

        final writeScriptResult = await state.client!.execSafe(
          (session) async {
            final scriptRaw = ShellFuncManager.installPayload(
              ShellFuncManager.allScript(
                systemType: detectedSystemType,
                disabledCmdTypes: spi.disabledCmdTypes,
              ),
              systemType: detectedSystemType,
            ).uint8List;
            session.stdin.add(scriptRaw);
            unawaited(session.stdin.close());
          },
          entry: ShellFuncManager.getInstallShellCmd(
            spi.id,
            systemType: detectedSystemType,
            customDir: spi.custom?.scriptDir,
          ),
          systemType: detectedSystemType,
          logLabel: 'WriteScript<${spi.name}>',
        );
        if (!_isRefreshCurrent(operation, spi)) return false;

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
          throw CommandFailed('script installation', writeScriptResult);
        } else {
          Loggers.app.info('Script written successfully for ${spi.name}');
          _scriptWritten = true;
        }
      return true;
    } on SSHAuthAbortError catch (e) {
      _failSsh(SSHErrType.auth, e, operation: operation, closeClient: true);
    } on SSHAuthFailError catch (e) {
      _failSsh(SSHErrType.auth, e, operation: operation, closeClient: true);
    } catch (e, s) {
      _failSsh(
        SSHErrType.writeScript,
        e,
        stack: s,
        operation: operation,
        closeClient: true,
      );
    }
    return false;
  }

  /// Runs the status command. Null when the refresh stops here: a reply with
  /// no segments, a timeout, or a failure, each already recorded.
  Future<({String raw, int? latencyMs})?> _readStatusSsh(Spi spi, {required int operation}) async {
    // The status command and nothing after it: the extended commands take
    // seconds by design and run once every few minutes, so including them
    // would report one poll in five as an unreachable machine.
    try {
      final statusCmd = ShellFunc.status.exec(
        spi.id,
        systemType: state.status.system,
        customDir: spi.custom?.scriptDir,
      );
      final read = await _runStatusCommand(statusCmd);
      final raw = read.raw;
      if (!_isRefreshCurrent(operation, spi)) return null;

      // Output carrying no segment marker parses into an empty status: the
      // page keeps whatever its rolling state still holds (cpu, net speeds)
      // and blanks the rest, with nothing saying why. It is what a host
      // answers once the script is gone from under it — the default script
      // directory is /tmp — so it is reported as a failure, which puts the
      // connection back through the connect path and reinstalls the script.
      //
      // Was `raw.split(separator).isEmpty`, which `String.split` never
      // returns: unparseable output reached the parser as if it were fine.
      //
      // Custom commands carry their own separator, and with every built-in
      // command disabled they are the only output there is.
      //
      // Empty output is only a failure if the server was asked for anything.
      // A host with every status command disabled legitimately returns nothing.
      final hasSegment = ffi.containsScriptSegment(raw: raw);
      if (!hasSegment && _hasEnabledStatusCommands(spi, state.status.system)) {
        if (Stores.setting.keepStatusWhenErr.fetch()) {
          // Keep previous server status when error occurs.
          //
          // The latency goes with it, deliberately: this setting asks for the
          // last good reading to stay on screen, and the delay is part of that
          // reading rather than a separate claim about right now.
          if (state.conn != ServerConn.failed && state.status.more.isNotEmpty) {
            return null;
          }
        }
        _failSsh(
          SSHErrType.segments,
          null,
          operation: operation,
          message: raw.isEmpty
              ? 'Empty response from server'
              : 'No status segments in response, raw:\n$raw',
        );
        return null;
      }
      return (raw: raw, latencyMs: read.elapsedMs);
    } on TimeoutException catch (e, s) {
      Loggers.app.warning('Get status from ${spi.name} timed out', e, s);
      // Reached by throwing out of an await, so it skips the check that
      // follows that await: a read that timed out against the address this
      // server used to have must not stamp its error onto the one it has now.
      if (!_isRefreshCurrent(operation, spi)) return null;
      // A slow command and a dead connection both end here, and only the
      // second one is worth dropping. sshd answers a keep-alive itself, however
      // busy the command is; no answer is a connection the network dropped —
      // after a suspension, typically — which `ensureExec` and
      // `ensureShellClient` would otherwise go on handing out.
      final client = state.client;
      if (client != null && !await _answersPing(client)) {
        if (!_isRefreshCurrent(operation, spi)) return null;
        _failSsh(
          SSHErrType.getStatus,
          e,
          operation: operation,
          closeClient: true,
          // The server did nothing wrong: the next refresh reconnects, and
          // the limiter is for when that fails.
          countAttempt: false,
        );
        return null;
      }
      if (!_isRefreshCurrent(operation, spi)) return null;
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
      TermSessionManager.updateStatus(
        _sshSessionId,
        TermSessionStatus.connected,
      );
      return null;
    } catch (e, s) {
      _failSsh(SSHErrType.getStatus, e, stack: s, operation: operation);
      return null;
    }

  }

  /// Adds the extended status and parses both into the server's status.
  /// False when the refresh stops here.
  Future<bool> _applyStatusSsh(
    Spi spi,
    String raw, {
    required int? latencyMs,
    required bool interactive,
    required int operation,
  }) async {
    try {
      // Segments the status function no longer carries, refreshed on their own
      // schedule and concatenated here: the parser splits by separator, so one
      // combined output parses exactly as the two runs would have
      final client = state.client;
      final extended = await _refreshExtendedRaw(
        force: interactive,
        operation: operation,
        // Timing discarded: the extended commands take seconds by design, and
        // what is wanted from them is their output.
        run: client == null
            ? null
            : (cmd) async => (await _runStatusCommandWithExec(
                client,
                cmd,
                isWindows: state.status.system == SystemType.windows,
              )).raw,
      );
      final status = await _parseScriptStatus(spi, extended, raw);
      // The last two awaits are the longest in this method — the extended
      // commands take seconds by design. A refresh that started before the
      // server was edited arrives here holding the old host's status.
      if (!_isRefreshCurrent(operation, spi)) return false;
      updateStatus(status, latencyMs: latencyMs);
      return true;
    } catch (e, trace) {
      _failSsh(
        SSHErrType.getStatus,
        e,
        operation: operation,
        message: 'Parse failed: $e\n\n$raw',
      );
      Loggers.app.warning('Server status', e, trace);
      return false;
    }

  }

  /// The status command's output, and how long the command itself took.
  ///
  /// Timed here rather than around the call, because this is the only place
  /// that knows which of the steps it takes is the request. The persistent
  /// shell opens its session on the first `run` after every connect — a
  /// channel open plus the remote shell's startup — and timed with the command
  /// that made the first reading of every connection a multiple of the ones
  /// after it, with nothing on screen explaining the drop.
  ///
  /// [elapsedMs] is null when there was nothing to time.
  Future<({String raw, int? elapsedMs})> _runStatusCommand(
    String statusCmd,
  ) async {
    final client = state.client;
    final spi = state.spi;

    if (client == null) {
      Loggers.app.warning(
        'Client for ${spi.name} is null, skipping status fetch',
      );
      return (raw: '', elapsedMs: null);
    }

    if (state.status.system == SystemType.windows) {
      return _runStatusCommandWithExec(client, statusCmd, isWindows: true);
    }

    if (!_usePersistentShellForStatus) {
      return _runStatusCommandWithExec(client, statusCmd);
    }

    try {
      final shell = await _getPersistentShell();
      await shell.ensureSession();
      final elapsed = Stopwatch()..start();
      final result = await shell.run(statusCmd, timeout: _timeout);
      elapsed.stop();
      return (raw: result.output, elapsedMs: elapsed.elapsedMilliseconds);
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

  /// The whole call is timed, unlike the persistent shell's: `run` opens a
  /// channel per command here, so that cost is part of every reading rather
  /// than of the first one.
  Future<({String raw, int? elapsedMs})> _runStatusCommandWithExec(
    SSHClient client,
    String statusCmd, {
    bool isWindows = false,
  }) async {
    final spi = state.spi;
    // Windows PowerShell serializes progress and information records (including
    // Write-Host) as CLIXML on stderr when invoked with -EncodedCommand. Status
    // parsing is a stdout protocol: merging stderr lets those records land in
    // whichever SrvBoxSep section happened to be current when the SSH chunks
    // arrived, so an <Objs> document could become the system name or an IP.
    final elapsed = Stopwatch()..start();
    final execResult = await client
        .run(statusCmd, stderr: false)
        .timeout(const Duration(seconds: 30));
    elapsed.stop();
    return (
      raw: SSHDecoder.decode(
        execResult,
        isWindows: isWindows,
        context: 'GetStatus<${spi.name}>',
      ),
      elapsedMs: elapsed.elapsedMilliseconds,
    );
  }

  Future<PersistentShell> _getPersistentShell() async {
    final client = state.client;
    if (client == null) {
      throw const SSHErr(
        type: SSHErrType.connect,
        message: 'SSH client is not connected',
      );
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
