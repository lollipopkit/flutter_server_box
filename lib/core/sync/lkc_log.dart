import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/core/sync/category.dart';
import 'package:server_box/core/sync/key.dart';
import 'package:server_box/core/sync/lkc_prefs.dart';
import 'package:server_box/core/sync/log.dart';
import 'package:server_box/core/utils/temp_file.dart';
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
  Future<bool> putSnapshot(int seq, Uint8List body) => withTempFile('snapshot', (path) async {
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
  Future<({String log, int seq, Uint8List body})?> snapshot() => withTempFile('snapshot', (path) async {
    final s = await _sync.downloadSnapshot(to: path);
    if (s == null) return null;
    return (log: s.log, seq: s.seq, body: await File(path).readAsBytes());
  });

  @override
  Future<void> putBlob(String name, Uint8List body) => withTempFile('blob', (path) async {
    await File(path).writeAsBytes(body, flush: true);
    try {
      await _sync.upload(name: name, from: path);
    } on LkcSyncError catch (e) {
      // Named by its content: the one there is this one.
      if (e.kind != LkcSyncErrorKind.changed) rethrow;
    }
  });

  @override
  Future<Uint8List?> getBlob(String name) => withTempFile('blob', (path) async {
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

/// [SyncKey]'s file on LK Cloud: `identity.age`, written only if unchanged.
final class LkcKeyFile implements SyncKeyFile {
  LkcKeyFile(this._sync, this.id);

  final LkcSync _sync;

  /// The account's id.
  @override
  final String id;

  static const _name = 'identity.age';

  @override
  PrefProp<bool> get rewrap => SyncKey.lkcRewrap;

  @override
  Future<Uint8List?> read() => withTempFile('key', (path) async {
    final fetched = await _sync.download(name: _name, to: path);
    return fetched.missing ? null : File(path).readAsBytes();
  });

  @override
  Future<bool> write(Uint8List body, {required bool replace}) => withTempFile('key', (path) async {
    await File(path).writeAsBytes(body, flush: true);
    final ifMatch = replace ? await _sync.head(name: _name) : null;
    try {
      await _sync.upload(name: _name, from: path, ifMatch: ifMatch);
      return true;
    } on LkcSyncError catch (e) {
      if (e.kind == LkcSyncErrorKind.changed) return false;
      rethrow;
    }
  });
}

/// Runs [LogSync] on LK Cloud while the backup syncs there: on this device's
/// edits (after [_debounce]), on another device's batch ([LkcSyncWatch]), and
/// on every (re)connection, which may have missed some.
abstract final class LkcLogSync {
  static const _debounce = Duration(milliseconds: 500);

  static Future<LogSync>? _opening;
  static SyncKey? _key;
  static Timer? _soon;

  static bool get _wanted =>
      Lkc.enabled && Lkc.client.signedIn && Lkc.client.user.value != null && LkcSyncPrefs.enabled.get();

  static void init() {
    SyncRecorder.onLocal.add(() {
      if (!_wanted) return;
      _soon?.cancel();
      _soon = Timer(_debounce, () => unawaited(sync()));
    });
    // A category carried or not: the log is read again from its start, and
    // everything here sent, so neither side misses what was left out.
    Listenable.merge([for (final c in SyncCategory.values) c.changes]).addListener(() {
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
    LkcSyncPrefs.enabled.listenable().addListener(() {
      // Off: what was said of its key goes with it.
      if (!LkcSyncPrefs.enabled.get()) {
        if (_keyOf case final id?) SyncKey.forgetMismatch(id);
      }
      unawaited(sync());
    });
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
    _keyOf = user.id;
    final key = _key = await SyncKey.load(LkcKeyFile(sync, user.id));
    LogSync.bind(user.id);
    return LogSync(
      LkcLogTransport(sync),
      key,
      carries: syncCarries,
    );
  }

  /// The account's sync key, as the log sync holds it: loaded (and sealed
  /// again after a password change) in one place.
  static Future<SyncKey> key() async {
    await (_opening ??= _open());
    return _key!;
  }

  /// Replaces the account's sync key (a device that held it is gone):
  /// what is written from now on is sealed to a new one. What the account
  /// refuses is thrown for the user to see; calling it with sync off is a
  /// programming error, as nothing offers it then.
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
    if (_keyOf case final id?) SyncKey.forgetMismatch(id);
    _keyOf = null;
  }

  /// The account whose key file [_opening] read.
  static String? _keyOf;
}
