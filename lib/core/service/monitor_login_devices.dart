import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:server_box/core/service/scoped_token.dart';

/// Per agent endpoint, the device token its last sign-in gave this app.
///
/// Sent with every later sign-in, it keeps this device out of the agent's
/// account-wide login throttle, so failed attempts from elsewhere cannot lock
/// it out (`monitor/src/api/ratelimit.rs`). It signs nothing in on its own,
/// but it is a credential of sorts, so it lives in the Keychain/Keystore
/// rather than in the synced database: it belongs to this device.
abstract final class MonitorLoginDevices {
  static const _key = 'monitorLoginDevices';

  static Map<String, String>? _cache;
  static Future<void> _writes = Future.value();

  /// How long a sign-in waits for another to the same agent.
  static const _waitForOther = Duration(seconds: 3);

  /// The sign-in running per endpoint, so the next waits for it.
  static final _signingIn = <String, Completer<void>>{};

  /// Where the map is kept. Tests replace it; the platform store is not there.
  @visibleForTesting
  static DeviceTokenStore store = const _SecureDeviceTokenStore();

  @visibleForTesting
  static void resetForTest() {
    _cache = null;
    _signingIn.clear();
  }

  static Future<Map<String, String>> _all() async {
    final cached = _cache;
    if (cached != null) return cached;
    Map<String, String> loaded;
    try {
      loaded = await store.read() ?? {};
    } catch (e, s) {
      Loggers.app.warning('Read monitor device tokens', e, s);
      loaded = {};
    }
    return _cache ??= loaded;
  }

  /// Runs [signIn] with this device's token for [addr] (null for none yet),
  /// one at a time while there is none.
  ///
  /// The clients a server has (its status, the Monitor tab, its web apps)
  /// sign in together at launch, and before the first one has kept the token
  /// the agent hands out, every one of them would arrive without it and be
  /// listed as a device of its own. Once there is a token there is nothing to
  /// wait for. [abandoned] completes when the caller gives up (its client is
  /// disposed): a sign-in nobody waits for any more must not hold the next.
  static Future<T> signingIn<T>(
    String addr,
    Future<T> Function(String? device) signIn, {
    Future<void>? abandoned,
  }) async {
    if (await of(addr) case final device?) return signIn(device);
    final key = normalizeAgentEndpoint(addr);
    final before = _signingIn[key]?.future;
    final done = Completer<void>();
    _signingIn[key] = done;
    void release() {
      if (!done.isCompleted) done.complete();
      if (identical(_signingIn[key], done)) _signingIn.remove(key);
    }

    unawaited(abandoned?.then((_) => release()));
    try {
      // Not for ever: one hanging on an agent that does not answer would hold
      // every other client of it for as long as its timeouts, a fire-and-
      // forget one with nobody to dispose it longest. Past this the worst is
      // one more device listed.
      await before?.timeout(_waitForOther, onTimeout: () {});
      return await signIn(await of(addr));
    } finally {
      release();
    }
  }

  /// The token [addr]'s agent gave this device, if any.
  static Future<String?> of(String addr) async =>
      (await _all())[normalizeAgentEndpoint(addr)];

  /// Keeps [device], the token [addr]'s agent just gave this device.
  static Future<void> remember(String addr, String device) async {
    final all = await _all();
    all[normalizeAgentEndpoint(addr)] = device;
    final snapshot = Map<String, String>.of(all);
    _writes = _writes.then((_) async {
      try {
        await store.write(snapshot);
      } catch (e, s) {
        Loggers.app.warning('Write monitor device tokens', e, s);
      }
    });
    await _writes;
  }
}

/// Reads and writes the whole endpoint → token map.
abstract interface class DeviceTokenStore {
  Future<Map<String, String>?> read();
  Future<void> write(Map<String, String> all);
}

final class _SecureDeviceTokenStore implements DeviceTokenStore {
  const _SecureDeviceTokenStore();

  @override
  Future<Map<String, String>?> read() async {
    final raw = await SecureStore.storage.read(key: MonitorLoginDevices._key);
    if (raw == null) return null;
    final decoded = json.decode(raw);
    if (decoded is! Map) return null;
    return {
      for (final e in decoded.entries)
        if (e.key is String && e.value is String) e.key as String: e.value as String,
    };
  }

  @override
  Future<void> write(Map<String, String> all) =>
      SecureStore.storage.write(key: MonitorLoginDevices._key, value: json.encode(all));
}

/// An in-memory [DeviceTokenStore] for tests.
@visibleForTesting
final class MemoryDeviceTokenStore implements DeviceTokenStore {
  Map<String, String>? saved;

  @override
  Future<Map<String, String>?> read() async => saved == null ? null : Map.of(saved!);

  @override
  Future<void> write(Map<String, String> all) async => saved = Map.of(all);
}
