import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/core/log_sync.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/sync_recorder.dart';
import 'package:server_box/data/store/sync_themes.dart';

/// [LogSync] on LK Cloud: homebase's log (`/v2/sync/serverbox/log`).
final class LkcLogTransport implements SyncLogTransport {
  LkcLogTransport(this._sync);

  final LkcSync _sync;

  @override
  Future<({String log, int seq, bool compact})> append(String key, Uint8List body) async {
    try {
      final a = await _sync.append(key: key, body: body);
      return (log: a.log, seq: a.seq, compact: a.compact);
    } on LkcSyncError catch (e) {
      if (e.kind == LkcSyncErrorKind.refused && e.reason == 'sync_log_full') throw const SyncLogFull();
      rethrow;
    }
  }

  @override
  Future<SyncLogPage> read(int after, String? log) async {
    final r = await _sync.readLog(after: after, log: log);
    if (r.compacted) return SyncLogPage.compacted(log: r.log);
    return SyncLogPage(log: r.log, batches: [for (final b in r.batches) (b.seq, b.body)], more: r.more);
  }

  @override
  Future<bool> putSnapshot(int seq, Uint8List body) => _withFile('snapshot', (path) async {
    await File(path).writeAsBytes(body, flush: true);
    try {
      await _sync.putSnapshot(seq: seq, from: path);
      return true;
    } on LkcSyncError catch (e) {
      if (e.kind == LkcSyncErrorKind.refused && e.reason == 'sync_snapshot_stale') return false;
      rethrow;
    }
  });

  @override
  Future<({String log, int seq, Uint8List body})?> snapshot() => _withFile('snapshot', (path) async {
    final s = await _sync.downloadSnapshot(to: path);
    if (s == null) return null;
    return (log: s.log, seq: s.seq, body: await File(path).readAsBytes());
  });

  @override
  Future<void> putBlob(String name, Uint8List body) => _withFile('blob', (path) async {
    await File(path).writeAsBytes(body, flush: true);
    try {
      await _sync.upload(name: name, from: path);
    } on LkcSyncError catch (e) {
      // Named by its content: the one there is this one.
      if (e.kind != LkcSyncErrorKind.changed) rethrow;
    }
  });

  @override
  Future<Uint8List?> getBlob(String name) => _withFile('blob', (path) async {
    final fetched = await _sync.download(name: name, to: path);
    return fetched.missing ? null : File(path).readAsBytes();
  });

  @override
  Future<List<({String name, DateTime? at})>> blobs(String prefix) async => [
    for (final f in await _sync.list())
      if (f.name.startsWith(prefix)) (name: f.name, at: DateTime.tryParse(f.updatedAt)),
  ];

  @override
  Future<void> deleteBlob(String name) => _sync.delete(name: name);
}

/// The account's sync key (`docs/dev/sync-log.md`, Encryption and keys): an
/// age X25519 identity, made by the first device and kept on LK Cloud as
/// [_file], sealed with the backup password, with the ones it replaced
/// ([rotate]), so what was sealed before stays readable to a device that
/// joins after. Each device keeps them, per account, in the synced keychain
/// once read.
final class LkcSyncKey implements SyncSeal {
  LkcSyncKey._(this._sync, this._account, this._identities, this._recipient);

  final LkcSync _sync;
  final String _account;

  /// The newest first: what is sealed now, then what was before.
  List<String> _identities;
  String _recipient;

  static const _file = 'identity.age';

  /// The keys kept after a [rotate], besides the newest.
  static const _history = 3;

  /// [account]'s keys, one per line, the newest first; kept beside the
  /// backup password: another Apple device of the person's has them with no
  /// passphrase asked.
  static SecureProp _kept(String account) =>
      SecureProp('syncIdentity.$account', storage: SecureStore.synced, legacy: SecureStore.storage);

  /// Set when the backup password changed here: [_file] is sealed again with
  /// the new one at the next [load]. Device-local.
  static const _rewrap = PrefProp<bool>('lkc_sync_key_rewrap');

