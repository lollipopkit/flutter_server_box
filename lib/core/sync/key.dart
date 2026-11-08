import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/sync/log.dart';
import 'package:server_box/data/model/app/error.dart';

/// Where a [SyncKey] keeps its keys beside what they seal: `identity.age`.
abstract interface class SyncKeyFile {
  /// Which keys these are in the synced keychain (`syncIdentity.<id>`).
  String get id;

  /// The file and its version, null when there is none.
  Future<({Uint8List body, String version})?> read();

  /// [body] as the file if it is still at [ifVersion] (none there for null):
  /// its new version, null when it is not. A store that does not order
  /// writes checks just before writing.
  Future<String?> write(Uint8List body, {required String? ifVersion});

  /// Whether a file may be made where none is read: false where one may only
  /// not have arrived yet (a store that does not order writes, holding what
  /// was synced with one).
  Future<bool> canCreate();
}

/// No key file is there yet beside what was synced with one: it may only not
/// have arrived. Tried again at the next sync.
final class SyncKeyNotHere implements Exception {
  const SyncKeyNotHere(this.id);

  final String id;

  @override
  String toString() => 'The sync key of $id is not here yet';
}

/// A remote's sync key, which seals everything synced there: age X25519
/// identities, the newest sealing and the ones it replaced ([rotate]) still
/// opening, so a device that joins later reads what was sealed before.
///
/// Kept in the remote's [SyncKeyFile], sealed with the backup password: the
/// one thing the password seals. Its first line, a comment `age -i` skips,
/// says the file's epoch, raised each time it is sealed with a new password.
/// Each device keeps the keys in the synced keychain.
///
/// The password is the remote's gate: where it does not open the file,
/// nothing syncs there ([SyncPasswordMismatch]) until it does. A device that
/// changed it ([passwordChanged]) seals the file again with the new one,
/// opening it with the one it changed from, unless another device sealed it
/// since.
final class SyncKey implements SyncSeal {
  SyncKey._(this._file);

  final SyncKeyFile _file;

  /// The newest first: what is sealed now, then what was before.
  List<String> _identities = const [];
  String _recipient = '';

  /// The file's epoch, as last read or written here.
  int _epoch = 0;

  /// The file's version and the password that opened it here: a check that
  /// finds both unchanged derives no key.
  ({String version, String password})? _opened;

  /// The password the file refused last: with it, none is put in its place
  /// when it is gone.
  String? _refused;

  DateTime? _checkedAt;
  Future<void>? _checking;

  /// The keys kept after a [rotate], besides the newest.
  static const _history = 3;

  /// How long a check stands: one per sync would derive a key each time.
  static const _recheckAfter = Duration(minutes: 1);

  static final _keys = <String, SyncKey>{};

  /// The key files ([SyncKeyFile.id]) the backup password here does not
  /// open. Nothing syncs to their remotes meanwhile.
  static final passwordMismatch = ValueNotifier<Set<String>>(const {});

  /// [file]'s key, opened with the backup password here: one per remote,
  /// checked again at most every [_recheckAfter]. Throws
  /// [SyncPasswordMismatch] while the password does not open it. Without
  /// [create] (a restore, nothing synced), none is put where there is none:
  /// [SyncKeyNotHere].
  static Future<SyncKey> of(SyncKeyFile file, {bool create = true}) async {
    final fresh = !_keys.containsKey(file.id);
    final key = _keys[file.id] ??= SyncKey._(file);
    try {
      await key.check(create: create);
    } catch (_) {
      // A restore's lookup leaves nothing behind for a remote nothing syncs
      // to; a sync's stays, to be checked again.
      if (!create && fresh && identical(_keys[file.id], key)) _keys.remove(file.id);
      rethrow;
    }
    return key;
  }

  /// [id]'s remote is not synced here any more (turned off): its key is
  /// read again next time, and nothing is said of it meanwhile.
  static void release(String id) {
    _keys.remove(id);
    _said(id, mismatch: false);
  }

  /// [id]'s remote is gone from this device (signed out, another server):
  /// as [release], and what this device knew of its file goes too.
  static Future<void> forget(String id) async {
    release(id);
    await _setEpoch(id, null);
    await _setPending(id, null);
  }

