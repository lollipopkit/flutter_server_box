import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/data/model/server/monitor_agent.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/data/provider/server/single.dart';

/// A task of a monitor agent: which server, which task.
typedef RemoteTaskRef = ({String serverId, String flowId});

/// The Agent mode tasks of every server whose monitor agent runs them for
/// this account, listed in the Agent's history beside the device's own
/// chats.
///
/// They stay on their machines: what is here is the agent's list as it last
/// said, kept current by its event stream while something follows it
/// ([follow]). Each server gets one client and one stream, shared by the
/// list and an open task ([events]).
abstract final class RemoteAgentTasks {
  /// Per server id, its tasks, newest first.
  static final tasks = ValueNotifier<Map<String, List<MonitorAgentFlow>>>(const {});

  /// The task shown in the Agent's conversation pane, instead of a chat of
  /// this device. Exclusive with `AgentChats.of(null)`: picking one clears
  /// the other.
  static final selected = ValueNotifier<RemoteTaskRef?>(null);

  /// Where a new conversation is made: null for this device, else the id of
  /// a server whose agent runs it as a task. Kept while the app runs.
  static final newOn = ValueNotifier<String?>(null);

  /// Per server id, why its list could not be read, for the history to say.
  static final errors = ValueNotifier<Map<String, String>>(const {});

  /// Per server id, the cursor of the page after what [tasks] holds; absent
  /// once the list is whole.
  static final more = ValueNotifier<Map<String, String>>(const {});

  /// Servers whose first page is being read: nothing of theirs is listed yet.
  static final loading = ValueNotifier<Set<String>>(const {});

  /// Servers whose next page is being read.
  static final _loadingMore = <String>{};

  /// Tasks read per page.
  static const pageSize = 50;

  static final _links = <String, _Link>{};
  static int _followers = 0;
  static ProviderSubscription<ServersState>? _serversSub;
  static final _serverSubs = <String, ProviderSubscription<bool>>{};

  /// Servers whose agent offers Agent mode to this account: their id and
  /// name, in the order the server list has them.
  static List<({String id, String name})> servers() {
    final container = AgentScope.maybeContainer;
    if (container == null) return const [];
    final all = container.read(serversProvider);
    return [
      for (final id in all.serverOrder)
        if (all.servers[id] case final spi? when spi.monitorOn != null && _offers(container.read(serverProvider(id))))
          (id: id, name: spi.name),
    ];
  }

  static bool _offers(ServerState s) {
    final caps = s.agentCapabilities;
    return caps != null && caps.features.contains('agent_mode') && caps.remoteAccess.fullAccess;
  }

  /// The client for server [serverId]'s agent, or null when it has none.
  static MonitorHttpClient? client(String serverId) {
    final cred = AgentScope.maybeContainer?.read(serversProvider).servers[serverId]?.monitorOn;
    final link = _links[serverId];
    if (cred == null) {
      _drop(serverId);
      return null;
    }
    if (link != null && link.client.monitor == cred) return link.client;
    _drop(serverId);
    return (_links[serverId] = _Link(serverId, MonitorHttpClient(cred))).client;
  }

  /// Server [serverId]'s events while it is followed: `flow`, `removed`,
  /// `pending`, `output`, `event`, `resync`.
  static Stream<Map<String, dynamic>> events(String serverId) {
    client(serverId);
    return _links[serverId]?.events.stream ?? const Stream.empty();
  }

  /// Keeps the lists current until the matching [unfollow]: what the history
  /// does while it is on screen.
  static void follow() {
    if (_followers++ > 0) return;
    final container = AgentScope.maybeContainer;
    if (container == null) return;
    _serversSub = container.listen(serversProvider, (_, _) => _sync(), fireImmediately: false);
    _sync();
  }

  static void unfollow() {
    if (--_followers > 0) return;
    _followers = 0;
    _serversSub?.close();
    _serversSub = null;
    for (final s in _serverSubs.values) {
      s.close();
    }
    _serverSubs.clear();
    for (final l in _links.values) {
      l.stop();
    }
  }

  /// Reads every list again.
  static Future<void> refresh() => Future.wait([for (final s in servers()) _load(s.id)]);

  /// Follows the servers that offer Agent mode now, and forgets the rest.
  static void _sync() {
    final container = AgentScope.maybeContainer;
    if (container == null) return;
    // A server's capabilities arrive with its first poll, after it is listed.
    for (final id in container.read(serversProvider).servers.keys) {
      _serverSubs[id] ??= container.listen(
        serverProvider(id).select((s) => _offers(s)),
        (_, _) => _sync(),
      );
    }
    final offering = {for (final s in servers()) s.id};
    for (final id in [..._serverSubs.keys]) {
      if (!container.read(serversProvider).servers.containsKey(id)) _serverSubs.remove(id)?.close();
    }
    for (final id in [...tasks.value.keys, ..._links.keys]) {
      if (!offering.contains(id)) _drop(id);
    }
    for (final id in offering) {
      if (client(id) case final _?) {
        _links[id]!.start();
        if (!tasks.value.containsKey(id)) unawaited(_load(id));
      }
    }
  }

