import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/monitor_desk_app.dart';
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
  const WebAppsState({this.offered = false, this.apps, this.deskApps, this.error});

  /// Whether the server's agent has apps to offer (its `stacks` or `desk`
  /// feature), as far as this app has heard.
  final bool offered;

  /// Null until the first answer, and for a server whose agent has none to
  /// offer.
  final List<MonitorWebApp>? apps;

  /// The apps installed on its desk (`desk`), opened in the panel; null as
  /// [apps] is.
  final List<MonitorDeskApp>? deskApps;

  /// Why the last read failed; [apps] keeps what came before.
  final String? error;
}

/// The web apps a server's `monitor` agent deployed (its `stacks` feature)
/// and the apps installed on its desk (`desk`), read while something shows
/// them.
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
    // The two answers, not the set: the capabilities are read again with
    // every status poll, a new set each time, and a set is equal only to
    // itself — so selecting it rebuilt this every few seconds, dropping the
    // apps (the card gone, the page under a reader's finger shorter) until
    // the next read brought them back.
    final (:stacks, :desk) = ref.watch(
      serverProvider(serverId).select((s) {
        final features = s.agentCapabilities?.features;
        return (stacks: features?.contains('stacks') ?? false, desk: features?.contains('desk') ?? false);
      }),
    );
    if (cred == null || !(stacks || desk)) return const WebAppsState();
    final poll = _poll = AgentPoll(cred, every: _pollInterval, read: (client, current) => _read(client, current, stacks: stacks, desk: desk));
    ref.onDispose(() {
      poll.dispose();
      _poll = null;
    });
    return const WebAppsState(offered: true);
  }

  Future<void> refresh() => _poll?.refresh() ?? Future.value();

  Future<void> _read(MonitorHttpClient client, bool Function() current, {required bool stacks, required bool desk}) async {
    try {
      final apps = stacks ? await client.stacks() : const <MonitorWebApp>[];
      final deskApps = desk ? await client.deskApps() : const <MonitorDeskApp>[];
      if (current()) state = WebAppsState(offered: true, apps: apps, deskApps: deskApps);
    } catch (e) {
      if (current()) state = WebAppsState(offered: true, apps: state.apps, deskApps: state.deskApps, error: e.toString());
    }
  }

  /// The panel at desk app [id], opened in a browser. Null when the agent is
  /// not followed.
  Uri? deskUri(MonitorDeskApp app) => switch (_poll?.client) {
    final client? => app.uri(client.agentUri),
    null => null,
  };

  /// Where a browser opens app [id]: a fresh single-use ticket into the
  /// agent's proxy, good for seconds. Null when the agent is not followed.
  Future<Uri?> enter(String id) async {
    final client = _poll?.client;
    if (client == null) return null;
    final entry = await client.stackEnter(id);
    return entry.uri(client.agentUri);
  }
}
