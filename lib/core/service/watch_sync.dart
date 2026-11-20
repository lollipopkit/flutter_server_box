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
/// Each server owns an independent [_ServerTokenSlot] state machine that
/// serialises revoke and mint operations for that server without blocking
/// unrelated servers. [buildPayload] reads only tokens currently active in
/// slots and triggers background reconciliation for missing ones, so an
/// offline monitor never stalls publishing the rest of the list.
final class WatchSync {
  WatchSync._()
    : _enabled = null,
      _readContext = null,
      _writeContext = null,
      _issueToken = null,
      _revokeToken = null,
      _now = DateTime.now,
      _revokeRetryDelay = _defaultRevokeRetryDelay,
      _revokeCredentialTtl = _defaultRevokeCredentialTtl,
      _mintWait = _defaultMintWait;

  @visibleForTesting
  WatchSync.forTest({
    required Future<Map<String, dynamic>?> Function() readContext,
    required Future<void> Function(Map<String, dynamic> payload) writeContext,
    required Future<ScopedToken> Function(Spi spi, String endpoint) issueToken,
    required Future<void> Function(Spi spi, String? endpoint) revokeToken,
    DateTime Function()? now,
    Duration revokeRetryDelay = Duration.zero,
    Duration revokeCredentialTtl = _defaultRevokeCredentialTtl,
    Duration mintWait = _defaultMintWait,
  }) : _enabled = true,
       _readContext = readContext,
       _writeContext = writeContext,
       _issueToken = issueToken,
       _revokeToken = revokeToken,
       _now = now ?? DateTime.now,
       _revokeRetryDelay = revokeRetryDelay,
       _revokeCredentialTtl = revokeCredentialTtl,
       _mintWait = mintWait;

  static final instance = WatchSync._();

  final bool? _enabled;
  final Future<Map<String, dynamic>?> Function()? _readContext;
  final Future<void> Function(Map<String, dynamic> payload)? _writeContext;
  final Future<ScopedToken> Function(Spi spi, String endpoint)? _issueToken;
  final Future<void> Function(Spi spi, String? endpoint)? _revokeToken;
  final DateTime Function() _now;
  final Duration _revokeRetryDelay;
  final Duration _revokeCredentialTtl;
  final Duration _mintWait;

  bool get _isEnabled => _enabled ?? isIOS;

  /// Bumped when the payload shape changes in a way an older watch app cannot
  /// read. The watch ignores keys it does not know, so additive changes do not
  /// need it.
  static const _payloadVersion = 3;

  /// Coalesces the burst of box events one server edit produces.
  static const _pushDebounce = Duration(milliseconds: 500);

  /// Bounded retries and retention window for a pre-deletion / pre-change
  /// [Spi] snapshot held in memory solely to revoke its old watch token.
  static const _maxRevokeRetries = 2;
  static const _defaultRevokeRetryDelay = Duration(seconds: 3);
  static const _defaultRevokeCredentialTtl = Duration(seconds: 30);

  /// How long a reply to the watch waits for tokens still being minted, so a
  /// fresh watch does not start from an empty list.
  static const _defaultMintWait = Duration(seconds: 5);

  /// One instance for the whole app: [MethodChannel.setMethodCallHandler] keeps
  /// a single handler, so a second `WatchConnectivity` would silently take the
  /// callbacks over — including the responder the watch depends on.
  WatchConnectivity? _wc;

  StreamSubscription<Map<String, dynamic>>? _activationSub;
  StreamSubscription<dynamic>? _serverStoreSub;
  Timer? _pushDebouncer;
  late final _pushes = Coalesced(_pushOnce);

  /// Per-server token state machines.
  final Map<String, _ServerTokenSlot> _slots = {};

  /// Lazily seeded once from the existing watch application context.
  Future<void>? _contextSeed;

  /// Completes once [_wc] is either connected or known to be unavailable, so
  /// callers racing app startup wait rather than silently doing nothing.
  Future<void>? _ready;

