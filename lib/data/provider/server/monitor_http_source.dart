import 'package:server_box/core/utils/monitor_exec.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/monitor_capabilities.dart';
import 'package:server_box/data/model/server/monitor_metrics_mapper.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/status_history.dart';
import 'package:server_box/data/provider/server/data_source.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

/// Reads status from a `monitor` agent's HTTP API.
///
/// Deliberately does NOT fall back to SSH on failure: a misconfigured or
/// unreachable monitor should surface as an error rather than silently
/// switching the user to a different data source with different semantics.
class MonitorHttpDataSource implements ServerDataSource {
  MonitorHttpDataSource(this.credential)
    : _client = MonitorHttpClient(credential.monitor);

  final ServerConnectCredentialMonitorHttp credential;
  final MonitorHttpClient _client;

  /// Whether this source was built from the same connection config, i.e.
  /// whether it can be reused across a refresh or must be rebuilt (and
  /// re-logged-in) instead.
  bool matches(ServerConnectCredentialMonitorHttp other) =>
      credential.monitor == other.monitor;

  /// Runs commands through the agent, on the session the status poll already
  /// authenticated — so the process list does not log in again per command.
  late final ServerExec exec = MonitorExec(_client);

  /// What the agent says it allows, and what it runs on.
  ///
  /// Cheap and already authenticated, so it rides along with the status poll
  /// rather than being a connect-time step that could go stale the moment the
  /// agent's config changes.
  Future<MonitorCapabilities> fetchCapabilities() => _client.fetchCapabilities();

  @override
  Future<ServerStatus> fetchStatus(ServerStatus into) async {
    final metrics = await _client.fetchStatus();
    final status = applyMonitorMetrics(into, metrics);
    status.history.add(
      // The agent's own sampling instant, not now(): it refreshes its metrics
      // once per collection cycle and the app polls faster than that, so
      // stamping receipt time would turn repeats into distinct points
      timeMs: _epochMs(metrics.timestamp) ??
          DateTime.now().millisecondsSinceEpoch,
      cpu: status.cpu.usedPercent(),
      mem: status.mem.total > 0 ? status.mem.usedPercent * 100 : null,
      disk: status.diskUsage?.usedPercent,
      netRx: status.netSpeed.speedInBytesOf(),
      netTx: status.netSpeed.speedOutBytesOf(),
      diskRead: status.diskIO.allSpeedBytes.$1,
      diskWrite: status.diskIO.allSpeedBytes.$2,
      temp: status.temps.first,
      temps: {
        for (final d in status.temps.devices) d: ?status.temps.get(d),
      },
      battery: status.batteries.firstOrNull?.percent?.toDouble(),
    );
    return status;
  }

  @override
  Future<List<StatusHistorySample>> fetchHistory({
    int minutes = 60,
    int maxPoints = StatusHistory.capacity,
  }) async {
    final points = await _client.fetchHistory(
      minutes: minutes,
      maxPoints: maxPoints,
    );
    return [
      for (final p in points)
        StatusHistorySample(
          timeMs: _epochMs(p.timestamp) ?? 0,
          cpu: p.cpu,
          mem: p.memory,
          disk: p.disk,
          netRx: p.netRxSpeed,
          netTx: p.netTxSpeed,
          diskRead: p.diskioReadSpeed,
          diskWrite: p.diskioWriteSpeed,
          temp: p.temperature,
          battery: p.batteryPercent,
        ),
    ];
  }

  @override
  void close() => _client.dispose();

  static int? _epochMs(String iso) =>
      DateTime.tryParse(iso)?.millisecondsSinceEpoch;
}
