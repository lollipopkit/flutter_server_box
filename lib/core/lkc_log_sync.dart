import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/core/log_sync.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/sync_recorder.dart';

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
}

/// The account's sync key (`docs/dev/sync-log.md`, Encryption and keys): an
/// age X25519 identity, made by the first device and kept on LK Cloud as
/// [_file], sealed with the backup password. Each device keeps it, per
/// account, in the synced keychain once read.
final class LkcSyncKey implements SyncSeal {
  LkcSyncKey._(this._identity, this._recipient);

  final String _identity;
  final String _recipient;

  static const _file = 'identity.age';

  /// [account]'s, kept beside the backup password: another Apple device of
  /// the person's has it with no passphrase asked.
  static SecureProp _kept(String account) =>
      SecureProp('syncIdentity.$account', storage: SecureStore.synced, legacy: SecureStore.storage);

  /// Set when the backup password changed here: [_file] is sealed again with
  /// the new one at the next [load]. Device-local.
  static const _rewrap = PrefProp<bool>('lkc_sync_key_rewrap');

  /// The key: kept here, else [_file]'s, else a new one put there (only one
  /// device's new key is taken: a write that loses reads the winner's).
  static Future<LkcSyncKey> load(LkcSync sync, String account) async {
    final kept = await _kept(account).read();
    if (kept != null && kept.isNotEmpty) {
      if (_rewrap.get() ?? false) {
        await _put(sync, kept, replace: true);
        await _rewrap.remove();
      }
      return LkcSyncKey._(kept, await AgeCryptor.recipientOf(kept));
    }
    while (true) {
      final remote = await _withFile('key', (path) async {
        final fetched = await sync.download(name: _file, to: path);
        if (fetched.missing) return null;
        return AgeCryptor.decrypt(await File(path).readAsBytes(), await _password());
      });
      final identity = remote != null ? String.fromCharCodes(remote).trim() : (await AgeCryptor.generateKey()).identity;
      if (remote == null && !await _put(sync, identity, replace: false)) continue;
      await _kept(account).write(identity);
      await _rewrap.remove();
      return LkcSyncKey._(identity, await AgeCryptor.recipientOf(identity));
    }
  }

  /// After the backup password changed on this device: [_file] is sealed
  /// with the new one at once.
  static Future<void> passwordChanged() async {
    await _rewrap.set(true);
    LkcLogSync.reset();
    unawaited(LkcLogSync.sync());
  }

  /// [_file] sealed with the backup password; false when another device's
  /// was put there first ([replace] false).
  static Future<bool> _put(LkcSync sync, String identity, {required bool replace}) =>
      _withFile('key', (path) async {
        await File(path).writeAsString(await AgeCryptor.encrypt(identity.codeUnits, await _password()));
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
  Future<Uint8List> open(Uint8List sealed) => AgeCryptor.decryptWith(sealed, _identity);
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
    Lkc.client.user.addListener(reset);
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

  static Future<LogSync> _open() async {
    final user = Lkc.client.user.value;
    if (user == null) throw StateError('signed out');
    final sync = await Lkc.client.sync(Lkc.app);
    final key = await LkcSyncKey.load(sync, user.id);
    LogSync.bind(user.id);
    return LogSync(
      LkcLogTransport(sync),
      key,
      carries: (c) => c != 'kv:${Stores.setting.name}' || PrefProps.syncAppSettings.get(),
    );
  }

  /// Signed out or in as someone else: opened again for the next.
  static void reset() {
    _soon?.cancel();
    _opening = null;
  }
}
