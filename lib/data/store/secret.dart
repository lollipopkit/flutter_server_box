import 'package:fl_lib/fl_lib.dart';

/// Each server's saved sudo password, by server id.
final class SudoPasswordStore extends SqliteStore {
  SudoPasswordStore._() : super('sudoPassword');

  static final instance = SudoPasswordStore._();
}

/// Passphrases of encrypted private keys, by the BLAKE3 of the key's bytes
/// (`KeyPassphrases`).
final class KeyPassphraseStore extends SqliteStore {
  KeyPassphraseStore._() : super('keyPassphrase');

  static final instance = KeyPassphraseStore._();
}

/// Where the backup syncs to besides iCloud and LK Cloud: WebDAV's address,
/// user and password (`SyncRemotes`).
final class SyncRemoteStore extends SqliteStore {
  SyncRemoteStore._() : super('syncRemote');

  static final instance = SyncRemoteStore._();
}
