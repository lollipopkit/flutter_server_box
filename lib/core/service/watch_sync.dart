import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/data/res/store.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

/// Keeps the watch app's server list in step with this app's.
///
/// The watch is a separate process on a separate device that reaches monitor
/// agents by itself; all it needs from here is *which* servers to show and how
/// to authenticate. That configuration lives in [SettingStore.watchServerIds]
/// (backed up and synced like everything else) — the WCSession application
/// context is only the transport.
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
    await _importLegacyUrls();
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

  /// What the watch app is told to display.
  Future<Map<String, dynamic>> buildPayload() async {
    final selectedIds = Stores.setting.watchServerIds.fetch();
    final existingTokens = await _existingTokens();
    final tokens = reusableTokens(
      selectedIds: selectedIds,
      lookup: Stores.server.fetchOneRaw,
      existingTokens: existingTokens,
    );
    for (final id in selectedIds) {
      final spi = Stores.server.fetchOneRaw(id);
      final monitor = spi?.monitor;
      if (spi == null || monitor == null) continue;
      if (tokens.containsKey(id)) continue;
      final existing = existingTokens[id];
      if (existing != null &&
          existing.endpoint != _normalizedEndpoint(monitor.addr)) {
        await _revokeServer(spi, endpoint: existing.endpoint);
      }
      final client = MonitorHttpClient(monitor);
      try {
        tokens[id] = await client.issueWatchToken('watch:${spi.id}');
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
      // TODO: drop with `SettingStore.watchLegacyUrls`.
      legacyUrls: Stores.setting.watchLegacyUrls.fetch(),
    );
  }

  @visibleForTesting
  static Map<String, String> reusableTokens({
    required List<String> selectedIds,
    required Spi? Function(String id) lookup,
    required Map<String, ({String endpoint, String token})> existingTokens,
  }) {
    final reusable = <String, String>{};
    for (final id in selectedIds) {
      final monitor = lookup(id)?.monitor;
      final existing = existingTokens[id];
      if (monitor != null &&
          existing != null &&
          existing.endpoint == _normalizedEndpoint(monitor.addr)) {
        reusable[id] = existing.token;
      }
    }
    return reusable;
  }

  Future<Map<String, ({String endpoint, String token})>> _existingTokens() async {
    try {
      final raw = await _wc?.applicationContext;
      final servers = raw?['servers'];
      if (servers is! List) return {};
      return {
        for (final entry in servers.whereType<Map>())
          if (entry['id'] is String &&
              entry['addr'] is String &&
              entry['token'] is String)
            entry['id'] as String: (
              endpoint: _normalizedEndpoint(entry['addr'] as String),
              token: entry['token'] as String,
            ),
      };
    } catch (e, s) {
      Loggers.app.info('Could not reuse the current watch token context', e, s);
      return {};
    }
  }

  Future<void> updateSelection(List<String> next) async {
    final previous = Stores.setting.watchServerIds.fetch();
    final nextIds = next.toSet();
    final existingTokens = await _existingTokens();
    for (final id in previous.where((id) => !nextIds.contains(id))) {
      final spi = Stores.server.fetchOneRaw(id);
      if (spi != null) {
        await _revokeServer(spi, endpoint: existingTokens[id]?.endpoint);
      }
    }
    Stores.setting.watchServerIds.put(next);
    await push();
  }

  Future<void> removeServer(Spi spi) async {
    final existingTokens = await _existingTokens();
    await _revokeServer(spi, endpoint: existingTokens[spi.id]?.endpoint);
    final selected = Stores.setting.watchServerIds.fetch();
    if (!selected.contains(spi.id)) return;
    Stores.setting.watchServerIds.put(
      selected.where((id) => id != spi.id).toList(),
    );
    await push();
  }

  Future<void> _revokeSelectedServers() async {
    final existingTokens = await _existingTokens();
    for (final id in Stores.setting.watchServerIds.fetch()) {
      final spi = Stores.server.fetchOneRaw(id);
      if (spi != null) {
        await _revokeServer(spi, endpoint: existingTokens[id]?.endpoint);
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

  static String _normalizedEndpoint(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');

  /// The payload as a pure function of the selection, so the shape the watch
  /// depends on can be tested without a Hive box behind it.
  ///
  /// `servers` carries scoped read-only tokens, so it only ever contains
  /// servers the user explicitly picked for the watch. `urls` is the pre-v2 shape and
  /// is still emitted so a watch app that has not updated yet keeps working.
  @visibleForTesting
  static Map<String, dynamic> payloadFrom({
    required List<String> selectedIds,
    required Spi? Function(String id) lookup,
    required Map<String, String> tokens,
    required List<String> legacyUrls,
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
        'token': token,
        'ignoreCert': monitor.ignoreCert,
      });
    }

    return {
      'v': _payloadVersion,
      'servers': servers,
      // TODO: drop with `SettingStore.watchLegacyUrls`.
      'urls': legacyUrls,
    };
  }

  /// Seeds [SettingStore.watchLegacyUrls] from the application context this app
  /// sent in an older build, which until now was the only place that list
  /// existed.
  ///
  /// TODO: drop with `SettingStore.watchLegacyUrls`.
  Future<void> _importLegacyUrls() async {
    final imported = Stores.setting.watchLegacyUrlsImported;
    if (imported.fetch()) return;

    try {
      final ctx = await _wc?.applicationContext;
      final urls = (ctx?['urls'] as List?)
          ?.whereType<String>()
          .where((e) => e.trim().isNotEmpty)
          .toList();
      if (urls != null && urls.isNotEmpty) {
        Stores.setting.watchLegacyUrls.put(urls);
      }
      imported.put(true);
    } catch (e, s) {
      // Leave the flag unset so the next launch retries; an empty import is
      // indistinguishable from a failed one otherwise.
      Loggers.app.warning('Failed to import legacy watch URLs', e, s);
    }
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
