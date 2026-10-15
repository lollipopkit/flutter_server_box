import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/monitor_stack.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/data/provider/server/single.dart';

part 'web_apps.g.dart';

/// The agent judges its apps' health every minute; reading more often shows
/// nothing new.
const _pollInterval = Duration(minutes: 1);

final class WebAppsState {
  const WebAppsState({this.offered = false, this.apps, this.error});

  /// Whether the server's agent has web apps to offer (its `stacks`
  /// feature), as far as this app has heard.
  final bool offered;

  /// Null until the first answer, and for a server whose agent has none to
  /// offer.
  final List<MonitorWebApp>? apps;

  /// Why the last read failed; [apps] keeps what came before.
  final String? error;
}

/// The web apps a server's `monitor` agent deployed (its `stacks` feature),
/// read while something shows them.
///
/// On the server's shared client ([MonitorClientLease]).
@riverpod
class WebAppsNotifier extends _$WebAppsNotifier {
  MonitorClientLease? _lease;
  MonitorHttpClient? get _client => _lease?.client;
  Timer? _timer;

  /// Rises on every rebuild, so an answer for a client that is gone is
  /// dropped.
  var _generation = 0;

  @override
  WebAppsState build(String serverId) {
    ref.onDispose(() {
      _generation++;
      _timer?.cancel();
      _timer = null;
      _lease?.release();
      _lease = null;
    });
    // The agent's own record, not the server's capabilities: a server with
    // both transports answers those as the union of the two, and this asks
    // the agent.
    final cred = ref.watch(serversProvider.select((s) => s.servers[serverId]?.monitorOn));
    final offered = ref.watch(
      serverProvider(serverId).select((s) => s.agentCapabilities?.features.contains('stacks') ?? false),
    );
    if (cred == null || !offered) return const WebAppsState();
    _lease = MonitorClientLease(cred);
    unawaited(refresh());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
    return const WebAppsState(offered: true);
  }

  Future<void> refresh() async {
    final client = _client;
    if (client == null) return;
    final generation = _generation;
    try {
      final apps = await client.stacks();
      if (generation != _generation) return;
      state = WebAppsState(offered: true, apps: apps);
    } catch (e) {
      if (generation != _generation) return;
      state = WebAppsState(offered: true, apps: state.apps, error: e.toString());
    }
  }

  /// Where a browser opens app [id]: a fresh single-use ticket into the
  /// agent's proxy, good for seconds. Null when the agent is not followed.
  Future<Uri?> enter(String id) async {
    final client = _client;
    if (client == null) return null;
    final entry = await client.stackEnter(id);
    return entry.uri(client.agentUri);
  }
}
