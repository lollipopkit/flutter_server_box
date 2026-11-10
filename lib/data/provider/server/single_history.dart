part of 'single.dart';

/// Trend data an agent stores for this server.
mixin _History on _MonitorStatus {
  /// The generation [seedHistory] last asked the source for, so each
  /// connection asks once however many places want the trend. Cleared when
  /// the asking fails, for the next poll to try again.
  int? _seededOperation;

  /// Prefills [ServerStatus.history] from whatever trend data the source
  /// already holds, so a freshly opened detail page shows a trend instead of
  /// building one up from scratch. A no-op for sources without
  /// [ServerCapabilities.storedHistory]; what is older than the first live
  /// sample goes before it — see [StatusHistory.seed]. Once per connection:
  /// `refresh` asks with every poll, and the page again when it opens.
  Future<void> seedHistory({int minutes = 60}) async {
    final generation = _operationGeneration;
    final spi = state.spi;
    // Whichever transport *has* history, not whichever leads. On a server
    // carrying both, SSH usually leads and has none — so asking only the
    // leading one meant `capabilities.storedHistory` advertised a trend the
    // page then never seeded, and the chart built up from empty exactly where
    // an agent had months of it.
    if (_seededOperation == generation) return;
    final credential = _historyCredential(spi);
    if (credential == null) return;
    _seededOperation = generation;
    try {
      // Asking for exactly what the buffer holds. Any more is averaged down
      // on the agent's side instead of being carried here and dropped by
      // [StatusHistory.seed] as it walks past the capacity.
      final samples = await _monitorSourceFor(
        credential,
      ).fetchHistory(minutes: minutes, maxPoints: StatusHistory.capacity);
      if (!_isRefreshCurrent(generation, spi)) return;
      if (samples.isEmpty) return;
      state.status.history.seed(samples);
      // history is mutated in place, so hand out a fresh ServerStatus to make
      // the watchers rebuild
      updateStatus(_copyStatus(state.status));
    } catch (e, s) {
      if (!_isRefreshCurrent(generation, spi)) return;
      _seededOperation = null;
      Loggers.app.warning('Seed history for ${spi.name}', e, s);
    }
  }

  /// The stored history of the last [minutes], as the source has it.
  ///
  /// Unlike [seedHistory] this leaves the rolling buffer alone: the page asks
  /// for a window to draw and holds the answer itself, so a longer window on
  /// screen never displaces what this app has watched happen. Empty when
  /// nothing here stores history — an SSH-only server has only the buffer.
  Future<List<StatusHistorySample>> fetchHistoryRange({
    required int minutes,
    int maxPoints = StatusHistory.capacity,
    DateTime? from,
    DateTime? to,
  }) async {
    final credential = _historyCredential(state.spi);
    if (credential == null) return const [];
    return _monitorSourceFor(credential).fetchHistory(
      minutes: minutes,
      maxPoints: maxPoints,
      from: from,
      to: to,
    );
  }

  /// The agent that stores [spi]'s history, the leading transport first;
  /// null when nothing does — an agent is the only thing that stores any.
  ServerConnectCredentialMonitorHttp? _historyCredential(Spi spi) {
    for (final c in [
      ServerConnectCredential.fromSpi(spi),
      ServerConnectCredential.fallbackOf(spi),
    ]) {
      if (c is ServerConnectCredentialMonitorHttp) return c;
    }
    return null;
  }
}
