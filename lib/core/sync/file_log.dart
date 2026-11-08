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

  /// Read on each call: its client is made again when the settings change.
  final Webdav _webdav;

  WebdavClient get _client => _webdav.client ?? (throw StateError('WebDAV is not set up'));

  String get _dir => '${_webdav.prefix}$_folder/';

  Future<void>? _made;

  Future<void> _mkdir() => _made ??= _client.mkdirAll(_dir).catchError((Object e, StackTrace s) {
    _made = null;
    Error.throwWithStackTrace(e, s);
  });

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
/// order writes: two devices that make a key at once each write theirs, and
/// [SyncKey.refresh] merges them.
final class FilesKeyFile implements SyncKeyFile {
  FilesKeyFile(this._files, this.id);

  final SyncFiles _files;

  static const _name = 'identity.age';

  /// The store's: another store's keys are not taken to it.
  @override
  final String id;

  @override
  PrefProp<bool> get rewrap => SyncKey.filesRewrap;

  @override
  Future<Uint8List?> read() => _files.getBlob(_name);

  @override
  Future<bool> write(Uint8List body, {required bool replace}) async {
    if (!replace && await _files.getBlob(_name) != null) return false;
    await _files.write(_name, body);
    return true;
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

  /// The store the backup syncs to, when it is one of these.
  static ({String id, SyncFiles files})? _store() => switch (bakSync.remoteStorage) {
    final ICloud icloud => (id: 'icloud:${icloud.containerId}', files: ICloudSyncFiles(icloud)),
    // Named by a keyed hash: no endpoint written to device-local state again.
    final Webdav webdav when webdav.client != null => (
      id: 'webdav:${syncBlobName(
        secret: _folder,
        data: utf8.encode('${webdav.identity}|${SyncRemotes.webdavUser}'),
      )}',
      files: WebdavSyncFiles(webdav),
    ),
    _ => null,
  };

  static bool get _on => (PrefProps.icloudSync.get() && isICloudSupported) || PrefProps.webdavSync.get();

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
    final store = _on ? _store() : null;
    if (store?.id != _openedFor) {
      // Not this device's to sync any more: what was said of its key goes.
      if (_openedFor case final was?) SyncKey.forgetMismatch(was);
      _opening = null;
      _openedFor = store?.id;
    }
    if (store == null) return;
    final SegmentSync sync;
    try {
      sync = await (_opening ??= _open(store));
    } catch (e, s) {
      // Opened again next time: the password or the network may be there by
      // then. None set is the backup page's to ask for, as the backup's own
      // sync leaves it.
      _opening = null;
      if (e is! RemoteBackupPasswordMissing) Loggers.app.warning('File log sync: opening', e, s);
      return;
    }
    try {
      await sync.sync();
    } catch (e, s) {
      Loggers.app.warning('File log sync', e, s);
    }
  }

  static Future<SegmentSync> _open(({String id, SyncFiles files}) store) async {
    final key = await SyncKey.load(FilesKeyFile(store.files, store.id));
    SegmentSync.bind(store.id);
    return SegmentSync(
      store.files,
      key,
      carries: syncCarries,
    );
  }

  /// The key or the store changed: opened again for the next sync.
  static void reset() {
    _soon?.cancel();
    _opening = null;
  }
}
