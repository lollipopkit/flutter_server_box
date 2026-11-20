import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/monitor/http.dart';
import 'package:server_box/core/service/scoped_token.dart';
import 'package:server_box/core/utils/coalesced.dart';
import 'package:server_box/data/model/server/monitor/agent_endpoint.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/store/stores.dart';
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
  WatchSync._()
    : _enabled = null,
      _readContext = null,
      _writeContext = null,
      _issueToken = null,
      _revokeToken = null;

  @visibleForTesting
  WatchSync.forTest({
    required Future<Map<String, dynamic>?> Function() readContext,
    required Future<void> Function(Map<String, dynamic> payload) writeContext,
    required Future<ScopedToken> Function(Spi spi, String endpoint) issueToken,
    required Future<void> Function(Spi spi, String? endpoint) revokeToken,
  }) : _enabled = true,
       _readContext = readContext,
       _writeContext = writeContext,
       _issueToken = issueToken,
       _revokeToken = revokeToken;

  static final instance = WatchSync._();

  final bool? _enabled;
  final Future<Map<String, dynamic>?> Function()? _readContext;
  final Future<void> Function(Map<String, dynamic> payload)? _writeContext;
  final Future<ScopedToken> Function(Spi spi, String endpoint)? _issueToken;
  final Future<void> Function(Spi spi, String? endpoint)? _revokeToken;

  bool get _isEnabled => _enabled ?? isIOS;

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
  late final _pushes = Coalesced(_pushOnce);

  /// Per-server in-flight revoke and issue futures so revoke/issue for the same
  /// server stay ordered without blocking unrelated servers behind a slow one.
  final Map<String, Future<void>> _revoking = {};
  final Map<String, _InFlightIssue> _issuing = {};

  /// Servers whose previous token is being or has been revoked and must not be
  /// reused from a stale watch application context.
  final Set<String> _mustReissue = {};

  /// Specific token values already sent for revocation per server, so even an
  /// out-of-order stale context read never republishes a revoked token.
  final Map<String, Set<String>> _revokedTokens = {};

  /// Completes once [_wc] is either connected or known to be unavailable, so
  /// callers racing app startup wait rather than silently doing nothing.
  Future<void>? _ready;

  /// Whether a watch is paired with this phone.
  ///
  /// Only affects delivery: the selection lives in this app's store, so it
  /// stays editable and is pushed whenever a watch does appear.
  Future<bool> get isWatchPaired async {
    if (!_isEnabled) return false;
    if (_writeContext != null) return true;
    await _setupOnce();
    return await _wc?.isPaired ?? false;
  }

  Future<void> init() async {
    if (!_isEnabled) return;
    await _setupOnce();
    await push();
  }

  /// Rebuilds the payload and hands it to the watch.
  Future<void> push() {
    if (!_isEnabled) return Future.value();
    return _pushes();
  }

  Future<void> _pushOnce() async {
    if (_writeContext case final writeContext?) {
      final payload = await buildPayload();
      await writeContext(payload);
      return;
    }

    try {
      await _setupOnce();
    } catch (e, s) {
      Loggers.app.warning('Watch sync setup failed', e, s);
      return;
    }

    final wc = _wc;
    if (wc == null) return;
    final bool paired;
    try {
      paired = await wc.isPaired;
    } catch (e, s) {
      Loggers.app.warning('Watch paired check failed', e, s);
      return;
    }
    if (!paired) {
      await _revokeSelectedServers();
      return;
    }

    final payload = await buildPayload();

    Diag.crumb(SbDiag.sync, 'watch push');
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
    final invalidatedIds = <String>{
      ..._revoking.keys,
      ..._mustReissue,
      for (final entry in existingTokens.entries)
        if (_revokedTokens[entry.key]?.contains(entry.value.token) == true)
          entry.key,
    };
    final tokens = reusableScopedTokens(
      serverIds: selectedIds,
      lookup: Stores.server.fetchOneRaw,
      existing: existingTokens,
      now: DateTime.now(),
      invalidatedIds: invalidatedIds,
    );
    for (final id in selectedIds) {
      final spi = Stores.server.fetchOneRaw(id);
      final monitor = spi?.monitor;
      if (spi == null || monitor == null) continue;
      if (tokens.containsKey(id)) continue;
      // A revoke is still in flight for this server, or the user excluded it
      // while an earlier server was being issued: skip rather than minting a
      // token that would be left dangling on the Monitor or race the revoke.
      if (_revoking.containsKey(id) || !syncedServerIds().contains(id)) {
        continue;
      }
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
      if (existing != null &&
          existing.endpoint != endpoint &&
          !invalidatedIds.contains(id)) {
        try {
          await _revokeServer(spi, endpoint: existing.endpoint);
        } catch (e, s) {
          Loggers.app.info('Backstop revoke at ${existing.endpoint}', e, s);
        }
      }
      final issued = await _issueForServer(spi, endpoint);
      if (issued == null) continue;
      // If the user excluded this server while the token was being minted, do
      // not publish it; the queued revoke will clean it up after `_issuing`.
      if (_revoking.containsKey(id) || !syncedServerIds().contains(id)) {
        continue;
      }
      _mustReissue.remove(id);
      tokens[id] = issued;
    }
    // Re-filter against the latest selection and revoke state so a server
    // excluded while an earlier server was being issued never ships a stale
    // reused token.
    final currentSelected = syncedServerIds().toSet();
    tokens.removeWhere(
      (id, tok) =>
          !currentSelected.contains(id) ||
          _revoking.containsKey(id) ||
          _mustReissue.contains(id) ||
          _revokedTokens[id]?.contains(tok.token) == true,
    );
    return payloadFrom(
      selectedIds: selectedIds,
      lookup: Stores.server.fetchOneRaw,
      tokens: tokens,
      stamp: revision,
    );
  }

  /// Shares one in-flight mint per `(server, endpoint, credential)` so a
  /// concurrent `push()` and `requestData` do not issue back-to-back tokens
  /// that overwrite each other's hash on the Monitor.
  Future<ScopedToken?> _issueForServer(Spi spi, String endpoint) async {
    final id = spi.id;
    final key = _issueKey(spi, endpoint);

    while (true) {
      final existing = _issuing[id];
      if (existing != null) {
        if (existing.key == key) return await existing.future;
        await existing.future;
        continue;
      }

      // Re-check right before issuing, including after waiting for a prior
      // issue with different credentials to settle.
      if (_revoking.containsKey(id) || !syncedServerIds().contains(id)) {
        return null;
      }

      final completer = Completer<ScopedToken?>();
      final inFlight = _InFlightIssue(key: key, future: completer.future);
      _issuing[id] = inFlight;

      ScopedToken? result;
      try {
        if (_issueToken case final issueToken?) {
          result = await issueToken(spi, endpoint);
        } else {
          final monitor = spi.monitor;
          if (monitor != null) {
            final client = MonitorHttpClient(monitor);
            try {
              final issued = await client.issueWatchToken(watchClientId(spi.id));
              result = ScopedToken(
                token: issued.token,
                endpoint: endpoint,
                expiresAt: issued.expiresAt,
              );
            } finally {
              client.dispose();
            }
          }
        }
      } catch (e, s) {
        Loggers.app.warning(
          'Failed to issue read-only watch token for $id',
          e,
          s,
        );
      } finally {
        if (!completer.isCompleted) completer.complete(result);
        if (identical(_issuing[id], inFlight)) _issuing.remove(id);
      }
      return result;
    }
  }

  static Object _issueKey(Spi spi, String endpoint) {
    final m = spi.monitor;
    return (endpoint, m?.pwd, m?.legacyUser, m?.certSha256, m?.allowInsecure);
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
            .where((e) => e.monitorOn != null && !excluded.contains(e.id))
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
      final raw = _readContext != null
          ? await _readContext()
          : await _wc?.applicationContext;
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
    final toRevoke = <Spi>[
      for (final id in nowExcluded.where((id) => !previously.contains(id)))
        ?Stores.server.fetchOneRaw(id),
    ];
    // Persisted before any network call: revoking against an offline monitor
    // costs a ten-second timeout per server, and the user's choice must take
    // effect locally right away rather than waiting behind unreachable agents.
    Stores.setting.watchExcludedServerIds.put(next);
    for (final spi in toRevoke) {
      _enqueueRevoke(spi);
    }
    // Deliver the updated list for all non-revoking servers immediately.
    unawaited(push());
  }

  /// Schedules a per-server revoke so a slow agent never stalls unrelated
  /// servers, while blocking token reuse and concurrent issue for [spi.id]
  /// until the revoke settles.
  void _enqueueRevoke(Spi spi) {
    final id = spi.id;
    _mustReissue.add(id);
    final prevRevoke = _revoking[id];
    late final Future<void> op;
    op = () async {
      try {
        if (prevRevoke != null) await prevRevoke;
        final inFlightIssue = _issuing[id];
        if (inFlightIssue != null) await inFlightIssue.future;
        final existingTokens = await _existingTokens();
        final held = existingTokens[id];
        if (held != null && !held.isEmpty) {
          _revokedTokens.putIfAbsent(id, () => <String>{}).add(held.token);
        }
        try {
          await _revokeServer(spi, endpoint: held?.endpoint);
        } catch (e, s) {
          Loggers.app.warning('Could not revoke watch token for $id', e, s);
        }
      } finally {
        if (identical(_revoking[id], op)) unawaited(_revoking.remove(id));
        // If the server was re-included while revoking, this push now mints a
        // fresh token; if it stayed excluded, `syncedServerIds()` omits it so
        // nothing is re-issued.
        unawaited(push());
      }
    }();
    _revoking[id] = op;
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
    if (_revokeToken case final revokeToken?) {
      await revokeToken(spi, endpoint);
      return;
    }
    final monitor = spi.monitor;
    if (monitor == null) return;
    final revocationEndpoint = endpoint?.trim();
    final credential = revocationEndpoint == null || revocationEndpoint.isEmpty
        ? monitor
        : MonitorHttpCredential(
            addr: revocationEndpoint,
            pwd: monitor.pwd,
            legacyUser: monitor.legacyUser,
            certSha256: monitor.certSha256,
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
        if (monitor.fallbackAddr case final f? when f.trim().isNotEmpty)
          'fallbackAddr': f.trim(),
        'token': token.token,
        // Read back by `_existingTokens` on the next push to decide whether
        // this one is close enough to expiry to replace. The watch app itself
        // ignores the key — it finds out a token has expired by being told
        // 401, which it cannot do anything about; renewing is this side's job.
        'expiresAt': token.expiresAt,
        // The certificate this app accepted for a self-signed agent; the
        // watch checks it where the system does not trust the certificate.
        'certSha256': ?monitor.certSha256,
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
  @visibleForTesting
  Future<Map<String, dynamic>> handleWatchMessage(
    Map<String, dynamic> msg,
  ) => _onWatchAsked(msg);

  Future<Map<String, dynamic>> _onWatchAsked(Map<String, dynamic> msg) async {
    if (msg['action'] != 'requestData') return const {};

    final payload = await buildPayload();
    // The watch is holding whatever it just got; the stored context has to say
    // the same thing, or the next launch would hand it something older.
    if (_writeContext case final writeContext?) {
      unawaited(writeContext(payload));
    } else if (_wc case final wc?) {
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
  Future<void> _setupOnce() {
    final existing = _ready;
    if (existing != null) return existing;
    final setup = _setup();
    _ready = setup;
    // Do not cache a failed setup forever: a transient platform-channel error
    // would otherwise disable watch sync for the rest of the session.
    setup.catchError((Object _, StackTrace _) {
      if (identical(_ready, setup)) _ready = null;
    });
    return setup;
  }

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
    _pushes.cancelPending();
    _revoking.clear();
    _issuing.clear();
    _mustReissue.clear();
    _revokedTokens.clear();
    unawaited(_activationSub?.cancel());
    _activationSub = null;
    unawaited(_serverStoreSub?.cancel());
    _serverStoreSub = null;
    _wc?.dispose();
    _wc = null;
    _ready = null;
  }
}

final class _InFlightIssue {
  const _InFlightIssue({required this.key, required this.future});

  final Object key;
  final Future<ScopedToken?> future;
}
