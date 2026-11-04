import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/sync/log.dart';
import 'package:server_box/data/model/app/error.dart';

/// Where a [SyncKey] keeps its keys beside what they seal: `identity.age`.
abstract interface class SyncKeyFile {
  /// Which keys these are in the synced keychain (`syncIdentity.<id>`).
  String get id;

  /// Set when the backup password changed here: the file is sealed again
  /// with the new one at the next [SyncKey.load]. Device-local.
  PrefProp<bool> get rewrap;

  /// The file, null when there is none.
  Future<Uint8List?> read();

  /// [body] as the file; false when one was there already (not [replace]),
  /// or, where the store can tell, it changed meanwhile.
  Future<bool> write(Uint8List body, {required bool replace});
}

/// An account's sync key: an
/// age X25519 identity, made by the first device and kept in a
/// [SyncKeyFile], sealed with the backup password, with the ones it replaced
/// ([rotate]), so what was sealed before stays readable to a device that
/// joins after. Each device keeps them in the synced keychain once read.
final class SyncKey implements SyncSeal {
  SyncKey._(this._file, this._identities, this._recipient);

  final SyncKeyFile _file;

  /// The newest first: what is sealed now, then what was before.
  List<String> _identities;
  String _recipient;

  /// The keys kept after a [rotate], besides the newest.
  static const _history = 3;

  /// LK Cloud's ([SyncKeyFile.rewrap]). Key is permanent.
  static const lkcRewrap = PrefProp<bool>('lkc_sync_key_rewrap');

  /// WebDAV's and iCloud's ([SyncKeyFile.rewrap]). Key is permanent.
  static const filesRewrap = PrefProp<bool>('files_sync_key_rewrap');

  /// The keys of [id], one per line, the newest first; kept beside the
  /// backup password: another Apple device of the person's has them with no
  /// passphrase asked.
  static SecureProp _kept(String id) => SecureProp(
    'syncIdentity.$id',
    storage: SecureStore.synced,
    legacy: SecureStore.storage,
  );

  /// The password before the change the rewrap flags stand for, while this
  /// run lasts: what the files are still sealed with. Memory only.
  static String? _previous;

  /// The key: kept here, else the file's, else a new one put there (only one
  /// device's new key is taken where the store orders writes; where it does
  /// not, the keys are merged when one meets the other's: [refresh]).
  static Future<SyncKey> load(SyncKeyFile file) async {
    final kept = _lines(await _kept(file.id).read());
    if (kept.isNotEmpty) {
      final key = SyncKey._(file, kept, await AgeCryptor.recipientOf(kept.first));
      if (file.rewrap.get() ?? false) await key._rewrapped();
      return key;
    }
    while (true) {
      final remote = await _fetch(file);
      final identities = remote ?? [(await AgeCryptor.generateKey()).identity];
      if (remote == null && !await _put(file, identities, replace: false)) continue;
      final key = SyncKey._(file, identities, await AgeCryptor.recipientOf(identities.first));
      await key._save();
      await file.rewrap.remove();
      return key;
    }
  }

  /// After the user changed the backup password on this device, from
  /// [previous]: each key file is sealed with the new one at its next
  /// [load]. Only here: the other devices take the new password and find it
  /// done.
  static Future<void> passwordChanged(String? previous) async {
    _previous = previous;
    await lkcRewrap.set(true);
    await filesRewrap.set(true);
  }

  /// The file sealed with the new password, holding the keys it held (read
  /// with the old one, or the new if another device was first) and these.
  Future<void> _rewrapped() async {
    List<String>? remote;
    for (final pwd in [?_previous, null]) {
      try {
        remote = await _fetch(_file, password: pwd);
        break;
      } on WrongPasswordException {
        continue;
      }
    }
    final identities = remote == null ? _identities : _merged(remote, newest: false);
    if (!await _put(_file, identities, replace: true)) throw StateError('identity.age changed meanwhile');
    await _adopt(identities);
    await _file.rewrap.remove();
    if (!(lkcRewrap.get() ?? false) && !(filesRewrap.get() ?? false)) _previous = null;
  }

  /// A new key in place of this one, put in the file first, so a device that
  /// meets what it seals finds it there ([refresh]). Fails, changing
  /// nothing here, when another device changed the file meanwhile.
  Future<void> rotate() async {
    await refresh();
    final identities = _merged([(await AgeCryptor.generateKey()).identity]);
    if (!await _put(_file, identities, replace: true)) throw StateError('identity.age changed meanwhile');
    await _adopt(identities);
  }

  /// Takes the keys the file holds that are not here. One that lacks the key
  /// this device seals with (put there by a device that made its own at the
  /// same time, on a store that does not order writes; or removed) is
  /// written again with it, so the other devices read what it sealed.
  @override
  Future<bool> refresh() async {
    while (true) {
      final remote = await _fetch(_file);
      if (remote == null) {
        if (await _put(_file, _identities, replace: false)) return false;
        continue;
      }
      final current = _identities.first;
      final found = !remote.every(_identities.contains);
      if (remote.contains(current)) {
        if (found) await _adopt(_merged(remote));
        return found;
      }
      // The file's newest stays first where it has keys new here: every
      // device then seals with it.
      final identities = found ? _merged([remote.first, current, ...remote.skip(1)]) : _identities;
      if (!await _put(_file, identities, replace: true)) continue;
      await _adopt(identities);
      return found;
    }
  }

  /// [other] and those kept here, at most [_history] besides the newest:
  /// [other] first when [newest] (a key just made or found), else this
  /// device's current key stays first.
  List<String> _merged(List<String> other, {bool newest = true}) =>
      (newest ? {...other, ..._identities} : {..._identities, ...other}).take(_history + 1).toList();

  Future<void> _adopt(List<String> identities) async {
    _identities = identities;
    _recipient = await AgeCryptor.recipientOf(identities.first);
    await _save();
  }

  static List<String> _lines(String? text) =>
      text?.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList() ?? const [];

  Future<void> _save() => _kept(_file.id).write(_identities.join('\n'));

  /// The file's keys, the newest first; null when there is none. Opened with
  /// [password], else the backup password.
  static Future<List<String>?> _fetch(SyncKeyFile file, {String? password}) async {
    final sealed = await file.read();
    if (sealed == null) return null;
    final keys = _lines(utf8.decode(await AgeCryptor.decrypt(sealed, password ?? await _password())));
    return keys.isEmpty ? null : keys;
  }

  static Future<bool> _put(SyncKeyFile file, List<String> identities, {required bool replace}) async {
    final sealed = await AgeCryptor.encrypt(utf8.encode(identities.join('\n')), await _password());
    return file.write(utf8.encode(sealed), replace: replace);
  }

  static Future<String> _password() async {
    final pwd = await SecureStoreProps.bakPwd.read();
    if (pwd == null || pwd.isEmpty) throw const RemoteBackupPasswordMissing();
    return pwd;
  }

  @override
  Future<Uint8List> seal(Uint8List plain) => AgeCryptor.encryptTo(plain, _recipient);

  @override
  Future<Uint8List> open(Uint8List sealed) async {
    for (final identity in _identities) {
      try {
        return await AgeCryptor.decryptWith(sealed, identity);
      } on FormatException {
        continue;
      }
    }
    throw const FormatException('Sealed to no key kept here');
  }

  @override
  String nameOf(List<int> data) => syncBlobName(secret: _identities.first, data: data);
}
