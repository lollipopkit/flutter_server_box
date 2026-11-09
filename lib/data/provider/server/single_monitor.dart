part of 'single.dart';

/// Status from a `monitor` agent's HTTP API.
mixin _MonitorStatus on _ScriptStatus {
  /// The agent's source, cached: it owns a `Dio` session and a login token,
  /// so reusing it across refreshes avoids re-authenticating. Rebuilt when the
  /// agent's connection config changes. SSH and local read through a
  /// [ScriptDataSource] made per refresh, as what it reads through is this
  /// notifier's.
  MonitorHttpDataSource? _monitorSource;

  /// The agent's source for [credential], the cached one while it still
  /// matches — see [_monitorSource].
  MonitorHttpDataSource _monitorSourceFor(
    ServerConnectCredentialMonitorHttp credential,
  ) {
    final existing = _monitorSource;
    if (existing != null && existing.matches(credential)) return existing;
    existing?.close();
    return _monitorSource = MonitorHttpDataSource(credential);
  }

  /// Status polling via a `monitor` instance's HTTP API instead of SSH+shell
  /// (see `Spi.monitorHttp`). Deliberately does NOT fall back to SSH on
  /// failure — a misconfigured/unreachable monitor should surface as an
  /// error, not silently switch data sources.
  Future<void> _refreshStatusMonitorHttp(
    MonitorHttpCredential monitor,
    int operation,
  ) async {
    final spi = state.spi;
    final sid = spi.id;

    if (!_beginRefresh(spi)) return;
    if (state.conn < ServerConn.connecting) {
      updateConnection(ServerConn.connecting);
    }
    if (state.conn != ServerConn.finished) {
      updateConnection(ServerConn.loading);
    }

    final source = _monitorSourceFor(
      ServerConnectCredentialMonitorHttp(spi: spi, monitor: monitor),
    );

    try {
      final status = await source.fetchStatus(_copyStatus(state.status));
      if (!_isRefreshCurrent(operation, spi)) return;
      // Timed by the source, which is the only place that can tell the request
      // apart from the mapping it does on the answer. Timed from here it would
      // be the sum of the two, plus — had the stopwatch run past this line —
      // a synchronous SQLite write and a full rebuild pass.
      updateStatus(status, latencyMs: source.lastRequestMs);
      // Alongside the status rather than once at connect: what the agent
      // allows is its own config, which can change under a running app, and
      // this poll is already authenticated and periodic. A failure here is
      // not a failure of the status — the app simply keeps the last answer,
      // or offers nothing until there is one.
      try {
        final caps = await source.capabilities();
        // The server may have been edited while this was in flight, in which
        // case this answer describes the agent it used to point at — and the
        // platform it reports decides which script gets installed.
        if (!_isRefreshCurrent(operation, spi)) return;
        state = state.copyWith(
          agentAccess: caps.access,
          agentVersion: caps.version,
          agentCapabilities: caps,
        );
        // The agent knows what it is running on. Over SSH this takes a
        // command and its output; here it arrives with the answer the app
        // was already asking for, and it decides which script gets
        // installed on the machine.
        final platform = caps.platform;
        if (platform != null && state.status.system != platform) {
          // The script that was written is the other platform's, and the
          // command about to run it is this platform's.
          _forgetInstalledScript(extended: false);
          updateStatus(_copyStatus(state.status, system: platform));
        }
      } catch (e, s) {
        Loggers.app.warning('Ask ${spi.name} what it allows', e, s);
      }

      if (!_isRefreshCurrent(operation, spi)) return;
      updateConnection(ServerConn.finished);
      TryLimiter.reset(sid);
      _registerMonitorSession(spi, monitor);
    } catch (e, s) {
      Loggers.app.warning('Get status via monitor for ${spi.name} failed', e, s);
      // A failure belongs to the server it was fetched for. Edit a server's
      // address and the poll still running against the old one eventually
      // times out; without this it counted that timeout against the retry
      // limiter and marked the server failed — overwriting the answer the
      // corrected address had already produced, so a fixed server went back
      // to looking broken a few seconds later.
      if (!_isRefreshCurrent(operation, spi)) return;
      TryLimiter.inc(sid);
      final err = e is MonitorHttpErr
          ? e
          : MonitorHttpErr(
              type: MonitorHttpErrType.unknown,
              message: e.toString(),
            );
      _setFailedState(_copyStatus(state.status, err: err, setErr: true));
      TermSessionManager.updateStatus(_statusSessionId, TermSessionStatus.disconnected);
    }
  }

  /// Lists the agent's connection with the SSH ones, once it answers.
  void _registerMonitorSession(Spi spi, MonitorHttpCredential monitor) {
    final id = _statusSessionId;
    if (TermSessionManager.contains(id)) {
      TermSessionManager.updateStatus(id, TermSessionStatus.connected);
      return;
    }
    TermSessionManager.add(
      id: id,
      title: spi.name,
      subtitle: monitor.addr,
      serverId: spi.id,
      startTimeMs: DateTime.now().millisecondsSinceEpoch,
      disconnect: () => ref.read(serversProvider.notifier).closeOneServer(spi.id),
      status: TermSessionStatus.connected,
      hasTerminal: false,
    );
  }
}
