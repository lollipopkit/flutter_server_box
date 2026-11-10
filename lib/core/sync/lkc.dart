import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/theme.dart' show ThemeBlobStore;
import 'package:flutter/foundation.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/core/sync/lkc_log.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/backup_reader.dart';
import 'package:server_box/data/res/misc.dart';

/// Theme packages kept apart from the backup on LK Cloud: `blob-<name>.age`
/// each, sealed to the account's sync key as the backup is. The name is the
/// package keyed by that key (`fl_sync::blob_name`): equal packages are kept
/// once, and homebase never learns which theme it holds. The backup's entry
/// names it.
final class LkcThemeBlobs implements ThemeBlobStore {
  LkcThemeBlobs._();

  static final shared = LkcThemeBlobs._();

  /// Where a restore can fetch a kept package from: signed in, whatever the
  /// backup came from.
  static ThemeBlobStore? get available =>
      Lkc.enabled && Lkc.client.signedIn ? shared : null;

  static const _prefix = 'blob-';

  /// A blob no backup names is removed this long after it was written: a
  /// device may have just put one there for a write of the backup still to
  /// come.
  static const _grace = Duration(days: 1);

  LkcSync? _sync;

  /// The blobs on homebase and when each was written, read once per backup.
  Map<String, DateTime?>? _listed;

  /// The blobs the backup being written names.
  final _used = <String>{};

  Future<LkcSync> get _client async => _sync ??= await Lkc.client.sync(Lkc.app);

  /// Before a backup is written.
  void begin() {
    _listed = null;
    _used.clear();
  }


  Future<Map<String, DateTime?>> _list() async {
    final files = await (await _client).list();
    return {
      for (final f in files)
        if (f.name.startsWith(_prefix)) f.name: DateTime.tryParse(f.updatedAt),
    };
  }

  @override
  Future<String> put(String id, Uint8List bytes) async {
    final listed = _listed ??= await _list();
    final client = await _client;
    final key = await lkcLog.key();
    final name = '$_prefix${key.nameOf(data: bytes)}.age';
    _used.add(name);
    if (listed.containsKey(name)) return name;
    final sealed = key.seal(plain: bytes);
    final dir = await Directory.systemTemp.createTemp('sb-theme-blob-');
    try {
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(sealed, flush: true);
      await client.upload(name: name, from: file.path);
    } on LkcSyncError catch (e) {
      // Put there meanwhile by another device: the same package.
      if (e.kind != LkcSyncErrorKind.changed) rethrow;
    } finally {
      await dir.delete(recursive: true);
    }
    listed[name] = DateTime.now();
    return name;
  }

  @override
  Future<Uint8List> get(String id, String name) async {
    final dir = await Directory.systemTemp.createTemp('sb-theme-blob-');
    try {
      final path = '${dir.path}/$name';
      final fetched = await (await _client).download(name: name, to: path);
      if (fetched.missing) throw StateError('Theme package $name is gone');
      // A restore: a key file is not made for it on an account that never synced.
      return await (await lkcLog.key(create: false)).open(sealed: await File(path).readAsBytes());
    } finally {
      await dir.delete(recursive: true);
    }
  }

  /// Marks [names] named by the backup being written: carried from another
  /// device's ([BakSyncer] leaving the themes out).
  void keep(Iterable<String> names) => _used.addAll(names);

  /// The packages [backup]'s themes name.
  static Iterable<String> namedBy(BackupV2 backup) => [
    for (final entry in backup.themes.values)
      if (entry case {'blob': final String name}) name,
  ];

  /// Once the backup naming [_used] is written: the blobs no backup names
  /// any more, past [_grace]. Best effort, the next backup tries again.
  Future<void> sweep() async {
    try {
      final sync = await _client;
      // What [put] listed is enough: a blob written since is within [_grace].
      final listed = _listed ?? await _list();
      final before = DateTime.now().subtract(_grace);
      final unused = [
        for (final MapEntry(key: name, value: at) in listed.entries)
          if (!_used.contains(name) && at != null && at.isBefore(before)) name,
      ];
      if (unused.isEmpty) return;
      // The versions LK Cloud keeps of the backup can be restored too.
      final kept = await _keptByVersions(sync);
      for (final name in unused) {
        if (!kept.contains(name)) await sync.delete(name: name);
      }
    } catch (e, s) {
      Loggers.app.warning('LK Cloud theme blobs sweep', e, s);
    }
  }

  /// The blobs the kept versions of the backup name. Throws when one cannot
  /// be read, so nothing is removed that one of them might name.
  Future<Set<String>> _keptByVersions(LkcSync sync) async {
    final names = <String>{};
    final key = await lkcLog.key();
    final dir = await Directory.systemTemp.createTemp('sb-theme-blob-');
    try {
      final path = '${dir.path}/version';
      for (final v in await sync.versions(name: Miscs.bakFileName)) {
        final fetched = await sync.downloadVersion(
          name: Miscs.bakFileName,
          etag: v.etag,
          to: path,
        );
        // Gone since it was listed: nothing to restore from it.
        if (fetched.missing) continue;
        final plain = await key.open(sealed: await File(path).readAsBytes());
        final (backup, _) = BackupReader.fromBytes(plain);
        if (backup is! BackupV2) continue;
        names.addAll(namedBy(backup));
      }
    } finally {
      await dir.delete(recursive: true);
    }
    return names;
  }

}

/// Restores fetch the theme packages a backup keeps apart from LK Cloud.
void installThemeBlobs() => BackupThemeBlobs.source = () => LkcThemeBlobs.available;
