import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/src/rust/api/digest.dart';

/// Passphrases of encrypted private keys, kept in [Stores.keyPassphrase]
/// while [SettingStore.rememberKeyPassphrase] is on.
///
/// Named by the BLAKE3 of the key's bytes rather than its id: a passphrase
/// kept for other bytes never meets these, a key referred to by path is
/// covered as well, and a restore bringing the same key back finds it.
abstract final class KeyPassphrases {
  @visibleForTesting
  static bool Function() enabled = () =>
      Stores.setting.rememberKeyPassphrase.fetch();

  static String _name(String pem) => blake3Hex(data: utf8.encode(pem));

  /// The passphrase kept for [pem]; null when there is none.
  static String? read(String pem) =>
      enabled() ? Stores.keyPassphrase.get<String>(_name(pem)) : null;

  /// Keeps [passphrase] for [pem], if passphrases are to be remembered.
  static void write(String pem, String passphrase) {
    if (enabled()) Stores.keyPassphrase.set(_name(pem), passphrase);
  }

  static void delete(String pem) => Stores.keyPassphrase.remove(_name(pem));

  /// Drops the passphrases of [before] that no key of [after] holds: what an
  /// edit, a delete or a restore left without a key.
  static void forgetGone(Iterable<String> before, Iterable<String> after) {
    final still = after.toSet();
    for (final pem in before.toSet()) {
      if (!still.contains(pem)) delete(pem);
    }
  }

  /// Drops every passphrase kept on this device, and nowhere else: turning
  /// remembering off is this device's choice (`SyncRecorder.forgetStore`).
  static void clear() => SyncRecorder.forgetStore(Stores.keyPassphrase);

  /// At launch: none kept while off; the ones builds before kept in the
  /// keychain moved here while on, removed there either way.
  static Future<void> init() async {
    final keep = enabled();
    if (!keep) clear();
    await _leaveKeychain(keep: keep);
  }

  static const _legacyPrefix = 'sshKeyPassphrase.';
  static const _legacyIndex = 'sshKeyPassphrases';

  /// Again at the next launch when the keychain fails.
  /// TODO: remove once no install can still hold them.
  static Future<void> _leaveKeychain({required bool keep}) async {
    final vault = SecureStore.storage;
    try {
      final raw = await vault.read(key: _legacyIndex);
      if (raw == null) return;
      for (final name in [for (final n in jsonDecode(raw) as List) n as String]) {
        final value = await vault.read(key: name);
        final key = name.substring(_legacyPrefix.length);
        if (keep && value != null && Stores.keyPassphrase.get<String>(key) == null) {
          SyncRecorder.adopt(Stores.keyPassphrase, key, value);
        }
        await vault.delete(key: name);
      }
      await vault.delete(key: _legacyIndex);
    } catch (e, s) {
      Loggers.app.warning('Move key passphrases out of the keychain', e, s);
    }
  }
}