  /// Before the backup password here changes from [previous]: the files of
  /// the syncs on here, opened with it, are to be sealed with the new one
  /// ([check]). Kept on this device until then, so a restart or a remote out
  /// of reach meanwhile loses nothing; a file already waiting keeps the
  /// password it is sealed with. A sync that is off keeps nothing of it: the
  /// password its file is sealed with is asked for when it is on again.
  static Future<void> passwordChanged(String? previous) async {
    if (previous == null || previous.isEmpty) return;
    final pending = await _pendingAll();
    // Also one not opened yet (out of reach), or refused: [previous] that
    // does not open it is dropped when tried.
    for (final id in _keys.keys) {
      pending.putIfAbsent(id, () => previous);
    }
    await _writePending(pending);
  }

  /// [sealed] opened with a key of a sync on here that the password opens,
  /// looking again for newer keys when none does: what was downloaded from
  /// one of them.
  static Future<Uint8List> openAny(Uint8List sealed) async {
    final keys = [for (final k in _keys.values) if (k._opened != null) k];
    final identities = [for (final k in keys) ...k._identities];
    try {
      return await AgeCryptor.decryptWithAny(sealed, identities);
    } on FormatException {
      for (final k in keys) {
        if (await k.refresh()) return openAny(sealed);
      }
      rethrow;
    }
  }

  /// [sealed] opened with any key this device keeps, whatever syncs here now:
  /// a synced backup the person picked to restore. Not one of a remote the
  /// password here is refused by.
  static Future<Uint8List> openKept(Uint8List sealed) async {
    final refused = passwordMismatch.value;
    final identities = {
      for (final MapEntry(key: id, value: k) in _keys.entries)
        if (!refused.contains(id)) ...k._identities,
      for (final id in (await _epochs()).keys)
        if (!refused.contains(id)) ..._lines(await _kept(id).read()),
    }.toList();
    if (identities.isEmpty) throw const FormatException('No sync key kept here');
    return AgeCryptor.decryptWithAny(sealed, identities);
  }

  /// Every key in use checked again now: the password here changed.
  static Future<void> recheck() async {
    for (final key in _keys.values) {
      key._checkedAt = null;
    }
    await Future.wait([
      for (final key in _keys.values.toList())
        key.check().catchError((Object e, StackTrace s) {
          if (e is! SyncPasswordMismatch) Loggers.app.warning('Check ${key._file.id}', e, s);
        }),
    ]);
  }

  /// Whether [data] is sealed to a key, as [seal] seals it; one sealed with a
  /// password otherwise, or not at all.
  static bool sealedToKey(List<int> data) => _startsWith(data, _keySealed);

  static final _keySealed = utf8.encode('${AgeCryptor.binaryHeader}-> X25519 ');

  static bool _startsWith(List<int> data, List<int> head) {
    if (data.length < head.length) return false;
    for (var i = 0; i < head.length; i++) {
      if (data[i] != head[i]) return false;
    }
    return true;
  }

  @visibleForTesting
  static void resetForTest() {
    _keys.clear();
    passwordMismatch.value = const {};
  }

  /// Opened with the backup password here, read again past
  /// [_recheckAfter], or now with [force]. Throws [SyncPasswordMismatch]
  /// while the password does not open the file.
  Future<void> check({bool force = false, bool create = true}) async {
    if (force) _checkedAt = null;
    final at = _checkedAt;
    if (at != null && DateTime.now().difference(at) < _recheckAfter) {
      if (passwordMismatch.value.contains(_file.id)) throw SyncPasswordMismatch(_file.id);
      return;
    }
    final checking = _checking ??= _check(create).whenComplete(() => _checking = null);
    await checking;
  }

  Future<void> _check(bool create) async {
    if (_identities.isEmpty) await _use(_lines(await _kept(_file.id).read()));
    // Once more when the password changed meanwhile: what was opened with the
    // one before is to be sealed with it.
    for (var pwd = await _password(); ; ) {
      try {
        await _open(pwd, create);
      } on SyncPasswordMismatch {
        _checkedAt = DateTime.now();
        rethrow;
      }
      final now = await _password();
      if (now == pwd) break;
      pwd = now;
    }
    // Opened with the password here as it is now: nothing waits any more.
    await _setPending(_file.id, null);
    _checkedAt = DateTime.now();
  }

