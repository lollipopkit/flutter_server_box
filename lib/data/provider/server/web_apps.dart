import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/monitor_stack.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/agent_poll.dart';
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
@riverpod
class WebAppsNotifier extends _$WebAppsNotifier {
  AgentPoll? _poll;

  @override
  WebAppsState build(String serverId) {
    _poll = null;
    // The agent's own record, not the server's capabilities: a server with
    // both transports answers those as the union of the two, and this asks
    // the agent.
    final cred = ref.watch(serversProvider.select((s) => s.servers[serverId]?.monitorOn));
    final offered = ref.watch(
      serverProvider(serverId).select((s) => s.agentCapabilities?.features.contains('stacks') ?? false),
    );
    if (cred == null || !offered) return const WebAppsState();
    final poll = _poll = AgentPoll(cred, every: _pollInterval, read: _read);
    ref.onDispose(() {
      poll.dispose();
      _poll = null;
    });
    return const WebAppsState(offered: true);
  }

  Future<void> refresh() => _poll?.refresh() ?? Future.value();

  Future<void> _read(MonitorHttpClient client, bool Function() current) async {
    try {
      final apps = await client.stacks();
      if (current()) state = WebAppsState(offered: true, apps: apps);
    } catch (e) {
      if (current()) state = WebAppsState(offered: true, apps: state.apps, error: e.toString());
    }
  }

  /// Where a browser opens app [id]: a fresh single-use ticket into the
  /// agent's proxy, good for seconds. Null when the agent is not followed.
  Future<Uri?> enter(String id) async {
    final client = _poll?.client;
    if (client == null) return null;
    final entry = await client.stackEnter(id);
    return entry.uri(client.agentUri);
  }
}
