import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/service/scoped_token.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/data/res/store.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

/// Keeps the watch app's server list in step with this app's.
///
/// The watch is a separate process on a separate device that reaches monitor
/// agents by itself; all it needs from here is *which* servers to show and how
/// to authenticate.
///
/// Which servers is not a list anyone maintains: it is every server with a
/// `monitor` agent, minus [SettingStore.watchExcludedServerIds]. Adding a
/// server in the app puts it on the watch, and the exclusion list exists for
/// the one thing that genuinely needs a decision — syncing a server mints a
/// credential and puts it on a second device, and that is worth being able to
/// refuse. The list is backed up and synced like everything else; the WCSession
/// application context is only the transport.
///
/// Both WatchConnectivity paths are used, on purpose and in this order:
///
/// - [WatchConnectivity.updateApplicationContext] first. It is the only path
///   that reaches a watch app which is not running, it survives reboots, and
///   it is what the watch reads at launch. It is also the state the watch pulls
///   when it re-asks, so it must never lag behind what the user last chose.
/// - [WatchConnectivity.sendMessage] second, and best-effort. It only reaches a
///   watch that is awake right now, and it fails outright against a watch app
///   old enough to lack the reply-carrying receive callback — so it is an
///   optimisation for immediacy, never the thing carrying the state.
///
/// This app also answers the watch's own `requestData` message
/// ([messageResponder]), which is how a freshly installed watch app configures
/// itself without the user having to visit the iOS settings page.
final class WatchSync {
  WatchSync._();

  static final instance = WatchSync._();

  /// Bumped when the payload shape changes in a way an older watch app cannot
  /// read. The watch ignores keys it does not know, so additive changes do not
  /// need it.
  static const _payloadVersion = 3;

  /// Coalesces the burst of box events one server edit produces.
  static const _pushDebounce = Duration(milliseconds: 500);

  /// One instance for the whole app: [MethodChannel.setMethodCallHandler] keeps
  /// a single handler, so a second `WatchConnectivity` would silently take the
  /// callbacks over — including the responder the watch depends on.
  WatchConnectivity? _wc;

  StreamSubscription<Map<String, dynamic>>? _activationSub;
  StreamSubscription<dynamic>? _serverStoreSub;
  Timer? _pushDebouncer;
  Future<void>? _pushing;
  bool _pushDirty = false;

  /// Completes once [_wc] is either connected or known to be unavailable, so
  /// callers racing app startup wait rather than silently doing nothing.
  Future<void>? _ready;

  /// Whether a watch is paired with this phone.
  ///
  /// Only affects delivery: the selection lives in this app's store, so it
  /// stays editable and is pushed whenever a watch does appear.
  Future<bool> get isWatchPaired async {
    if (!isIOS) return false;
    await _setupOnce();
    return await _wc?.isPaired ?? false;
  }

  Future<void> init() async {
    if (!isIOS) return;
    await _setupOnce();
    await push();
  }

  /// Rebuilds the payload and hands it to the watch.
  Future<void> push() {
    if (!isIOS) return Future.value();
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
    await _setupOnce();

    final wc = _wc;
    if (wc == null) return;
    if (!await wc.isPaired) {
      await _revokeSelectedServers();
      return;
    }

    final payload = await buildPayload();

    try {
      await wc.updateApplicationContext(payload);
    } catch (e, s) {
      // Nothing to fall back to: this *is* the durable path. An unpaired watch
      // is the common cause and is not worth surfacing.
      Loggers.app.warning('Failed to update watch application context', e, s);
      return;
    }

    try {
      if (await wc.isReachable) await wc.sendMessage(payload);
    } catch (e, s) {
      // The context above already carries the change; the watch picks it up
      // when it next activates.
      Loggers.app.info('Watch realtime update skipped: $e', e, s);
    }
  }

