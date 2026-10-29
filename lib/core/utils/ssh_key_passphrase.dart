import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
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
abstract final class KeyPassphrases {
  static const _prefix = 'sshKeyPassphrase.';

  @visibleForTesting
  static bool Function() enabled = () =>
      Stores.setting.rememberKeyPassphrase.fetch();

  static String _name(String pem) =>
      '$_prefix${blake3Hex(data: utf8.encode(pem))}';

  /// The passphrase kept for [pem]; null when there is none, or no vault on
  /// this isolate (the transfer isolate has none).
  static Future<String?> read(String pem) async {
    try {
      if (!enabled()) return null;
      return await SecureStore.storage.read(key: _name(pem));
    } catch (e, s) {
      Loggers.app.warning('Read key passphrase', e, s);
      return null;
    }
  }

  /// Keeps [passphrase] for [pem], if passphrases are to be remembered.
  static Future<void> write(String pem, String passphrase) async {
    try {
      if (!enabled()) return;
      await SecureStore.storage.write(key: _name(pem), value: passphrase);
    } catch (e, s) {
      Loggers.app.warning('Write key passphrase', e, s);
    }
  }

  static Future<void> delete(String pem) async {
    try {
      await SecureStore.storage.delete(key: _name(pem));
    } catch (e, s) {
      Loggers.app.warning('Delete key passphrase', e, s);
    }
  }

  /// Drops every passphrase but those of [pems], the keys still stored; all of
  /// them while passphrases are not to be remembered.
  static Future<void> prune(Iterable<String> pems) async {
    try {
      if (!enabled()) return await clear();
      await _dropAllBut({for (final pem in pems) _name(pem)});
    } catch (e, s) {
      Loggers.app.warning('Prune key passphrases', e, s);
    }
  }

  /// Drops every passphrase kept.
  static Future<void> clear() async {
    try {
      await _dropAllBut(const {});
    } catch (e, s) {
      Loggers.app.warning('Clear key passphrases', e, s);
    }
  }

  static Future<void> _dropAllBut(Set<String> keep) async {
    final all = await SecureStore.storage.readAll();
    for (final name in all.keys) {
      if (name.startsWith(_prefix) && !keep.contains(name)) {
        await SecureStore.storage.delete(key: name);
      }
    }
  }
}