  /// Whether the phone currently has a paired watch. When false, slots only
  /// drain pending revocations and never mint new tokens or re-trigger pushes.
  var _paired = true;

  var _disposed = false;

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
    if (!_isEnabled || _disposed) return Future.value();
    return _pushes();
  }

  Future<void> _pushOnce() async {
    if (_disposed) return;
    if (_writeContext case final writeContext?) {
      final payload = await buildPayload();
      if (!_disposed) await writeContext(payload);
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
    _paired = paired;
    if (!paired) {
      await _revokeSelectedServers();
      return;
    }

    final payload = await buildPayload();
    if (_disposed) return;

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

  /// What the watch app is told to display right now.
  ///
  /// Reads only tokens currently active in per-server slots so a slow or
  /// offline monitor never blocks publishing the remaining servers. Any
  /// selected server without a ready token is reconciled in the background and
  /// triggers a follow-up [push] once minted. [waitForMints] bounds a wait for
  /// those mints before the snapshot is taken.
  Future<Map<String, dynamic>> buildPayload({Duration? waitForMints}) async {
    await _seedFromContextOnce();

    if (waitForMints != null) {
      final missing = <_ServerTokenSlot>[];
      _readyTokens(syncedServerIds(), missing: missing);
      // A revoke ahead of the mint may take its whole retry window.
      final running = [
        for (final slot in missing)
          if (slot.phase == _SlotPhase.minting) ?slot.running,
      ];
      if (running.isNotEmpty) {
        await Future.wait(running).timeout(
          waitForMints,
          onTimeout: () => const [],
        );
      }
    }

    final revision = nextRevision();
    final selectedIds = syncedServerIds();
    return payloadFrom(
      selectedIds: selectedIds,
      lookup: Stores.server.fetchOneRaw,
      // The wait above already reconciled; again would retry a mint still
      // running as soon as it fails.
      tokens: _readyTokens(selectedIds, reconcile: waitForMints == null),
      stamp: revision,
    );
  }

  /// The active token of each of [selectedIds]; every other one is added to
  /// [missing] and, with [reconcile], reconciled in the background.
  Map<String, ScopedToken> _readyTokens(
    List<String> selectedIds, {
    List<_ServerTokenSlot>? missing,
    bool reconcile = true,
  }) {
    final now = _now();
    final tokens = <String, ScopedToken>{};
    for (final id in selectedIds) {
      if (_slots[id]?.deleting ?? false) continue;
      final spi = Stores.server.fetchOneRaw(id);
      final monitor = spi?.monitorOn;
      if (spi == null || monitor == null) continue;

      final slot = _slot(id);
      final endpoint = normalizeAgentEndpoint(monitor.addr);
      final key = _issueKey(spi, endpoint);

      if (slot.usableToken(key: key, endpoint: endpoint, now: now)
          case final tok?) {
        tokens[id] = tok;
      } else {
        if (reconcile) _reconcileSlot(slot);
        missing?.add(slot);
      }
    }
    return tokens;
  }

  /// Seeds untouched slots once from the last delivered watch context so valid
  /// existing tokens are reused without an extra mint after restart.
  Future<void> _seedFromContextOnce() {
    return _contextSeed ??= _seedFromContext();
  }

  Future<void> _seedFromContext() async {
    final existingTokens = await _existingTokens();
    if (_disposed || existingTokens.isEmpty) return;

    final selectedIds = syncedServerIds();
    final invalidatedIds = <String>{
      for (final entry in _slots.entries)
        if (entry.value.revokeGen > 0 || entry.value.hasPendingRevoke)
          entry.key,
    };
    final reusable = reusableScopedTokens(
      serverIds: selectedIds,
      lookup: Stores.server.fetchOneRaw,
      existing: existingTokens,
      now: _now(),
      invalidatedIds: invalidatedIds,
    );
    for (final entry in reusable.entries) {
      final spi = Stores.server.fetchOneRaw(entry.key);
      final monitor = spi?.monitor;
      if (spi == null || monitor == null) continue;
      final slot = _slot(entry.key);
      // Do not overwrite a slot that has already started revoking or minting.
      if (slot.revokeGen > 0 ||
          slot.hasPendingRevoke ||
          slot.phase != _SlotPhase.idle) {
        continue;
      }
      final endpoint = normalizeAgentEndpoint(monitor.addr);
      slot.seed(token: entry.value, key: _issueKey(spi, endpoint));
    }
  }

  _ServerTokenSlot _slot(String id) =>
      _slots.putIfAbsent(id, () => _ServerTokenSlot(id));

  /// Schedules a per-server revoke using a pre-change [Spi] snapshot.
  void _scheduleRevoke(Spi spi, {bool useActiveEndpoint = true}) {
    if (_disposed) return;
    final slot = _slot(spi.id);
    final endpoint = useActiveEndpoint ? slot.activeToken?.endpoint : null;
    _queueRevoke(slot, spi, endpoint);
    _reconcileSlot(slot);
  }

  /// Revokes the old endpoint's token after a server edit is saved.
  void revokeEditedServer(Spi spi) {
    _scheduleRevoke(spi, useActiveEndpoint: false);
  }

  void _queueRevoke(
    _ServerTokenSlot slot,
    Spi spi,
    String? endpoint, {
    bool reusePending = false,
  }) {
    final now = _now();
    slot.requestRevoke(
      _PendingRevoke(
        spi: spi,
        endpoint: endpoint,
        deadline: now.add(_revokeCredentialTtl),
      ),
      reusePendingAt: reusePending ? now : null,
    );
  }

  void _reconcileSlot(_ServerTokenSlot slot) {
    if (_disposed) return;
    // Only a replacement for the request being retried cancels its backoff.
    if (slot.retryTimer != null) return;
    if (slot.running != null) {
      slot.dirty = true;
      return;
    }
    slot.running = _runSlot(slot).whenComplete(() {
      slot.running = null;
      if (_disposed || slot.retryTimer != null) return;
      if (slot.dirty) {
        slot.dirty = false;
        _reconcileSlot(slot);
      } else if (slot.isSettled &&
          identical(_slots[slot.id], slot) &&
          Stores.server.fetchOneRaw(slot.id) == null) {
        // Deleted or renamed away, with nothing left to revoke.
        _slots.remove(slot.id);
      }
    });
  }

  Future<void> _runSlot(_ServerTokenSlot slot) async {
    while (!_disposed) {
      slot.dirty = false;

      // 1. Revoke always runs before any mint for the same server.
      if (slot.hasPendingRevoke) {
        final shouldRetryLater = await _stepRevoke(slot);
        if (shouldRetryLater) return;
        // Loop again to check if the server was re-included meanwhile.
        continue;
      }

      if (!_isEnabled || !_paired || slot.deleting) {
        slot.clearActive();
        slot.phase = _SlotPhase.idle;
        return;
      }

      // 2. Check desired state from the store.
      final spi = Stores.server.fetchOneRaw(slot.id);
      final monitor = spi?.monitorOn;
      final excluded = Stores.setting.watchExcludedServerIds
          .fetch()
          .contains(slot.id);

      if (spi == null || monitor == null || excluded) {
        slot.clearActive();
        slot.phase = _SlotPhase.idle;
        return;
      }

      final endpoint = normalizeAgentEndpoint(monitor.addr);
      final key = _issueKey(spi, endpoint);

      // Already active with matching credentials and valid expiry.
      if (slot.usableToken(key: key, endpoint: endpoint, now: _now()) != null) {
        slot.phase = _SlotPhase.active;
        return;
      }

      // Endpoint moved: backstop-revoke the old endpoint if we knew it.
      final previousEndpoint = slot.activeToken?.endpoint;
      slot.clearActive();
      if (previousEndpoint != null && previousEndpoint != endpoint) {
        try {
          await _revokeServer(spi, endpoint: previousEndpoint);
        } catch (e, s) {
          Loggers.app.info('Backstop revoke at $previousEndpoint', e, s);
        }
        // The server or its queued revokes may have changed during DELETE.
        continue;
      }

      slot.phase = _SlotPhase.minting;
      final genBeforeMint = slot.revokeGen;
      final minted = await _mintToken(spi, endpoint);

      if (_disposed) return;

      // If a revoke arrived while minting, loop immediately to execute it.
      if (slot.hasPendingRevoke || slot.revokeGen != genBeforeMint) {
        if (minted != null) {
          _queueRevoke(slot, spi, endpoint, reusePending: true);
        }
        continue;
      }

      if (minted == null) {
        slot.phase = _SlotPhase.idle;
        return;
      }

      // Re-check latest selection and credentials before activating.
      final latestSpi = Stores.server.fetchOneRaw(slot.id);
      final latestMonitor = latestSpi?.monitorOn;
      final latestExcluded = Stores.setting.watchExcludedServerIds
          .fetch()
          .contains(slot.id);
      if (latestSpi == null ||
          latestMonitor == null ||
          latestExcluded ||
          slot.deleting ||
          !_paired) {
        // Excluded/deleted right as mint completed: revoke the just-minted
        // token using the credentials we just used.
        _queueRevoke(slot, spi, endpoint);
        continue;
      }
      final latestEndpoint = normalizeAgentEndpoint(latestMonitor.addr);
      if (_issueKey(latestSpi, latestEndpoint) != key) {
        // If the endpoint moved mid-mint, revoke the token just minted at the
        // old endpoint before minting for the new one.
        if (latestEndpoint != endpoint) {
          _queueRevoke(slot, spi, endpoint);
        }
        continue;
      }

      if (!minted.servesEndpoint(endpoint, _now())) {
        slot.phase = _SlotPhase.idle;
        return;
      }
      slot.activate(token: minted, key: key);
      unawaited(push());
      return;
    }
  }

  /// Executes one revoke attempt for [slot]. Returns `true` if a bounded retry
  /// timer was scheduled and the loop should yield until it fires.
  Future<bool> _stepRevoke(_ServerTokenSlot slot) async {
    final request = slot.pendingRevokes.first;
    // A request queued behind slow work is still sent once: only a retry
    // expires.
    if (request.attempts > 0 && !_now().isBefore(request.deadline)) {
      slot.pendingRevokes.removeAt(0);
      return false;
    }

    slot.clearActive();
    slot.phase = _SlotPhase.revoking;

    var succeeded = false;
    try {
      await _revokeServer(request.spi, endpoint: request.endpoint);
      succeeded = true;
    } catch (e, s) {
      Loggers.app.warning('Could not revoke watch token for ${slot.id}', e, s);
    }

    if (_disposed || !identical(slot.pendingRevokes.first, request)) return false;

    final now = _now();
    final canRetry =
        !succeeded &&
        request.attempts < _maxRevokeRetries &&
        now.isBefore(request.deadline);
    if (canRetry) {
      request.attempts++;
      slot.phase = _SlotPhase.idle;
      final remaining = request.deadline.difference(now);
      final delay = _revokeRetryDelay < remaining
          ? _revokeRetryDelay
          : remaining;
      slot.retryTimer = Timer(delay, () {
        slot.retryTimer = null;
        if (!_disposed) _reconcileSlot(slot);
      });
      return true;
    }

    slot.pendingRevokes.removeAt(0);
    slot.phase = _SlotPhase.idle;
    // Publishing while unpaired would schedule another revoke.
    if (_isEnabled && _paired) unawaited(push());
    return false;
  }

  Future<ScopedToken?> _mintToken(Spi spi, String endpoint) async {
    try {
      if (_issueToken case final issueToken?) {
        return await issueToken(spi, endpoint);
      }
      final monitor = spi.monitor;
      if (monitor == null) return null;
      final client = MonitorHttpClient(monitor);
      try {
        final issued = await client.issueWatchToken(watchClientId(spi.id));
        return ScopedToken(
          token: issued.token,
          endpoint: endpoint,
          expiresAt: issued.expiresAt,
        );
      } finally {
        client.dispose();
      }
    } catch (e, s) {
      Loggers.app.warning(
        'Failed to issue read-only watch token for ${spi.id}',
        e,
        s,
      );
      return null;
    }
  }

  /// Every server the watch is meant to show, in a stable order.
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
  static String watchClientId(String serverId) => 'watch:$serverId';

  /// The tokens the watch is currently holding, read back out of the context
  /// this app last delivered.
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
  /// Persists the selection immediately and reconciles per-server revocations
  /// and mints in the background.
  Future<void> updateExclusions(List<String> next) async {
    final previously = Stores.setting.watchExcludedServerIds.fetch().toSet();
    final nowExcluded = next.toSet();
    final toRevoke = <Spi>[
      for (final id in nowExcluded.where((id) => !previously.contains(id)))
        ?Stores.server.fetchOneRaw(id),
    ];
    final newlyIncluded = previously.where((id) => !nowExcluded.contains(id));

    Stores.setting.watchExcludedServerIds.put(next);

    for (final spi in toRevoke) {
      _scheduleRevoke(spi);
    }
    for (final id in newlyIncluded) {
      _reconcileSlot(_slot(id));
    }
    // Deliver the updated list for all non-revoking servers immediately.
    unawaited(push());
  }

  /// Hands this server's credential back, ahead of the record being deleted.
  ///
  /// Uses the pre-deletion [spi] snapshot inside the server's slot so the
  /// revoke runs asynchronously without blocking deletion UI.
  Future<void> revokeServer(Spi spi) async {
    if (_disposed) return;
    _slot(spi.id).deleting = true;
    _scheduleRevoke(spi);
  }

  /// Releases the selection guard after the store deletion settles.
  void finishServerDeletion(String id) {
    final slot = _slots[id];
    if (slot == null) return;
    if (Stores.server.fetchOneRaw(id) == null) {
      final excluded = Stores.setting.watchExcludedServerIds.fetch();
      if (excluded.contains(id)) {
        Stores.setting.watchExcludedServerIds.put(
          excluded.where((excludedId) => excludedId != id).toList(),
        );
      }
    }
    slot.deleting = false;
    _reconcileSlot(slot);
  }

  /// Hands every credential back, because there is no watch to use them.
  Future<void> _revokeSelectedServers() async {
    for (final id in syncedServerIds()) {
      final spi = Stores.server.fetchOneRaw(id);
      if (spi == null) continue;
      _scheduleRevoke(spi);
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
    final credential = revocationEndpoint == null ||
            revocationEndpoint.isEmpty ||
            revocationEndpoint == normalizeAgentEndpoint(monitor.addr)
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
      await client.revokeWatchToken(watchClientId(spi.id));
    } catch (e, s) {
      Loggers.app.warning('Failed to revoke watch token for ${spi.id}', e, s);
      rethrow;
    } finally {
      client.dispose();
    }
  }

  /// The payload as a pure function of the selection, so the shape the watch
  /// depends on can be tested without a store behind it.
  @visibleForTesting
  static Map<String, dynamic> payloadFrom({
    required List<String> selectedIds,
    required Spi? Function(String id) lookup,
    required Map<String, ScopedToken> tokens,
    required int stamp,
  }) {
    final servers = <Map<String, dynamic>>[];
    for (final id in selectedIds) {
      final spi = lookup(id);
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
        'expiresAt': token.expiresAt,
        'certSha256': ?monitor.certSha256,
        'allowInsecure': monitor.allowInsecure,
      });
    }

    return {
      'v': _payloadVersion,
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

  /// Whether [serverId] still retains a pre-change credential snapshot for a
  /// pending revoke retry.
  @visibleForTesting
  bool hasPendingRevokeFor(String serverId) =>
      _slots[serverId]?.hasPendingRevoke ?? false;

  /// Whether [serverId] still has a token slot.
  @visibleForTesting
  bool hasSlotFor(String serverId) => _slots.containsKey(serverId);

  Future<Map<String, dynamic>> _onWatchAsked(Map<String, dynamic> msg) async {
    if (msg['action'] != 'requestData') return const {};

    final payload = await buildPayload(waitForMints: _mintWait);
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

  static Object _issueKey(Spi spi, String endpoint) {
    final m = spi.monitor;
    return (endpoint, m?.pwd, m?.legacyUser, m?.certSha256, m?.allowInsecure);
  }

  /// Never calls [push] itself — [push] awaits this, and doing both ways round
  /// would deadlock.
  Future<void> _setupOnce() {
    final existing = _ready;
    if (existing != null) return existing;
    final setup = _setup();
    _ready = setup;
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
    _serverStoreSub = Stores.server.watch().listen((_) => _schedulePush());
  }

  void _schedulePush() {
    _pushDebouncer?.cancel();
    _pushDebouncer = Timer(_pushDebounce, () => unawaited(push()));
  }

  void dispose() {
    _disposed = true;
    _pushDebouncer?.cancel();
    _pushDebouncer = null;
    _pushes.cancelPending();
    for (final slot in _slots.values) {
      slot.dispose();
    }
    _slots.clear();
    _contextSeed = null;
    unawaited(_activationSub?.cancel());
    _activationSub = null;
    unawaited(_serverStoreSub?.cancel());
    _serverStoreSub = null;
    _wc?.dispose();
    _wc = null;
    _ready = null;
  }
}

enum _SlotPhase { idle, minting, active, revoking }

final class _PendingRevoke {
  _PendingRevoke({
    required this.spi,
    required this.endpoint,
    required this.deadline,
  });

  final Spi spi;
  final String? endpoint;
  final DateTime deadline;
  int attempts = 0;

  Object get key {
    final monitor = spi.monitor;
    final primary = normalizeAgentEndpoint(monitor?.addr ?? '');
    return (
      WatchSync._issueKey(spi, endpoint ?? primary),
      endpoint == null || endpoint == primary ? monitor?.fallbackAddr : null,
    );
  }
}

/// Per-server token lifecycle state machine.
final class _ServerTokenSlot {
  _ServerTokenSlot(this.id);

  final String id;
  _SlotPhase phase = _SlotPhase.idle;
  ScopedToken? activeToken;
  Object? activeKey;

  int revokeGen = 0;
  final pendingRevokes = <_PendingRevoke>[];
  Timer? retryTimer;
  var deleting = false;

  Future<void>? running;
  var dirty = false;

  bool get hasPendingRevoke => pendingRevokes.isNotEmpty;

  /// Holds nothing that outlives the server record.
  bool get isSettled =>
      !hasPendingRevoke && !deleting && activeToken == null && running == null;

  ScopedToken? usableToken({
    required Object key,
    required String endpoint,
    required DateTime now,
  }) {
    if (hasPendingRevoke || phase == _SlotPhase.revoking) return null;
    final token = activeToken;
    if (token == null || activeKey != key) return null;
    if (!token.servesEndpoint(endpoint, now)) return null;
    return token;
  }

  void seed({required ScopedToken token, required Object key}) {
    activeToken = token;
    activeKey = key;
    phase = _SlotPhase.active;
  }

  void activate({required ScopedToken token, required Object key}) {
    activeToken = token;
    activeKey = key;
    phase = _SlotPhase.active;
  }

  void clearActive() {
    activeToken = null;
    activeKey = null;
  }

  void requestRevoke(_PendingRevoke request, {DateTime? reusePendingAt}) {
    final key = request.key;
    final index = pendingRevokes.indexWhere((pending) => pending.key == key);
    if (reusePendingAt != null &&
        index >= 0 &&
        reusePendingAt.isBefore(pendingRevokes[index].deadline)) {
      return;
    }
    revokeGen++;
    clearActive();
    if (index < 0) {
      pendingRevokes.add(request);
    } else {
      pendingRevokes[index] = request;
      if (index == 0) {
        retryTimer?.cancel();
        retryTimer = null;
      }
    }
  }

  void dispose() {
    clearActive();
    retryTimer?.cancel();
    retryTimer = null;
    pendingRevokes.clear();
    phase = _SlotPhase.idle;
    dirty = false;
  }
}