  /// Reads server [serverId]'s newest page. What was read before it stays:
  /// a page further down is still where the list left off.
  static Future<void> _load(String serverId) async {
    final c = client(serverId);
    if (c == null) return;
    final first = !tasks.value.containsKey(serverId);
    if (first) loading.value = {...loading.value, serverId};
    try {
      final page = await c.agentFlows(limit: pageSize);
      if (!identical(_links[serverId]?.client, c)) return;
      final had = tasks.value[serverId];
      final fresh = {for (final f in page.flows) f.id};
      final kept = [...page.flows, ...?had?.where((f) => !fresh.contains(f.id))]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      tasks.value = {...tasks.value, serverId: kept};
      // Further than one page already read: the cursor of the furthest read.
      if (had == null || !more.value.containsKey(serverId) && had.length <= page.flows.length) {
        more.value = {...more.value}..remove(serverId);
        if (page.next case final n?) more.value = {...more.value, serverId: n};
      }
      if (errors.value.containsKey(serverId)) errors.value = {...errors.value}..remove(serverId);
    } catch (e) {
      Loggers.app.warning('Agent tasks of $serverId', e);
      errors.value = {...errors.value, serverId: '$e'};
    } finally {
      if (first) loading.value = {...loading.value}..remove(serverId);
    }
  }

  /// Reads server [serverId]'s next page, if it has one and is not reading
  /// it already.
  static Future<void> loadMore(String serverId) async {
    final cursor = more.value[serverId];
    final c = client(serverId);
    if (cursor == null || c == null || !_loadingMore.add(serverId)) return;
    try {
      final page = await c.agentFlows(limit: pageSize, before: cursor);
      if (!identical(_links[serverId]?.client, c)) return;
      final had = tasks.value[serverId] ?? const <MonitorAgentFlow>[];
      final known = {for (final f in had) f.id};
      tasks.value = {
        ...tasks.value,
        serverId: [...had, ...page.flows.where((f) => !known.contains(f.id))]
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      };
      more.value = {...more.value}..remove(serverId);
      if (page.next case final n?) more.value = {...more.value, serverId: n};
    } catch (e) {
      Loggers.app.warning('More agent tasks of $serverId', e);
    } finally {
      _loadingMore.remove(serverId);
    }
  }

  static bool loadingMore(String serverId) => _loadingMore.contains(serverId);

  /// Tasks whose title or last line has [needle], per server, as each agent
  /// finds them: the whole list, not only the pages read.
  static Future<Map<String, List<MonitorAgentFlow>>> search(String needle) async {
    final out = <String, List<MonitorAgentFlow>>{};
    Future<void> one(String id, MonitorHttpClient c) async {
      try {
        out[id] = (await c.agentFlows(limit: pageSize, query: needle)).flows;
      } catch (e) {
        Loggers.app.warning('Agent task search on $id', e);
      }
    }

    await Future.wait([
      for (final s in servers())
        if (client(s.id) case final c?) one(s.id, c),
    ]);
    return out;
  }

  static void _onEvent(String serverId, Map<String, dynamic> e) {
    final list = [...?tasks.value[serverId]];
    switch (e['type']) {
      case 'flow':
        if (e['flow'] case final Map<String, dynamic> f) {
          final flow = MonitorAgentFlow.fromJson(f);
          list
            ..removeWhere((x) => x.id == flow.id)
            ..add(flow)
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          tasks.value = {...tasks.value, serverId: list};
        }
      case 'removed':
        list.removeWhere((x) => x.id == e['id']);
        tasks.value = {...tasks.value, serverId: list};
        if (selected.value case (serverId: final s, flowId: final f) when s == serverId && f == e['id']) {
          selected.value = null;
        }
      case 'resync':
        unawaited(_load(serverId));
    }
  }

  static void _drop(String serverId) {
    _links.remove(serverId)?.stop();
    if (tasks.value.containsKey(serverId)) tasks.value = {...tasks.value}..remove(serverId);
    if (more.value.containsKey(serverId)) more.value = {...more.value}..remove(serverId);
    if (selected.value?.serverId == serverId) selected.value = null;
  }

  /// Shows task [ref] in the Agent's pane.
  static void select(RemoteTaskRef? ref) => selected.value = ref;

  @visibleForTesting
  static void reset() {
    for (final l in _links.values) {
      l.stop();
    }
    _links.clear();
    _followers = 0;
    tasks.value = const {};
    errors.value = const {};
    more.value = const {};
    loading.value = const {};
    selected.value = null;
  }
}

/// One server's client and its event stream, reconnected while followed.
final class _Link {
  _Link(this.serverId, this.client);

  final String serverId;
  final MonitorHttpClient client;
  final events = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _retry;
  var _backoff = const Duration(seconds: 1);
  var _running = false;
  var _connected = false;

  void start() {
    if (_running) return;
    _running = true;
    _connect();
  }

  void _connect() {
    if (!_running) return;
    _sub = client.agentEvents().listen(
      (e) {
        _backoff = const Duration(seconds: 1);
        RemoteAgentTasks._onEvent(serverId, e);
        events.add(e);
      },
      onError: (Object e) => Loggers.app.warning('Agent events of $serverId', e),
      onDone: _again,
      cancelOnError: true,
    );
    // Anything missed while it was down: a list read after the stream opened.
    if (_connected) unawaited(RemoteAgentTasks._load(serverId));
    _connected = true;
  }

  void _again() {
    _sub = null;
    if (!_running) return;
    _retry = Timer(_backoff, _connect);
    final next = _backoff * 2;
    _backoff = next > const Duration(seconds: 30) ? const Duration(seconds: 30) : next;
  }

  void stop() {
    _running = false;
    _retry?.cancel();
    unawaited(_sub?.cancel());
    _sub = null;
  }
}