  Future<void> _open(String pwd, bool create) async {
    final id = _file.id;
    while (true) {
      final remote = await _file.read();
      if (remote == null) {
        // None to open: put there, unless the password here was refused
        // there, so nothing it seals replaces what another device sealed.
        if (_refused == pwd) throw SyncPasswordMismatch(id);
        final knew = (await _epochs())[id] != null && _identities.isNotEmpty;
        // A device that opened it before puts back the keys it holds; another
        // makes none where synced data may only be waiting for its key.
        if (!create || (!knew && !await _file.canCreate())) throw SyncKeyNotHere(id);
        final identities = _identities.isNotEmpty ? _identities : [(await AgeCryptor.generateKey()).identity];
        final epoch = (await _epochs())[id] ?? 0;
        final version = await _file.write(await _sealed(identities, epoch, pwd), ifVersion: null);
        if (version == null) continue;
        await _use(identities, save: true);
        return _openedAt(epoch, version, pwd);
      }
      if (_opened case (:final version, :final password) when version == remote.version && password == pwd) {
        return _said(id, mismatch: false);
      }
      final opened = await _read(remote.body, pwd);
      if (opened != null) {
        if (await _take(opened, remote.version, pwd)) return;
        continue;
      }
      _opened = null;
      final previous = (await _pendingAll())[id];
      if (previous != null && previous != pwd) {
        final old = await _read(remote.body, previous);
        final verified = (await _epochs())[id];
        // Not if another device sealed it since this one last opened it:
        // that one's password is the remote's now.
        if (old != null && (verified == null || old.epoch == verified)) {
          final identities = _merged(old.identities);
          final epoch = old.epoch + 1;
          final version = await _file.write(await _sealed(identities, epoch, pwd), ifVersion: remote.version);
          if (version == null) continue;
          await _use(identities, save: true);
          return _openedAt(epoch, version, pwd);
        }
        await _setPending(id, null);
      }
      _refused = pwd;
      _said(id, mismatch: true);
      throw SyncPasswordMismatch(id);
    }
  }

  /// The keys [opened] holds taken, at [version]. One that lacks the key this
  /// device seals with (put there by a device that made its own at the same
  /// time, on a store that does not order writes) is written again with it,
  /// so the other devices read what it sealed; false when the file changed
  /// meanwhile.
  Future<bool> _take(({int epoch, List<String> identities}) opened, String version, String pwd) async {
    final remote = opened.identities;
    final current = _identities.firstOrNull;
    if (current == null || remote.contains(current)) {
      await _use(_merged(remote), save: true);
      await _openedAt(opened.epoch, version, pwd);
      return true;
    }
    // The file's newest stays first: every device then seals with it.
    final identities = _merged([remote.first, current, ...remote.skip(1)]);
    final written = await _file.write(await _sealed(identities, opened.epoch, pwd), ifVersion: version);
    if (written == null) return false;
    await _use(identities, save: true);
    await _openedAt(opened.epoch, written, pwd);
    return true;
  }

  Future<void> _openedAt(int epoch, String version, String pwd) async {
    _epoch = epoch;
    _opened = (version: version, password: pwd);
    _refused = null;
    await _setEpoch(_file.id, epoch);
    _said(_file.id, mismatch: false);
  }

  /// A new key in place of this one, put in the file first, so a device that
  /// meets what it seals finds it there ([refresh]). Fails, changing nothing
  /// here, when another device changed the file meanwhile.
  Future<void> rotate() async {
    await check(force: true);
    final pwd = await _password();
    final identities = [(await AgeCryptor.generateKey()).identity, ..._identities].take(_history + 1).toList();
    final version = await _file.write(await _sealed(identities, _epoch, pwd), ifVersion: _opened?.version);
    if (version == null) throw StateError('identity.age changed meanwhile');
    await _use(identities, save: true);
    await _openedAt(_epoch, version, pwd);
  }

  /// Reads the file again, after something did not [open]: whether it held
  /// keys not here (the key was replaced elsewhere).
  @override
  Future<bool> refresh() async {
    final before = _identities.toSet();
    await check(force: true);
    return !_identities.every(before.contains);
  }

  /// [other] first, then those kept here, at most [_history] besides the
  /// newest.
  List<String> _merged(List<String> other) => {...other, ..._identities}.take(_history + 1).toList();

  Future<void> _use(List<String> identities, {bool save = false}) async {
    if (identities.isEmpty) return;
    final changed = !listEquals(identities, _identities);
    _identities = identities;
    if (changed || _recipient.isEmpty) _recipient = await AgeCryptor.recipientOf(identities.first);
    if (save && changed) await _kept(_file.id).write(identities.join('\n'));
  }

  static final _epochLine = RegExp(r'^#.*\bepoch (\d+)$');

