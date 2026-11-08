import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/widgets.dart';
import 'package:server_box/core/sync/category.dart';
import 'package:server_box/core/sync/key.dart';
import 'package:server_box/core/sync/log.dart';
import 'package:server_box/core/sync/remotes.dart';
import 'package:server_box/core/sync/sync.dart';
import 'package:server_box/core/utils/temp_file.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/store/sync_recorder.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';

/// The folder [SegmentSync] keeps its files in, beside the backup.
const _folder = 'srvbox_sync';

/// [SegmentSync]'s folder on WebDAV: `<prefix>srvbox_sync/`.
final class WebdavSyncFiles implements SyncFiles {
  WebdavSyncFiles(this._webdav);

  /// Read on each call: a new one is made when the settings change (a new
  /// password, say), and what is kept of this one must not hold the old.
  final Webdav Function() _webdav;

  WebdavClient get _client => _webdav().client ?? (throw StateError('WebDAV is not set up'));

  String get _dir => '${_webdav().prefix}$_folder/';

  /// The folder made, for the client it was made with.
  (WebdavClient, Future<void>)? _made;

  Future<void> _mkdir() {
    final client = _client;
    if (_made case (final c, final made) when identical(c, client)) return made;
    final made = client.mkdirAll(_dir).catchError((Object e, StackTrace s) {
      _made = null;
      Error.throwWithStackTrace(e, s);
    });
    _made = (client, made);
    return made;
  }

  static int? _status(Object e) => switch (e) {
    WebdavException(:final statusCode) => statusCode,
    DioException(:final response) => response?.statusCode,
    _ => null,
  };

  @override
  Future<void> write(String name, Uint8List body) async {
    await _mkdir();
    await _client.write('$_dir$name', body);
  }

  @override
  Future<void> putBlob(String name, Uint8List body) => write(name, body);

