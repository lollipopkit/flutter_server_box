import 'package:server_box/core/monitor/exec.dart';
import 'package:server_box/core/monitor/http.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/monitor/monitor_capabilities.dart';
import 'package:server_box/data/model/server/monitor/monitor_metrics.dart';
import 'package:server_box/data/model/server/monitor/monitor_metrics_mapper.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/status/status_history.dart';
import 'package:server_box/data/provider/server/data_source.dart';

/// Reads status from a `monitor` agent's HTTP API.
///
/// Deliberately does NOT fall back to SSH on failure: a misconfigured or
/// unreachable monitor should surface as an error rather than silently
/// switching the user to a different data source with different semantics.
class MonitorHttpDataSource implements ServerDataSource {
  MonitorHttpDataSource(this.credential)
    : _lease = MonitorClientLease(credential.monitor);

  final ServerConnectCredentialMonitorHttp credential;
  final MonitorClientLease _lease;
  MonitorHttpClient get _client => _lease.client;

  /// Whether this source was built from the same connection config, i.e.
  /// whether it can be reused across a refresh or must be rebuilt (and
  /// re-logged-in) instead.
  bool matches(ServerConnectCredentialMonitorHttp other) =>
      credential.monitor == other.monitor;

  /// Runs commands through the agent, on the session the status poll already
  /// authenticated — so the process list does not log in again per command.
  late final CommandExec exec = MonitorExec(_client);

  /// What the agent says it allows, and what it runs on.
  ///
  /// Cheap and already authenticated, so it rides along with the status poll
  /// rather than being a connect-time step that could go stale the moment the
  /// agent's config changes.
  Future<MonitorCapabilities> capabilities() => _client.capabilities();

  /// How long the last [fetchStatus] spent on its request, in milliseconds.
  ///
  /// The request and nothing else. What follows it here — the mapping and the
  /// history append — is Dart on the isolate drawing frames, and counting it
  /// as a network reading reports a fast agent on a fast network as a slow
  /// one. Null until the first call, and describes the last one.
  int? get lastRequestMs => _lastRequestMs;
  int? _lastRequestMs;

  @override
  Future<ServerStatus> fetchStatus(ServerStatus into) async {
    final request = Stopwatch()..start();
    final metrics = await _client.metrics();
    request.stop();
    _lastRequestMs = request.elapsedMilliseconds;
    final status = applyMonitorMetrics(into, metrics);
    status.recordSample(
      // The agent's own sampling instant, not now(): it refreshes its metrics
      // once per collection cycle and the app polls faster than that, so
      // stamping receipt time would turn repeats into distinct points
      timeMs:
          _epochMs(metrics.timestamp) ?? DateTime.now().millisecondsSinceEpoch,
    );
    return status;
  }

  @override
  Future<List<StatusHistorySample>> fetchHistory({
    int minutes = 60,
    int maxPoints = StatusHistory.capacity,
    DateTime? from,
    DateTime? to,
  }) async {
    final points = await _client.history(
      minutes: minutes,
      maxPoints: maxPoints,
      from: from,
      to: to,
    );
    return [
      for (final p in points)
        StatusHistorySample(
          timeMs: _epochMs(p.timestamp) ?? 0,
          cpu: p.cpu,
          mem: p.memory,
          swap: p.swap,
          disk: p.disk,
          netRx: p.netRxSpeed,
          netTx: p.netTxSpeed,
          diskRead: p.diskioReadSpeed,
          diskWrite: p.diskioWriteSpeed,
          gpu: _busiestGpuUsage(p.gpus),
          temp: p.temperature,
          battery: p.batteryPercent,
          temps: p.temps.isEmpty
              ? null
              : {for (final t in p.temps) t.device: t.celsius},
          netRxs: p.ifaces.isEmpty
              ? null
              : {for (final i in p.ifaces) i.name: i.rxBytesPerSec},
          netTxs: p.ifaces.isEmpty
              ? null
              : {for (final i in p.ifaces) i.name: i.txBytesPerSec},
          mounts: p.mounts.isEmpty
              ? null
              : [
                  for (final m in p.mounts)
                    (mount: m.mount, used: m.used, total: m.total),
                ],
          gpus: p.gpus.isEmpty
              ? null
              : [
                  for (final g in p.gpus)
                    (
                      id: g.id,
                      name: g.name,
                      usagePercent: g.usagePercent,
                      memoryUsed: g.memoryUsed,
                      memoryTotal: g.memoryTotal,
                    ),
                ],
        ),
    ];
  }

  static double? _busiestGpuUsage(List<MonitorHistoryGpu> gpus) {
    double? top;
    for (final g in gpus) {
      final u = g.usagePercent;
      if (u != null && (top == null || u > top)) {
        top = u;
      }
    }
    return top;
  }

  @override
  void close() => _lease.release();

  static int? _epochMs(String iso) =>
      DateTime.tryParse(iso)?.millisecondsSinceEpoch;
}
