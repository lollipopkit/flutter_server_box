part of 'single.dart';

/// How long one command on this device may take before the poll gives up on
/// it. The bound the SSH path puts on its exec reads, for the same commands.
const _localCmdTimeout = Duration(seconds: 30);

/// Status of this device (`Spi.local`).
mixin _LocalStatus on _ScriptStatus {
  /// The same script the SSH path runs, started as a process here.
  ///
  /// What the SSH flow does minus the connection. There is no handshake to
  /// time or record, no session to register, and no `uname` round trip — the
  /// platform is known. What stays is the script, installed on the first poll
  /// and again after anything that clears [_scriptWritten], and the extended
  /// commands on their own schedule.
  Future<void> _refreshStatusLocal({
    required bool interactive,
    required int operation,
  }) async {
    final spi = state.spi;

    // Said on the card rather than attempted: a phone reading a server synced
    // from a desktop would otherwise run the desktop's script on itself.
    if (!LocalServer.isSupported) {
      _failLocal(
        LocalServerErrType.unsupported,
        'Local server on ${Pfs.type.name}',
        operation: operation,
        countAttempt: false,
      );
      return;
    }

    if (!_beginRefresh(spi)) return;
    if (state.conn < ServerConn.connecting) {
      updateConnection(ServerConn.connecting);
    }

    final system = spi.customSystemType ?? LocalServer.systemType;
    if (state.status.system != system) {
      // Whatever was installed was generated for the previous answer.
      _forgetInstalledScript(extended: false);
      updateStatus(_copyStatus(state.status, system: system));
    }

    final CommandExec exec;
    try {
      exec = await ensureScriptExec();
    } catch (e) {
      _failLocal(LocalServerErrType.writeScript, e, operation: operation);
      return;
    }
    if (!_isRefreshCurrent(operation, spi)) return;
    if (state.conn != ServerConn.finished) {
      updateConnection(ServerConn.loading);
    }

    final String raw;
    final int latencyMs;
    try {
      final elapsed = Stopwatch()..start();
      raw = await _runLocal(
        exec,
        ShellFunc.status.exec(
          spi.id,
          systemType: system,
          customDir: spi.custom?.scriptDir,
        ),
      );
      latencyMs = elapsed.elapsedMilliseconds;
      if (!_isRefreshCurrent(operation, spi)) return;
      // The script is gone from under the app — the default directory is a
      // temporary one, which the OS cleans on its own schedule. Reinstalled
      // on the next poll.
      if (!ffi.containsScriptSegment(raw: raw) &&
          _hasEnabledStatusCommands(spi, system)) {
        _forgetInstalledScript(extended: false);
        throw raw.isEmpty
            ? 'Empty response from this device'
            : 'No status segments in response, raw:\n$raw';
      }
    } catch (e) {
      _failLocal(LocalServerErrType.getStatus, e, operation: operation);
      return;
    }

    try {
      final extended = await _refreshExtendedRaw(
        force: interactive,
        operation: operation,
        run: (cmd) => _runLocal(exec, cmd),
      );
      final status = await _parseScriptStatus(spi, extended, raw);
      if (!_isRefreshCurrent(operation, spi)) return;
      updateStatus(status, latencyMs: latencyMs);
    } catch (e, s) {
      Loggers.app.warning('Local status', e, s);
      _failLocal(
        LocalServerErrType.getStatus,
        e,
        operation: operation,
        message: 'Parse failed: $e\n\n$raw',
      );
      return;
    }

    if (!_isRefreshCurrent(operation, spi)) return;
    updateConnection(ServerConn.finished);
    TryLimiter.reset(spi.id);
  }

  /// Runs [cmd] on this device and answers its stdout, stopping it after
  /// [_localCmdTimeout].
  ///
  /// Stdout alone, as the SSH status read takes it: on Windows, PowerShell
  /// writes progress records to stderr, and the parser reads one stream.
  Future<String> _runLocal(CommandExec exec, String cmd) async {
    final cancel = Completer<void>();
    final timer = Timer(_localCmdTimeout, cancel.complete);
    try {
      final result = await exec.run(cmd, cancel: cancel.future);
      if (cancel.isCompleted) {
        throw TimeoutException('Local command', _localCmdTimeout);
      }
      return result.stdout;
    } finally {
      timer.cancel();
    }
  }

  /// `_failSsh` for this device: the same bookkeeping minus the terminal
  /// session, which a local server never registers.
  void _failLocal(
    LocalServerErrType type,
    Object e, {
    required int operation,
    bool countAttempt = true,
    String? message,
  }) {
    if (!_isRefreshCurrent(operation, state.spi)) return;
    if (countAttempt) TryLimiter.inc(state.spi.id);
    final err = LocalServerErr(
      type: type,
      // The inner error's own words when it has them, such as the
      // [ScriptErr] `ensureScriptExec` throws.
      message: message ?? (e is Err ? e.message : null) ?? e.toString(),
    );
    _setFailedState(_copyStatus(state.status, err: err, setErr: true));
    Loggers.app.warning('Local ${state.spi.name}', err);
  }
}