  @override
  Future<Uint8List?> getBlob(String name) async {
    try {
      return await _client.read('$_dir$name');
    } catch (e) {
      if (_status(e) == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<({String name, DateTime? at})>> blobs(String prefix) async {
    final List<WebdavFile> files;
    try {
      files = await _client.readDir(_dir);
    } catch (e) {
      if (_status(e) == 404) return const [];
      rethrow;
    }
    return [
      for (final f in files)
        if (!f.isDir && f.name.startsWith(prefix)) (name: f.name, at: f.modified),
    ];
  }

  @override
  Future<void> deleteBlob(String name) async {
    try {
      await _client.remove('$_dir$name');
    } catch (e) {
      if (_status(e) != 404) rethrow;
    }
  }
}

/// [SegmentSync]'s folder in the app's iCloud container: `srvbox_sync/`.
final class ICloudSyncFiles implements SyncFiles {
  ICloudSyncFiles(this._icloud);

  final ICloud _icloud;

  static const _dir = '$_folder/';

  @override
  Future<void> write(String name, Uint8List body) => withTempFile(name, (path) async {
    await File(path).writeAsBytes(body, flush: true);
    await _icloud.upload(relativePath: '$_dir$name', localPath: path);
  });

  @override
  Future<void> putBlob(String name, Uint8List body) => write(name, body);

  /// A download iCloud says nothing of for this long fails, and is tried
  /// again at the next sync: the reads are one at a time, and one iCloud
  /// never ended held every later sync behind it.
  static const _downloadIdle = Duration(minutes: 2);

  @override
  Future<Uint8List?> getBlob(String name) => withTempFile(name, (path) async {
    try {
      await _icloud.download(relativePath: '$_dir$name', localPath: path, idle: _downloadIdle);
    } on TimeoutException {
      rethrow;
    } catch (_) {
      if (!await _icloud.exists('$_dir$name')) return null;
      rethrow;
    }
    return File(path).readAsBytes();
  });

  @override
  Future<List<({String name, DateTime? at})>> blobs(String prefix) async => [
    for (final f in await _icloud.list())
      if (!f.isDirectory && f.relativePath.startsWith('$_dir$prefix'))
        (name: f.relativePath.substring(_dir.length), at: f.contentChangeDate),
  ];

  @override
  Future<void> deleteBlob(String name) => _icloud.delete('$_dir$name');
}

/// [SyncKey]'s file beside the segments: `identity.age`. The store does not
/// order writes: a write checks the file just before, and two devices that
/// make a key at the same moment each write theirs, which the next
/// [SyncKey.check] merges.
final class FilesKeyFile implements SyncKeyFile {
  FilesKeyFile(this._files, this.id);

  final SyncFiles _files;

  static const _name = 'identity.age';

  /// The store's: another store's keys are not taken to it.
  @override
  final String id;

  /// The file itself: a few hundred bytes.
  static String _versionOf(Uint8List body) => base64.encode(body);

  @override
  Future<({Uint8List body, String version})?> read() async {
    final body = await _files.getBlob(_name);
    return body == null ? null : (body: body, version: _versionOf(body));
  }

  /// Only beside nothing synced (no segment, no snapshot): with one there,
  /// its key may not have arrived yet.
  @override
  Future<bool> canCreate() async =>
      !(await _files.blobs('')).any((f) => f.name.startsWith('seg-') || f.name.startsWith('snap-'));

  @override
  Future<String?> write(Uint8List body, {required String? ifVersion}) async {
    final now = await read();
    if (now?.version != ifVersion) return null;
    await _files.write(_name, body);
    return _versionOf(body);
  }
}

/// Runs [SegmentSync] while the backup syncs to WebDAV or iCloud: on this
/// device's edits (after [_debounce]), at launch, on resume, and every
/// [_every] in the foreground, as neither tells of another device's write.
abstract final class FileLogSync {
  static const _debounce = Duration(seconds: 2);
  static const _every = Duration(minutes: 5);

  static Future<SegmentSync>? _opening;

  /// The store [_opening] is of.
  static String? _openedFor;
  static Timer? _soon;

  /// [rs], when it is one of these.
  static ({String id, SyncFiles files})? _storeOf(RemoteStorage? rs) => switch (rs) {
    final ICloud icloud => (id: 'icloud:${icloud.containerId}', files: ICloudSyncFiles(icloud)),
    // Named by a keyed hash: no endpoint written to device-local state again.
    final Webdav webdav when webdav.client != null => (
      id: 'webdav:${syncBlobName(
        secret: _folder,
        data: utf8.encode('${webdav.identity}|${SyncRemotes.webdavUser}'),
      )}',
      files: WebdavSyncFiles(() => SyncRemotes.webdav),
    ),
    _ => null,
  };

  static bool get _on => (PrefProps.icloudSync.get() && isICloudSupported) || PrefProps.webdavSync.get();

  /// [rs]'s sync key, opened with the password here ([SyncKey.of]): what
  /// its segments and the backup are sealed with.
  static Future<SyncKey> keyOf(RemoteStorage rs) {
    final store = _storeOf(rs);
    if (store == null) throw StateError('Not a store of segments: ${rs.runtimeType}');
    return SyncKey.of(FilesKeyFile(store.files, store.id));
  }

  static void init() {
    SyncRecorder.onLocal.add(() {
      if (!_on) return;
      _soon?.cancel();
      _soon = Timer(_debounce, () => unawaited(sync()));
    });
    // A category carried or not: every device is read again from its start,
    // and everything here sent, so neither side misses what was left out.
    Listenable.merge([for (final c in SyncCategory.values) c.changes]).addListener(() {
      if (!SqliteDb.isOpen) return;
      final opening = _opening;
      if (opening == null) return SegmentSync.forget();
      unawaited(opening.then((s) => s.reset()).then((_) => sync(), onError: (Object _) => SegmentSync.forget()));
    });
    for (final prop in [PrefProps.icloudSync, PrefProps.webdavSync]) {
      prop.listenable().addListener(() => unawaited(sync()));
    }
    AppLifecycleListener(onResume: () => unawaited(sync()));
    Timer.periodic(_every, (_) {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed || state == AppLifecycleState.inactive) {
        unawaited(sync());
      }
    });
    unawaited(sync());
  }

  /// Reads what other devices wrote, then writes what this one has.
  static Future<void> sync() async {
    if (!SqliteDb.isOpen) return;
    final rs = _on ? bakSync.remoteStorage : null;
    final store = _storeOf(rs);
    if (store?.id != _openedFor) {
      // Off: read again when on. Another store in its place: this one is
      // gone from this device.
      if (_openedFor case final was?) {
        store == null ? SyncKey.release(was) : await SyncKey.forget(was);
      }
      _opening = null;
      _openedFor = store?.id;
    }
    if (rs == null || store == null) return;
    final SegmentSync sync;
    try {
      sync = await (_opening ??= _open(rs, store.id));
      // The password still opens the key: nothing syncs while it does not.
      await keyOf(rs);
    } catch (e, s) {
      // Opened again next time: the password or the network may be there by
      // then. None set is the backup page's to ask for, as the backup's own
      // sync leaves it.
      _opening = null;
      if (e is! SyncPasswordMismatch && e is! RemoteBackupPasswordMissing) {
        Loggers.app.warning('File log sync: opening', e, s);
      }
      return;
    }
    try {
      await sync.sync();
    } catch (e, s) {
      Loggers.app.warning('File log sync', e, s);
    }
  }

  static Future<SegmentSync> _open(RemoteStorage rs, String id) async {
    final key = await keyOf(rs);
    SegmentSync.bind(id);
    return SegmentSync(_storeOf(rs)!.files, key, carries: syncCarries);
  }

  /// The key or the store changed: opened again for the next sync.
  static void reset() {
    _soon?.cancel();
    _opening = null;
  }
}
