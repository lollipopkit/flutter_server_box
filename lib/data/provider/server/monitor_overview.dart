import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/monitor_overview.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/data/provider/server/single.dart';

part 'monitor_overview.g.dart';

/// The agent checks its rules once a sampling cycle and a notification is
/// written when one starts; a minute is as fresh as the tab needs.
const _pollInterval = Duration(minutes: 1);

final class MonitorOverviewState {
  const MonitorOverviewState({this.features = const {}, this.alerts, this.notices, this.update, this.error});

  /// What the agent offers of `alerts`, `audit`, `live`, `desk` (its
  /// notifications) and `update`, as its capabilities said; empty for an
  /// agent too old for any of them, or none heard from yet.
  final Set<String> features;

  /// Null until the first answer, and when the agent has no `alerts`.
  final MonitorAlerts? alerts;

  /// Null until the first answer, and when the agent has no `desk`.
  final MonitorNotices? notices;

  /// Null until the first answer, and when the agent has no `update`.
  final MonitorUpdate? update;

  /// Why the last read failed; what came before is kept.
  final String? error;

  bool offers(String feature) => features.contains(feature);

  MonitorOverviewState copyWith({
    MonitorAlerts? alerts,
    MonitorNotices? notices,
    MonitorUpdate? update,
    String? error,
  }) => MonitorOverviewState(
    features: features,
    alerts: alerts ?? this.alerts,
    notices: notices ?? this.notices,
    update: update ?? this.update,
    error: error,
  );
}

/// One server's `monitor` agent for the Monitor tab: its firing rules and
/// notifications, polled while something shows them, and the audit log and
/// what is open on it, read when asked. On the server's shared client
/// ([MonitorClientLease]).
@riverpod
class MonitorOverviewNotifier extends _$MonitorOverviewNotifier {
  static const watched = {'alerts', 'audit', 'live', 'desk', 'update'};

  /// What [refresh] polls; `audit` and `live` are read when asked.
  static const _polled = {'alerts', 'desk', 'update'};

  MonitorClientLease? _lease;
  MonitorHttpClient? get _client => _lease?.client;
  Timer? _timer;

  /// What this build found the agent offers. A field rather than read off
  /// [state]: [build]'s first [refresh] runs before there is a state.
  Set<String> _features = const {};

  /// Rises on every rebuild, so an answer for a client that is gone is
  /// dropped.
  var _generation = 0;

  @override
  MonitorOverviewState build(String serverId) {
    ref.onDispose(() {
      _generation++;
      _timer?.cancel();
      _timer = null;
      _lease?.release();
      _lease = null;
    });
    final cred = ref.watch(serversProvider.select((s) => s.servers[serverId]?.monitorOn));
    // A string, which compares by value: a set built in the selector is a
    // new one on every status poll, and rebuilt this — a new client, a new
    // sign-in — every few seconds.
    final offered = ref.watch(
      serverProvider(serverId).select(
        (s) => ([...?s.agentCapabilities?.features.where(watched.contains)]..sort()).join(','),
      ),
    );
    final features = offered.isEmpty ? const <String>{} : offered.split(',').toSet();
    _features = features;
    if (cred == null || features.isEmpty) return const MonitorOverviewState();
    _lease = MonitorClientLease(cred);
    // Nothing to poll would set the state before this returns one.
    if (features.any(_polled.contains)) {
      unawaited(refresh());
      _timer = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
    }
    return MonitorOverviewState(features: features);
  }

  MonitorHttpClient get _required {
    final client = _client;
    if (client == null) throw StateError('No monitor agent for $serverId');
    return client;
  }

  Future<void> refresh() async {
    final client = _client;
    if (client == null || !_features.any(_polled.contains)) return;
    final generation = _generation;
    try {
      // One after the other: the first signs the client in, and two at once
      // would both find it signed out.
      final alerts = _features.contains('alerts') ? await client.alerts() : null;
      final notices = _features.contains('desk') ? await client.notices() : null;
      final update = _features.contains('update') ? await client.update() : null;
      if (generation != _generation) return;
      state = state.copyWith(alerts: alerts, notices: notices, update: update);
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(error: '$e');
    }
  }

  /// Marks [ids] read here at once, then on the agent; every one with [all].
  Future<void> markRead({List<int> ids = const [], bool all = false}) async {
    final notices = state.notices;
    if (notices != null) {
      final read = all ? null : ids.toSet();
      final marked = [
        for (final n in notices.notices) (read == null || read.contains(n.id)) ? n.markedRead() : n,
      ];
      state = state.copyWith(
        notices: MonitorNotices(notices: marked, unread: marked.where((n) => !n.read).length),
      );
    }
    await _required.markNoticesRead(ids: ids, all: all);
  }

  Future<MonitorAuditPage> audit({int? before, String? kind, String? result}) =>
      _required.audit(before: before, kind: kind, result: result);

  Future<MonitorLive> live() => _required.live();

  /// Has the agent read its releases again (at most once a minute).
  Future<void> checkUpdate() async {
    final generation = _generation;
    final update = await _required.update(check: true);
    if (generation == _generation) state = state.copyWith(update: update);
  }

  Future<void> endSession(String id) => _required.endSession(id);

  Future<void> endConnection(String id) => _required.endConnection(id);

  Future<void> forgetDevice(int id) => _required.forgetDevice(id);

  Future<void> revokeWatchToken(String clientId) => _required.revokeWatchToken(clientId);
}