  /// Strictly increasing, and read where a snapshot is taken.
  ///
  /// Seeded from the clock so that it keeps rising across a restart, where a
  /// counter starting again at zero would look older than everything the watch
  /// had already applied. Bumped by hand when the clock has not moved, so two
  /// snapshots taken in the same millisecond are still ordered.
  @visibleForTesting
  static int nextRevision() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _revision = now > _revision ? now : _revision + 1;
    return _revision;
  }

  static int _revision = 0;

  /// What the watch app is told to display.
  Future<Map<String, dynamic>> buildPayload() async {
    // Taken with the snapshot rather than with the result. Issuing tokens is a
    // network round trip per server, so two builds overlap easily — and stamped
    // at the end, the slower one finished last carrying the *newer* number
    // while holding the *older* selection, which is exactly backwards.
    final revision = nextRevision();
    final selectedIds = syncedServerIds();
    final existingTokens = await _existingTokens();
    final tokens = reusableScopedTokens(
      serverIds: selectedIds,
      lookup: Stores.server.fetchOneRaw,
      existing: existingTokens,
      now: DateTime.now(),
    );
    for (final id in selectedIds) {
      final spi = Stores.server.fetchOneRaw(id);
      final monitor = spi?.monitor;
      if (spi == null || monitor == null) continue;
      if (tokens.containsKey(id)) continue;
      final existing = existingTokens[id];
      final endpoint = normalizeAgentEndpoint(monitor.addr);
      // Only when the *address* moved. An expiry that crept up is renewed by
      // issuing again — the agent's `ON CONFLICT DO UPDATE` replaces the row
      // in place — and revoking first would leave the watch with nothing for
      // as long as the second request takes, or forever if it fails.
      //
      // A backstop, not the real revocation: `revokeScopedTokensLeftBehind`
      // runs at the edit, while the old *login* is still known, and this only
      // has the new one to try the old address with. So a failure here is
      // expected and must not take the payload with it — it used to throw out
      // of the whole build, and since the store event that started it had
      // already been consumed, nothing was delivered and nothing retried. The
      // watch kept whatever it had until the next unrelated edit.
      if (existing != null && existing.endpoint != endpoint) {
        try {
          await _revokeServer(spi, endpoint: existing.endpoint);
        } catch (e, s) {
          Loggers.app.info('Backstop revoke at ${existing.endpoint}', e, s);
        }
      }
      final client = MonitorHttpClient(monitor);
      try {
        final issued = await client.issueWatchToken(watchClientId(spi.id));
        tokens[id] = ScopedToken(
          token: issued.token,
          endpoint: endpoint,
          expiresAt: issued.expiresAt,
        );
      } catch (e, s) {
        Loggers.app.warning('Failed to issue read-only watch token for $id', e, s);
      } finally {
        client.dispose();
      }
    }
    return payloadFrom(
      selectedIds: selectedIds,
      lookup: Stores.server.fetchOneRaw,
      tokens: tokens,
      stamp: revision,
    );
  }

  /// Every server the watch is meant to show, in a stable order.
  ///
  /// Everything with a `monitor` agent, minus what the user held back. There
  /// is no opt-in step: a server added in the app is on the watch by the next
  /// push, which is what makes this automatic rather than a second list to
  /// maintain.
  ///
  /// Ordered by name because the watch pages through this list and the order
  /// has to be one someone can predict — store order is the order servers
  /// happened to be added, which on a watch face reads as no order at all.
  static List<String> syncedServerIds() {
    final excluded = Stores.setting.watchExcludedServerIds.fetch().toSet();
    final servers =
        Stores.server
            .fetch()
            .where((e) => e.monitor != null && !excluded.contains(e.id))
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return servers.map((e) => e.id).toList();
  }

  /// The agent-side `client_id` a watch token is scoped to.
  ///
  /// Distinct from the widgets' — see `WidgetSync.widgetClientId` — so that
  /// revoking one device does not take the other's credential with it. The
  /// agent keys `watch_tokens` by `(subject, client_id)`, which is what makes
  /// the two independent. Both appear in `scopedClientIdsFor`, which is what
  /// revokes them together when a server leaves its agent behind.
  static String watchClientId(String serverId) => 'watch:$serverId';

  /// The tokens the watch is currently holding, read back out of the context
  /// this app last delivered.
  ///
  /// The context is the only place they are kept: a scoped token is derived
  /// state — it can always be minted again — so storing it beside the server
  /// record would be one more copy of a credential to protect, back up and
  /// forget to revoke.
  Future<Map<String, ScopedToken>> _existingTokens() async {
    try {
      final raw = await _wc?.applicationContext;
      final servers = raw?['servers'];
      if (servers is! List) return {};
      return {
        for (final entry in servers.whereType<Map>())
          if (entry['id'] is String &&
              entry['addr'] is String &&
              entry['token'] is String)
            entry['id'] as String: ScopedToken(
              token: entry['token'] as String,
              endpoint: normalizeAgentEndpoint(entry['addr'] as String),
              // Absent on a context written before this app kept the
              // deadline, which `ScopedToken` reads as due for renewal —
              // so an install carrying one of those gets a known expiry on
              // its next push rather than a silent 401 up to 90 days later.
              expiresAt: switch (entry['expiresAt']) {
                final num v => v.toInt(),
                _ => 0,
              },
            ),
      };
    } catch (e, s) {
      Loggers.app.info('Could not reuse the current watch token context', e, s);
      return {};
    }
  }

  /// Holds [next] back from the watch, and syncs everything else.
  ///
  /// A server moving *into* the exclusion list has its credential revoked
  /// right away rather than left to lapse. Holding a server back has to mean
  /// the watch can no longer read it — a token that stays valid for another 90
  /// days would make this a change to what is displayed and nothing more.
  Future<void> updateExclusions(List<String> next) async {
    final previously = Stores.setting.watchExcludedServerIds.fetch().toSet();
    final nowExcluded = next.toSet();
    final existingTokens = await _existingTokens();
    for (final id in nowExcluded.where((id) => !previously.contains(id))) {
      final spi = Stores.server.fetchOneRaw(id);
      if (spi == null) continue;
      // Best effort, per server. `_revokeServer` rethrows, and one agent that
      // is merely offline used to take the whole call with it — the choice was
      // never stored and the watch was never told, so a user holding three
      // servers back kept all three because one of them was unreachable.
      try {
        await _revokeServer(spi, endpoint: existingTokens[id]?.endpoint);
      } catch (e, s) {
        Loggers.app.warning('Could not revoke watch token for $id', e, s);
      }
    }
    Stores.setting.watchExcludedServerIds.put(next);
    await push();
  }

  /// Hands this server's credential back, ahead of the record being deleted.
  ///
  /// Deliberately does **not** push. The caller runs this while the server is
  /// still in the store — it has to, since revoking needs the credential — and
  /// a push here would rebuild the list from a store that still contains it,
  /// mint a *replacement* token for a server about to be deleted, and deliver
  /// it to the watch. Publishing is the caller's job, after the delete.
  Future<void> revokeServer(Spi spi) async {
    final existingTokens = await _existingTokens();
    try {
      await _revokeServer(spi, endpoint: existingTokens[spi.id]?.endpoint);
    } catch (e, s) {
      // The local server must remain removable while its monitor is offline.
      // The token may outlive it remotely, but retaining local credentials is
      // worse and there is no retry target once the user has deleted it.
      Loggers.app.warning('Could not revoke watch token for ${spi.id}', e, s);
    }
    // A deleted server must not leave its id sitting in the exclusion list.
    // Ids are generated, so a stale one is only clutter today — but it becomes
    // a trap the moment one is reused by a restore, which would arrive already
    // held back for a reason nobody can see.
    final excluded = Stores.setting.watchExcludedServerIds.fetch();
    if (excluded.contains(spi.id)) {
      Stores.setting.watchExcludedServerIds.put(
        excluded.where((id) => id != spi.id).toList(),
      );
    }
  }

  /// Hands every credential back, because there is no watch to use them.
  ///
  /// Per server and best effort: one unreachable agent must not stop the rest
  /// being revoked, and must not abort the `_pushOnce` that called this.
  Future<void> _revokeSelectedServers() async {
    final existingTokens = await _existingTokens();
    for (final id in syncedServerIds()) {
      final spi = Stores.server.fetchOneRaw(id);
      if (spi == null) continue;
      try {
        await _revokeServer(spi, endpoint: existingTokens[id]?.endpoint);
      } catch (e, s) {
        Loggers.app.warning('Could not revoke watch token for $id', e, s);
      }
    }
  }

  Future<void> _revokeServer(Spi spi, {String? endpoint}) async {
    final monitor = spi.monitor;
    if (monitor == null) return;
    final revocationEndpoint = endpoint?.trim();
    final credential = revocationEndpoint == null || revocationEndpoint.isEmpty
        ? monitor
        : MonitorHttpCredential(
            addr: revocationEndpoint,
            user: monitor.user,
            pwd: monitor.pwd,
            ignoreCert: monitor.ignoreCert,
            allowInsecure: monitor.allowInsecure,
          );
    final client = MonitorHttpClient(credential);
    try {
      await client.revokeWatchToken('watch:${spi.id}');
    } catch (e, s) {
      Loggers.app.warning('Failed to revoke watch token for ${spi.id}', e, s);
      rethrow;
    } finally {
      client.dispose();
    }
  }

  /// The payload as a pure function of the selection, so the shape the watch
  /// depends on can be tested without a store behind it.
  ///
  /// `servers` carries scoped read-only tokens, and is the only shape the
  /// watch is offered. The pre-v2 `urls` list is gone: it named the agent's
  /// Go-compat endpoint, which the agent no longer serves, so emitting it
  /// would only give an un-updated watch something that fails slightly later.
  @visibleForTesting
  /// [stamp] orders this against the other payloads in flight, and is passed in
  /// rather than read here so that this stays a pure function.
  static Map<String, dynamic> payloadFrom({
    required List<String> selectedIds,
    required Spi? Function(String id) lookup,
    required Map<String, ScopedToken> tokens,
    required int stamp,
  }) {
    final servers = <Map<String, dynamic>>[];
    for (final id in selectedIds) {
      final spi = lookup(id);
      // A server can be deleted, or lose its monitor config, after being
      // picked; sending it would give the watch an entry it can never load.
      final monitor = spi?.monitor;
      if (spi == null || monitor == null) continue;
      final token = tokens[id];
      if (token == null || token.isEmpty) continue;

      servers.add({
        'id': spi.id,
        'name': spi.name,
        'addr': monitor.addr.trim(),
        'token': token.token,
        // Read back by `_existingTokens` on the next push to decide whether
        // this one is close enough to expiry to replace. The watch app itself
        // ignores the key — it finds out a token has expired by being told
        // 401, which it cannot do anything about; renewing is this side's job.
        'expiresAt': token.expiresAt,
        'ignoreCert': monitor.ignoreCert,
        // The watch refuses to send the token over plaintext without it, the
        // way this app and the home widget do. Not a storage decision made
        // here: the answer travels so the check can be made where the request
        // is.
        'allowInsecure': monitor.allowInsecure,
      });
    }

    return {
      'v': _payloadVersion,
      // When this was built, so the watch can tell a stale delivery from a
      // fresh one. WatchConnectivity orders nothing between a queued userInfo,
      // the application context and a reply to `requestData`, so a payload that
      // had been sitting in the queue could land last and undo a newer
      // selection. A watch that predates this ignores the key, and a payload
      // without it is applied as before.
      'ts': stamp,
      'servers': servers,
    };
  }

  /// The watch asking for the current configuration, e.g. right after being
  /// installed or restored.
  Future<Map<String, dynamic>> _onWatchAsked(Map<String, dynamic> msg) async {
    if (msg['action'] != 'requestData') return const {};

    final payload = await buildPayload();
    // The watch is holding whatever it just got; the stored context has to say
    // the same thing, or the next launch would hand it something older.
    final wc = _wc;
    if (wc != null) {
      unawaited(
        wc.updateApplicationContext(payload).catchError(
          (Object e, StackTrace s) =>
              Loggers.app.warning('Watch context refresh', e, s),
        ),
      );
    }
    return payload;
  }

  /// Never calls [push] itself — [push] awaits this, and doing both ways round
  /// would deadlock.
  Future<void> _setupOnce() => _ready ??= _setup();

  Future<void> _setup() async {
    final wc = WatchConnectivity();
    if (!await wc.isSupported) {
      wc.dispose();
      return;
    }
    _wc = wc;

    wc.messageResponder = _onWatchAsked;
    _activationSub = wc.activationStream.listen((event) {
      if (event['isActivated'] == true) unawaited(push());
    });
    // A server's monitor address or login can change without the watch
    // selection changing, and issuing again also rotates the scoped token.
    _serverStoreSub = Stores.server.watch().listen((_) => _schedulePush());
  }

  void _schedulePush() {
    _pushDebouncer?.cancel();
    _pushDebouncer = Timer(_pushDebounce, () => unawaited(push()));
  }

  void dispose() {
    _pushDebouncer?.cancel();
    _pushDebouncer = null;
    _pushDirty = false;
    unawaited(_activationSub?.cancel());
    _activationSub = null;
    unawaited(_serverStoreSub?.cancel());
    _serverStoreSub = null;
    _wc?.dispose();
    _wc = null;
    _ready = null;
  }
}
