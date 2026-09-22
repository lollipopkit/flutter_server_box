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
  static Future<String>? _ensuring;

  /// Creates [Paths.file], copies in anything the documents-directory release
  /// left, and answers with it.
  ///
  /// Idempotent, and cheap enough to call on every entry into a browser or a
  /// transfer. Throws what [Directory.create] throws, so a refused permission
  /// reaches the caller instead of turning into an empty directory listing.
  static Future<String> ensure() => _ensuring ??= _ensure().whenComplete(() {
    _ensuring = null;
  });

  static Future<String> _ensure() async {
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
  /// Existing names win and the source remains untouched. This is also the
  /// safe primitive for a future user-selected external folder after that
  /// folder's persistent permission is available.
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
      try {
        if (await _copyAtomically(entity, dest)) imported++;
      } catch (e, s) {
        // One unreadable or damaged legacy entry must not hide every usable
        // one after it. The source remains in place, so a later open can retry
        // any entry whose destination was not published.
        Loggers.app.warning('Import ${entity.path} into $dest', e, s);
      }
    }
    return imported;
  }

  static Future<bool> _copyAtomically(
    FileSystemEntity entity,
    String dest,
  ) async {
    // A symlink could escape the browser root after import. The automatic
    // migration copies data, not filesystem topology supplied by a user.
    if (entity is Link) return false;

    // `createTemp` is the filesystem's unique-name operation. Keeping the
    // payload below that owned directory also means cleanup never guesses from
    // a destination-derived name.
    final stagingRoot = await Directory(
      Paths.file,
    ).createTemp('.serverbox-import-');
    final staging = stagingRoot.path.joinPath('payload');

    try {
      await _copy(entity, staging);
      return await _publishNoReplace(entity, staging, dest);
    } finally {
      // This exact directory was created by this invocation. Nothing else is
      // ever treated as stale import work or removed.
      if (await stagingRoot.exists()) {
        await stagingRoot.delete(recursive: true);
      }
    }
  }

  /// Publishes [staging] without replacing anything already at [dest].
  ///
  /// Files use the filesystem's exclusive-create operation. Directories are
  /// materialized recursively and every child is published the same way, so a
  /// writer that wins any name keeps it. App writers await [ensure], which also
  /// keeps them out until this compatibility import has finished.
  static Future<bool> _publishNoReplace(
    FileSystemEntity source,
    String staging,
    String dest,
  ) async {
    switch (source) {
      case File():
        RandomAccessFile? output;
        var created = false;
        try {
          final destination = await File(dest).create(exclusive: true);
          created = true;
          output = await destination.open(mode: FileMode.writeOnly);
          await for (final chunk in File(staging).openRead()) {
            await output.writeFrom(chunk);
          }
          return true;
        } on PathExistsException {
          return false;
        } on FileSystemException {
          if (!created &&
              await FileSystemEntity.type(dest, followLinks: false) !=
                  FileSystemEntityType.notFound) {
            return false;
          }
          if (created) {
            await output?.close();
            output = null;
            await File(dest).delete();
          }
          rethrow;
        } catch (_) {
          if (created) {
            await output?.close();
            output = null;
            await File(dest).delete();
          }
          rethrow;
        } finally {
          await output?.close();
        }
      case Directory():
        if (await FileSystemEntity.type(dest, followLinks: false) !=
            FileSystemEntityType.notFound) {
          return false;
        }
        await Directory(dest).create();
        await for (final child in Directory(staging).list(followLinks: false)) {
          final name = child.path.getFileName();
          if (name == null || child is Link) continue;
          await _publishNoReplace(
            child,
            child.path,
            Directory(dest).path.joinPath(name),
          );
        }
        return true;
      case Link():
        return false;
      default:
        return false;
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