  /// The password before the change [_rewrap] stands for, while this run
  /// lasts: what [_file] is still sealed with. Memory only.
  static String? _previous;

  /// The key: kept here, else [_file]'s, else a new one put there (only one
  /// device's new key is taken: a write that loses reads the winner's).
  static Future<LkcSyncKey> load(LkcSync sync, String account) async {
    final kept = _lines(await _kept(account).read());
    if (kept.isNotEmpty) {
      final key = LkcSyncKey._(sync, account, kept, await AgeCryptor.recipientOf(kept.first));
      if (_rewrap.get() ?? false) await key._rewrapped();
      return key;
    }
    while (true) {
      final remote = await _fetch(sync);
      final identities = remote ?? [(await AgeCryptor.generateKey()).identity];
      if (remote == null && !await _put(sync, identities, replace: false)) continue;
      final key = LkcSyncKey._(sync, account, identities, await AgeCryptor.recipientOf(identities.first));
      await key._save();
      await _rewrap.remove();
      return key;
    }
  }

  /// After the user changed the backup password on this device, from
  /// [previous]: [_file] is sealed with the new one at once. Only here: the
  /// other devices take the new password and find it done.
  static Future<void> passwordChanged(String? previous) async {
    _previous = previous;
    await _rewrap.set(true);
    LkcLogSync.reset();
    unawaited(LkcLogSync.sync());
  }

  /// [_file] sealed with the new password, holding the keys it held (read
  /// with the old one, or the new if another device was first) and these.
  Future<void> _rewrapped() async {
    List<String>? remote;
    for (final pwd in [?_previous, null]) {
      try {
        remote = await _fetch(_sync, password: pwd);
        break;
      } on WrongPasswordException {
        continue;
      }
    }
    final identities = remote == null ? _identities : _merged(remote, newest: false);
    if (!await _put(_sync, identities, replace: true)) throw StateError('identity.age changed meanwhile');
    await _adopt(identities);
    await _rewrap.remove();
    _previous = null;
  }

  /// A new key in place of this one, put in [_file] first, so a device that
  /// meets what it seals finds it there ([refresh]). Fails, changing
  /// nothing here, when another device changed [_file] meanwhile.
  Future<void> rotate() async {
    await refresh();
    final identities = _merged([(await AgeCryptor.generateKey()).identity]);
    if (!await _put(_sync, identities, replace: true)) throw StateError('identity.age changed meanwhile');
    await _adopt(identities);
  }

