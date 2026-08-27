import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/service/scoped_token.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/data/res/store.dart';

/// Keeps the home-screen widgets' idea of the server list in step with this
/// app's, and gives them a credential to fetch with.
///
/// Every server with a `monitor` agent is published, with no selection step:
/// a widget is configured on the home screen, by picking from what this
/// publishes, and a second list to curate first would only be somewhere to
/// forget a server. What the user picks *there* is which one a given widget
/// shows. That is the difference from [WatchSync], where the selection decides
/// which servers a second device gets credentials for at all.
///
/// The split between what goes where is the point of this class:
///
/// - The **list** — name, address, certificate handling — is not secret and
///   goes to a container the widget process can read directly: the iOS App
///   Group, and Android's shared preferences. A widget that cannot read this
///   has nothing to offer the configuration screen.
/// - The **token** never touches either. It goes to the platform's credential
///   store — the shared Keychain on iOS, a Keystore-wrapped file on Android —
///   through [MethodChans.publishWidgetServers], and comes back only as
///   metadata (see [MethodChans.widgetTokenState]).
///
/// The token is a [ScopedToken], the same read-only credential the watch
/// carries and scoped to its own `client_id` so revoking one surface leaves
/// the other alone.
final class WidgetSync {
  WidgetSync._();

  static final instance = WidgetSync._();

  /// Bumped when the payload shape changes in a way the native side cannot
  /// read. Additive changes do not need it — both sides ignore keys they do
  /// not know.
  static const payloadVersion = 1;

  /// Coalesces the burst of store events one server edit produces.
  static const _pushDebounce = Duration(milliseconds: 500);

  StreamSubscription<dynamic>? _serverStoreSub;
  Timer? _pushDebouncer;
  Future<void>? _pushing;
  bool _pushDirty = false;

  bool get _supported => isIOS || isAndroid;

  Future<void> init() async {
    if (!_supported) return;
    _serverStoreSub ??= Stores.server.watch().listen((_) => _schedulePush());
    await push();
  }

  /// Rebuilds the payload and hands it to the native side.
  ///
  /// Coalesced the same way [WatchSync.push] is: issuing tokens is a request
  /// per server, and a burst of store events must not turn into a burst of
  /// those.
  Future<void> push() {
    if (!_supported) return Future.value();
    _pushDirty = true;
    return _pushing ??= _drainPush();
  }

  Future<void> _drainPush() async {
    try {
      while (_pushDirty) {
        _pushDirty = false;
        await _pushOnce();
      }
    } finally {
      _pushing = null;
      if (_pushDirty) _pushing = _drainPush();
    }
  }

  Future<void> _pushOnce() async {
    final servers = monitorServers();
    final held = await _heldTokens();
    final tokens = reusableScopedTokens(
      serverIds: servers.map((e) => e.id).toList(),
      lookup: Stores.server.fetchOneRaw,
      existing: held,
      now: DateTime.now(),
    );

    for (final spi in servers) {
      if (tokens.containsKey(spi.id)) continue;
      final monitor = spi.monitor;
      if (monitor == null) continue;
      final endpoint = normalizeAgentEndpoint(monitor.addr);
      final client = MonitorHttpClient(monitor);
      // A backstop, not the real revocation: `revokeScopedTokensLeftBehind`
      // runs at the edit, while the old *login* is still known, and this only
      // has the new one to try the old address with. It covers the address
      // moving without this device seeing the edit — a change arriving over
      // sync, where nothing local ever held the old credential. Failing is
      // expected and must not stop the replacement being issued.
      final previous = held[spi.id];
      if (previous != null && previous.endpoint != endpoint) {
        try {
          await MonitorHttpClient(
            MonitorHttpCredential(
              addr: previous.endpoint,
              user: monitor.user,
              pwd: monitor.pwd,
              ignoreCert: monitor.ignoreCert,
              allowInsecure: monitor.allowInsecure,
            ),
          ).revokeWatchToken(widgetClientId(spi.id));
        } catch (e, s) {
          Loggers.app.info('Backstop revoke at ${previous.endpoint}', e, s);
        }
      }
      try {
        final issued = await client.issueWatchToken(widgetClientId(spi.id));
        tokens[spi.id] = ScopedToken(
          token: issued.token,
          endpoint: endpoint,
          expiresAt: issued.expiresAt,
        );
      } catch (e, s) {
        // Not fatal, and deliberately not a reason to drop the server from
        // the list: the widget still has a name and an address to show, and
        // an agent that is merely unreachable right now will answer the next
        // push. Publishing nothing would empty the configuration screen for a
        // temporary failure.
        Loggers.app.warning('Issue widget token for ${spi.id}', e, s);
      } finally {
        client.dispose();
      }
    }

    try {
      await MethodChans.publishWidgetServers(
        jsonEncode(payloadFrom(servers: servers, tokens: tokens)),
      );
    } catch (e, s) {
      Loggers.app.warning('Publish widget servers', e, s);
    }
  }

