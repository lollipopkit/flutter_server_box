import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/src/rust/api/digest.dart';

/// Passphrases of encrypted private keys, kept in the system vault while
/// [SettingStore.rememberKeyPassphrase] is on.
///
/// The key itself stays encrypted in the database, and so in every backup;
/// only this device's vault can open it without asking.
///
/// Named by the BLAKE3 of the key's bytes rather than its id: a passphrase
/// kept for other bytes never meets these, a key referred to by path is
/// covered as well, and a restore bringing the same key back finds it.
///
/// The names kept are listed in one more entry, so that clearing them never
/// reads the rest of the vault. Every call is queued behind the one before:
/// a delete and the write after it land in that order.
abstract final class KeyPassphrases {
  static const _prefix = 'sshKeyPassphrase.';
  static const _index = 'sshKeyPassphrases';

  @visibleForTesting
  static bool Function() enabled = () =>
      Stores.setting.rememberKeyPassphrase.fetch();

  static FlutterSecureStorage get _vault => SecureStore.storage;

  static Future<void> _tail = Future.value();

  /// How long a caller waits for its call: a vault that never answers must
  /// not keep a connection waiting. The queue itself waits for the call to
  /// end, so that one running late still lands before the next.
  static const _timeout = Duration(seconds: 10);

  static Future<T> _queued<T>(String what, T fallback, Future<T> Function() f) {
    final op = _tail.then((_) => f());
    _tail = op.then((_) {}, onError: (_) {});
    return op.timeout(_timeout).catchError((Object e, StackTrace s) {
      Loggers.app.warning('$what key passphrase', e, s);
      return fallback;
    });
  }

  /// A queue started in the test's own zone: one finished in another zone
  /// answers there, which a fake clock never runs.
  @visibleForTesting
  static void resetQueue() => _tail = Future.value();

  static String _name(String pem) =>
      '$_prefix${blake3Hex(data: utf8.encode(pem))}';

  static Future<Set<String>> _names() async {
    final raw = await _vault.read(key: _index);
    if (raw == null) return {};
    return {for (final n in jsonDecode(raw) as List) n as String};
  }

  static Future<void> _setNames(Set<String> names) => names.isEmpty
      ? _vault.delete(key: _index)
      : _vault.write(key: _index, value: jsonEncode(names.toList()));

  /// The passphrase kept for [pem]; null when there is none, or no vault on
  /// this isolate (the transfer isolate has none).
  static Future<String?> read(String pem) => _queued('Read', null, () async {
    if (!enabled()) return null;
    return _vault.read(key: _name(pem));
  });

  /// Keeps [passphrase] for [pem], if passphrases are to be remembered.
  static Future<void> write(String pem, String passphrase) =>
      _queued('Write', null, () async {
        if (!enabled()) return;
        final name = _name(pem);
        // Listed first: a name listed without its entry costs a delete that
        // finds nothing, an entry not listed is one nothing would remove.
        final names = await _names();
        if (names.add(name)) await _setNames(names);
        await _vault.write(key: name, value: passphrase);
      });

  static Future<void> delete(String pem) => _queued('Delete', null, () async {
    final name = _name(pem);
    await _vault.delete(key: name);
    // Unlisted only once it is gone, for the same reason.
    final names = await _names();
    if (names.remove(name)) await _setNames(names);
  });

  /// Drops the passphrases of [before] that no key of [after] holds: what an
  /// edit, a delete or a restore left without a key.
  static Future<void> forgetGone(
    Iterable<String> before,
    Iterable<String> after,
  ) {
    final still = after.toSet();
    return Future.wait([
      for (final pem in before.toSet())
        if (!still.contains(pem)) delete(pem),
    ]);
  }

  /// Drops every passphrase kept.
  static Future<void> clear() => _queued('Clear', null, () async {
    for (final name in await _names()) {
      await _vault.delete(key: name);
    }
    await _vault.delete(key: _index);
  });

  /// At launch: what a clear that failed while switching off left behind.
  static Future<void> init() async {
    if (!enabled()) await clear();
  }
}