  @override
  Future<bool> refresh() async {
    final remote = await _fetch(_sync);
    if (remote == null || remote.every(_identities.contains)) return false;
    await _adopt(_merged(remote));
    return true;
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

  Future<void> _save() => _kept(_account).write(_identities.join('\n'));

  /// [_file]'s keys, the newest first; null when there is none. Opened with
  /// [password], else the backup password.
  static Future<List<String>?> _fetch(LkcSync sync, {String? password}) => _withFile('key', (path) async {
    final fetched = await sync.download(name: _file, to: path);
    if (fetched.missing) return null;
    final keys = _lines(utf8.decode(await AgeCryptor.decrypt(await File(path).readAsBytes(), password ?? await _password())));
    return keys.isEmpty ? null : keys;
  });

  /// [_file] sealed with the backup password; false when another device's
  /// was put there first ([replace] false).
  static Future<bool> _put(LkcSync sync, List<String> identities, {required bool replace}) =>
      _withFile('key', (path) async {
        await File(path).writeAsString(await AgeCryptor.encrypt(utf8.encode(identities.join('\n')), await _password()));
        final ifMatch = replace ? await sync.head(name: _file) : null;
        try {
          await sync.upload(name: _file, from: path, ifMatch: ifMatch);
          return true;
        } on LkcSyncError catch (e) {
          if (e.kind == LkcSyncErrorKind.changed) return false;
          rethrow;
        }
      });

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

/// [run] with a path in a directory of its own, removed after.
Future<T> _withFile<T>(String name, Future<T> Function(String path) run) async {
  final dir = await Directory.systemTemp.createTemp('sb-sync-');
  try {
    return await run('${dir.path}/$name');
  } finally {
    await dir.delete(recursive: true);
  }
}

/// Runs [LogSync] on LK Cloud while the backup syncs there: on this device's
/// edits (after [_debounce]), on another device's batch ([LkcSyncWatch]), and
/// on every (re)connection, which may have missed some.
abstract final class LkcLogSync {
  static const _debounce = Duration(milliseconds: 500);

  static Future<LogSync>? _opening;
  static LkcSyncKey? _key;
  static Timer? _soon;

  static bool get _wanted =>
      Lkc.enabled && Lkc.client.signedIn && Lkc.client.user.value != null && BakSyncer.lkcSync.get();

  static void init() {
    SyncRecorder.onLocal = () {
      if (!_wanted) return;
      _soon?.cancel();
      _soon = Timer(_debounce, () => unawaited(sync()));
    };
    // Settings carried or not: the log is read again from its start, and
    // everything here sent, so neither side misses what was left out.
    PrefProps.syncAppSettings.listenable().addListener(() {
      if (!SqliteDb.isOpen) return;
      final opening = _opening;
      if (opening == null) return LogSync.forget();
      unawaited(opening.then((s) => s.reset()).then((_) => sync(), onError: (Object _) => LogSync.forget()));
    });
    // Signed out, or in as someone else: the next run opens anew.
    Lkc.client.user.addListener(() {
      reset();
      unawaited(sync());
    });
    // Not only on the event stream connecting: a device whose network keeps
    // it from listening still sends what was edited while sync was off.
    BakSyncer.lkcSync.listenable().addListener(() => unawaited(sync()));
    unawaited(sync());
  }

  /// Reads what other devices sent, then sends what this one has.
  static Future<void> sync() => _run((s) => s.sync());

  /// Reads what other devices sent, when the log at [seq] has any not read
  /// here (this device's own append is announced too).
  static Future<void> pull(int seq) => _run((s) async {
    if (LogSync.behind(seq)) await s.pull();
  });

  static Future<void> _run(Future<void> Function(LogSync) run) async {
    if (!_wanted) return;
    final LogSync sync;
    try {
      sync = await (_opening ??= _open());
    } catch (e, s) {
      // Opened again next time: the key, the password or the network may be
      // there by then.
      _opening = null;
      Loggers.app.warning('LK Cloud log sync: opening', e, s);
      return;
    }
    try {
      await run(sync);
    } catch (e, s) {
      Loggers.app.warning('LK Cloud log sync', e, s);
    }
  }

  static Future<LogSync> _open() => _openOnce().catchError((Object e) {
    _opening = null;
    throw e;
  });

  static Future<LogSync> _openOnce() async {
    final user = Lkc.client.user.value;
    if (user == null) throw StateError('signed out');
    final sync = await Lkc.client.sync(Lkc.app);
    final key = _key = await LkcSyncKey.load(sync, user.id);
    LogSync.bind(user.id);
    return LogSync(
      LkcLogTransport(sync),
      key,
      // The themes go with the settings: they are what the settings select.
      carries: (c) => (c != 'kv:${Stores.setting.name}' && c != SyncThemes.c) || PrefProps.syncAppSettings.get(),
    );
  }

  /// The account's sync key, as the log sync holds it: loaded (and sealed
  /// again after a password change) in one place.
  static Future<LkcSyncKey> key() async {
    await (_opening ??= _open());
    return _key!;
  }

  /// Replaces the account's sync key (a device that held it is gone):
  /// what is written from now on is sealed to a new one. Throws what went
  /// wrong, for the user to see.
  static Future<void> rotateKey() async {
    if (!_wanted) throw StateError('LK Cloud sync is off');
    final sync = await (_opening ??= _open());
    await sync.rotate(() => _key!.rotate());
  }

  /// Signed out or in as someone else: opened again for the next.
  static void reset() {
    _soon?.cancel();
    _opening = null;
    _key = null;
  }
}