  /// The agent-side `client_id` a widget token is scoped to.
  ///
  /// Distinct from [WatchSync.watchClientId] on purpose. The agent keys
  /// `watch_tokens` by `(subject, client_id)`, so two client ids are two rows:
  /// unpairing a watch revokes one and leaves the widgets working, and a
  /// widget removed from the home screen does not log a watch out.
  static String widgetClientId(String serverId) => 'widget:$serverId';

  /// Servers a widget could show: it speaks to a `monitor` agent over HTTP and
  /// has no SSH client of its own.
  static List<Spi> monitorServers() =>
      Stores.server.fetch().where((e) => e.monitor != null).toList();

  /// What the native side is currently holding, as metadata only.
  ///
  /// The token itself is never read back: it lives in the platform credential
  /// store and this side has no reason to see it again. Only the endpoint it
  /// belongs to and when it lapses, which is everything the renewal decision
  /// needs — the token stands in as a non-empty placeholder so
  /// [ScopedToken.isEmpty] answers correctly.
  Future<Map<String, ScopedToken>> _heldTokens() async {
    try {
      final raw = await MethodChans.widgetTokenState();
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return {
        for (final entry in decoded.whereType<Map>())
          if (entry['id'] is String && entry['endpoint'] is String)
            entry['id'] as String: ScopedToken.held(
              endpoint: normalizeAgentEndpoint(entry['endpoint'] as String),
              expiresAt: switch (entry['expiresAt']) {
                final num v => v.toInt(),
                _ => 0,
              },
            ),
      };
    } catch (e, s) {
      Loggers.app.info('Could not read the widget token state', e, s);
      return {};
    }
  }

  /// The payload as a pure function of its inputs, so the shape two native
  /// implementations depend on can be tested without either of them.
  ///
  /// A server with no usable token is still published. The widget shows a name
  /// and says it cannot reach the agent, which is a better answer than a
  /// configuration screen that has silently lost an entry.
  ///
  /// Ordered by name here rather than left in store order, because the one
  /// place this list is read by a person is a picker on a configuration sheet —
  /// where alphabetical is what lets someone find a server, and the user's own
  /// arrangement of their server *list* means nothing.
  @visibleForTesting
  static Map<String, dynamic> payloadFrom({
    required List<Spi> servers,
    required Map<String, ScopedToken> tokens,
  }) {
    final ordered = [...servers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final entries = <Map<String, dynamic>>[];
    for (final spi in ordered) {
      final monitor = spi.monitor;
      if (monitor == null) continue;
      final token = tokens[spi.id];
      entries.add({
        'id': spi.id,
        'name': spi.name,
        'addr': normalizeAgentEndpoint(monitor.addr),
        // Only a credential this side actually holds. A reused one lives in
        // the platform store and comes back as a placeholder
        // (`ScopedToken.held`); publishing that would write the word "held"
        // over the real token, and the native side already keeps what it has
        // when an entry carries none.
        if (token != null && !token.isEmpty && !token.opaque)
          'token': token.token,
        'expiresAt': token?.expiresAt ?? 0,
        'ignoreCert': monitor.ignoreCert,
        // Whether this server was opted in to plaintext HTTP. The widget
        // asks the same question the app does before every request: Android's
        // `usesCleartextTraffic` lets the *process* speak plaintext, and is
        // not a decision about any particular server. Without this the widget
        // would put a bearer token on the wire for a server whose owner never
        // agreed to that.
        'allowInsecure': monitor.allowInsecure,
      });
    }

    return {'v': payloadVersion, 'servers': entries};
  }

  void _schedulePush() {
    _pushDebouncer?.cancel();
    _pushDebouncer = Timer(_pushDebounce, () => unawaited(push()));
  }

  /// Drops a deleted server's credential rather than leaving it on the device
  /// and valid at the agent.
  ///
  /// Best effort, like the watch's: a server has to stay deletable while its
  /// agent is offline, and once the record is gone there is nothing left to
  /// retry against.
  /// Hands this server's credential back, ahead of the record being deleted.
  ///
  /// Deliberately does **not** publish. The caller runs this while the server
  /// is still in the store — it has to, since revoking needs the credential —
  /// and a push here would rebuild the list from a store that still contains
  /// it, mint a *replacement* token for a server about to be deleted, and hand
  /// it to the widget. Publishing is the caller's job, after the delete.
  Future<void> revokeServer(Spi spi) async {
    if (!_supported) return;
    final monitor = spi.monitor;
    if (monitor == null) return;
    final client = MonitorHttpClient(monitor);
    try {
      await client.revokeWatchToken(widgetClientId(spi.id));
    } catch (e, s) {
      // The local server must remain deletable while its agent is offline,
      // and once the record is gone there is no retry target.
      Loggers.app.warning('Revoke widget token for ${spi.id}', e, s);
    } finally {
      client.dispose();
    }
  }

  void dispose() {
    _pushDebouncer?.cancel();
    _pushDebouncer = null;
    _pushDirty = false;
    unawaited(_serverStoreSub?.cancel());
    _serverStoreSub = null;
  }
}
