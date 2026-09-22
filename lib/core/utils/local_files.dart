import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/res/build_data.dart';

/// [Paths.file] — this device's files, as the browser and the transfers see
/// it.
///
/// Everything goes through [ensure] rather than through `Paths.file` alone so
/// files from the short-lived user-documents location can be imported without
/// making that protected directory the browser's root.
abstract final class LocalFiles {
  /// Creates [Paths.file], copies in anything the documents-directory release
  /// left, and answers with it.
  ///
  /// Idempotent, and cheap enough to call on every entry into a browser or a
  /// transfer. Throws what [Directory.create] throws, so a refused permission
  /// reaches the caller instead of turning into an empty directory listing.
  static Future<String> ensure() async {
    final dir = await Paths.ensureFile();
    await _importLegacyDocuments();
    return dir.path;
  }

  /// Copies files from the documents-directory release into app-owned storage.
  ///
  /// The source stays in place. It is user-visible data, and deleting it during
  /// an automatic compatibility import would make a mistaken path decision
  /// unrecoverable. Existing destination names win.
  ///
  /// Best-effort: macOS may refuse Documents access. The Device browser still
  /// opens on its own directory, and a later launch can retry after access is
  /// granted.
  ///
  /// TODO: remove after no supported install can have used the documents path.
  static Future<void> _importLegacyDocuments() async {
    if (!isLinux && !isWindows && !(isMacOS && !Pfs.isMacSandboxed)) return;

    final legacyPath = await Paths.userFilesPath(BuildData.name);
    if (legacyPath == Paths.file) return;

    try {
      await importFrom(legacyPath);
    } catch (e, s) {
      Loggers.app.warning('Import $legacyPath into ${Paths.file}', e, s);
    }
  }

  /// Copies missing top-level entries from [sourcePath] into the Device root.
  ///
  /// Existing names win, the source remains untouched, and each entry appears
  /// atomically. This is also the safe primitive for a future user-selected
  /// external folder after that folder's persistent permission is available.
  static Future<int> importFrom(String sourcePath) async {
    final src = Directory(sourcePath);
    if (src.path == Paths.file || !await src.exists()) return 0;

    var imported = 0;
    await for (final entity in src.list(followLinks: false)) {
      final name = entity.path.getFileName();
      if (name == null || entity is Link) continue;
      final dest = Paths.file.joinPath(name);
      // Whatever is already there was put there by this build, so it is the
      // newer of the two and must not be overwritten.
      final existing = await FileSystemEntity.type(dest, followLinks: false);
      if (existing != FileSystemEntityType.notFound) continue;
      await _copyAtomically(entity, dest);
      imported++;
    }
    return imported;
  }

  static Future<void> _copyAtomically(
    FileSystemEntity entity,
    String dest,
  ) async {
    // A symlink could escape the browser root after import. The automatic
    // migration copies data, not filesystem topology supplied by a user.
    if (entity is Link) return;

    final staging = '$dest.importing';
    final stale = await FileSystemEntity.type(staging, followLinks: false);
    await _delete(staging, stale);

    try {
      await _copy(entity, staging);
      switch (entity) {
        case File():
          await File(staging).rename(dest);
        case Directory():
          await Directory(staging).rename(dest);
        case Link():
          break;
      }
    } catch (_) {
      final partial = await FileSystemEntity.type(staging, followLinks: false);
      await _delete(staging, partial);
      rethrow;
    }
  }

  static Future<void> _delete(String path, FileSystemEntityType type) async {
    switch (type) {
      case FileSystemEntityType.file:
        await File(path).delete();
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
      case FileSystemEntityType.link:
        await Link(path).delete();
      case FileSystemEntityType.notFound:
      case FileSystemEntityType.pipe:
      case FileSystemEntityType.unixDomainSock:
        break;
    }
  }

  static Future<void> _copy(FileSystemEntity entity, String dest) async {
    switch (entity) {
      case final File file:
        await file.copy(dest);
      case final Directory directory:
        final out = await Directory(dest).create(recursive: true);
        await for (final child in directory.list(followLinks: false)) {
          final name = child.path.getFileName();
          if (name == null) continue;
          await _copy(child, out.path.joinPath(name));
        }
      case Link():
        break;
    }
  }
}