  /// [sealed] opened with [pwd]: its epoch and keys, the newest first; null
  /// when [pwd] does not open it. A file with no epoch line is epoch 0.
  static Future<({int epoch, List<String> identities})?> _read(Uint8List sealed, String pwd) async {
    final Uint8List plain;
    try {
      plain = await AgeCryptor.decrypt(sealed, pwd);
    } on WrongPasswordException {
      return null;
    }
    var epoch = 0;
    final lines = _lines(utf8.decode(plain), comments: true);
    if (lines.firstOrNull case final first? when first.startsWith('#')) {
      epoch = int.tryParse(_epochLine.firstMatch(first)?.group(1) ?? '') ?? 0;
    }
    final identities = [for (final l in lines) if (!l.startsWith('#')) l];
    if (identities.isEmpty) throw const FormatException('identity.age holds no key');
    return (epoch: epoch, identities: identities);
  }

  static Future<Uint8List> _sealed(List<String> identities, int epoch, String pwd) async {
    final text = ['# ServerBox sync key, epoch $epoch', ...identities].join('\n');
    return utf8.encode(await AgeCryptor.encrypt(utf8.encode(text), pwd));
  }

  static List<String> _lines(String? text, {bool comments = false}) => [
    for (final l in text?.split('\n') ?? const <String>[])
      if (l.trim() case final t when t.isNotEmpty && (comments || !t.startsWith('#'))) t,
  ];

  static void _said(String id, {required bool mismatch}) {
    final now = passwordMismatch.value;
    if (now.contains(id) == mismatch) return;
    passwordMismatch.value = mismatch ? {...now, id} : ({...now}..remove(id));
  }

  static Future<String> _password() async {
    final pwd = await SecureStoreProps.bakPwd.read();
    if (pwd == null || pwd.isEmpty) throw const RemoteBackupPasswordMissing();
    return pwd;
  }

  /// The keys of [id], one per line, the newest first; kept beside the
  /// backup password: another Apple device of the person's has them with no
  /// passphrase asked.
  static SecureProp _kept(String id) => SecureProp(
    'syncIdentity.$id',
    storage: SecureStore.synced,
    legacy: SecureStore.storage,
  );

  /// Each key file's epoch as this device last opened it (JSON). Device
  /// local. Key is permanent.
  static const _epochsProp = PrefProp<String>('sync_key_epochs');

  static Future<Map<String, int>> _epochs() async => {
    for (final MapEntry(:key, :value) in _decoded(_epochsProp.get()).entries)
      if (value is int) key: value,
  };

  static Future<void> _setEpoch(String id, int? epoch) async {
    final all = await _epochs();
    if (all[id] == epoch) return;
    epoch == null ? all.remove(id) : all[id] = epoch;
    all.isEmpty ? await _epochsProp.remove() : await _epochsProp.set(jsonEncode(all));
  }

  /// The password each key file is still sealed with after a change here
  /// ([passwordChanged]), JSON. On this device only, until the file is
  /// sealed again. Key is permanent.
  static const _pendingProp = SecureProp('syncKeyPending');

  static Future<Map<String, String>> _pendingAll() async => {
    // Past the rate limit: a sync is not a user asking.
    for (final MapEntry(:key, :value) in _decoded(await _pendingProp.storage.read(key: _pendingProp.key)).entries)
      if (value is String && value.isNotEmpty) key: value,
  };

  static Future<void> _setPending(String id, String? pwd) async {
    final all = await _pendingAll();
    if (all[id] == pwd) return;
    pwd == null ? all.remove(id) : all[id] = pwd;
    await _writePending(all);
  }

  static Future<void> _writePending(Map<String, String> all) =>
      _pendingProp.storage.write(key: _pendingProp.key, value: all.isEmpty ? null : jsonEncode(all));

  static Map<String, Object?> _decoded(String? raw) {
    if (raw == null) return const {};
    try {
      return switch (jsonDecode(raw)) {
        final Map<String, Object?> m => m,
        _ => const {},
      };
    } on FormatException {
      return const {};
    }
  }

  @override
  Future<Uint8List> seal(Uint8List plain) => AgeCryptor.encryptTo(plain, _recipient);

  @override
  Future<Uint8List> open(Uint8List sealed) => AgeCryptor.decryptWithAny(sealed, _identities);

  /// [open], once more after looking for a newer key when none kept here
  /// opens it (it was replaced elsewhere).
  Future<Uint8List> openFresh(Uint8List sealed) async {
    try {
      return await open(sealed);
    } on FormatException {
      if (!await refresh()) rethrow;
      return open(sealed);
    }
  }

  @override
  String nameOf(List<int> data) => syncBlobName(secret: _identities.first, data: data);
}
