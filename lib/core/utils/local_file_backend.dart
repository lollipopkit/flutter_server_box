import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:server_box/data/model/file/file_backend.dart';

/// [FileBackend] on the device the app is running on.
///
/// No connection, no authentication, and no failure worth retrying: what this
/// cannot do, it cannot do because the OS said so.
class LocalFileBackend implements FileBackend {
  const LocalFileBackend();

  @override
  FileBackendTraits get traits => const FileBackendTraits(
    // `FileStat.mode` is there on POSIX and meaningless on Windows, and this
    // one class serves both. Reported as absent rather than as a number that
    // means nothing on half the platforms it runs on.
    permissions: false,
    symlinks: true,
    // Nothing to escalate to. A local shell runs as whoever runs the app, so
    // "try again with sudo" would be the same user asking twice.
    sudoFallback: false,
  );

  @override
  Future<List<FileEntry>> list(String path) async {
    final dir = Directory(_native(path));
    final entries = <FileEntry>[];
    await for (final entity in dir.list(followLinks: false)) {
      entries.add(await _entryOf(entity));
    }
    return entries;
  }

  @override
  Future<FileEntry?> stat(String path) async {
    final native = _native(path);
    final stat = await FileStat.stat(native);
    // `FileStat.stat` answers `notFound` both for something absent and for a
    // path whose parent cannot be traversed. Only the first is null here; the
    // second surfaces when the caller does something with it.
    if (stat.type == FileSystemEntityType.notFound) return null;
    return FileEntry(
      name: p.basename(native),
      kind: _kindOf(stat.type),
      size: stat.size < 0 ? null : stat.size,
      modified: stat.modified,
    );
  }

  @override
  Future<void> mkdir(String path) =>
      Directory(_native(path)).create(recursive: false);

  @override
  Future<void> remove(String path, {bool recursive = false}) async {
    final native = _native(path);
    final type = await FileSystemEntity.type(native, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(native).delete(recursive: recursive);
      return;
    }
    // A link is deleted, never followed: removing what it points at is not
    // what anyone means by deleting a shortcut.
    await Link(native).exists()
        ? await Link(native).delete()
        : await File(native).delete();
  }

  @override
  Future<void> rename(String from, String to) async {
    final native = _native(from);
    final target = _native(to);
    final type = await FileSystemEntity.type(native, followLinks: false);
    switch (type) {
      case FileSystemEntityType.directory:
        await Directory(native).rename(target);
      case FileSystemEntityType.link:
        await Link(native).rename(target);
      default:
        await File(native).rename(target);
    }
  }

  @override
  Future<void> chmod(String path, int mode) async {
    // `traits.permissions` says so, and `dart:io` has no chmod anyway.
    throw UnsupportedError('This device does not expose file permissions');
  }

  @override
  Stream<List<int>> read(String path, {int offset = 0}) =>
      File(_native(path)).openRead(offset);

  @override
  Future<void> write(String path, Stream<List<int>> data, {int? size}) async {
    final native = _native(path);
    // Beside the destination, not in a temp directory: a rename across
    // filesystems is a copy, and this one has to be the cheap kind for the
    // atomicity to be worth anything.
    final staging = File('$native.${_stagingSuffix()}');
    try {
      final sink = staging.openWrite();
      try {
        await sink.addStream(data);
        await sink.close();
      } catch (_) {
        // Closing a sink whose stream failed throws "File closed", which would
        // replace the error worth reporting with one about the cleanup.
        try {
          await sink.close();
        } catch (_) {}
        rethrow;
      }
      await staging.rename(native);
    } catch (_) {
      // A failed write leaves nothing behind, including its own leftovers.
      if (await staging.exists()) {
        try {
          await staging.delete();
        } catch (_) {
          // Best effort; the original error is the one worth reporting.
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> close() async {}

  static var _staging = 0;

  String _stagingSuffix() => 'sb-part-${_staging++}';

  /// POSIX in, whatever this platform uses out.
  ///
  /// The interface is POSIX-shaped so that a path can be handed from one
  /// backend to another without asking which; Windows is converted here, at
  /// the one place that knows it is Windows.
  ///
  /// Public because the things only this device can do — handing a path to the
  /// editor, to the share sheet — take a native one, and they should not each
  /// re-derive the rule.
  static String nativePath(String path) =>
      Platform.isWindows ? path.replaceAll('/', r'\') : path;

  static String _native(String path) => nativePath(path);

  static Future<FileEntry> _entryOf(FileSystemEntity entity) async {
    final stat = await entity.stat();
    final kind = entity is Link
        ? FileKind.link
        : _kindOf(stat.type);
    return FileEntry(
      name: p.basename(entity.path),
      kind: kind,
      size: kind == FileKind.file && stat.size >= 0 ? stat.size : null,
      modified: stat.modified,
      linkTarget: entity is Link ? await _targetOf(entity) : null,
    );
  }

  static Future<String?> _targetOf(Link link) async {
    try {
      return await link.target();
    } on FileSystemException {
      // A link to nowhere is still a link, and still worth listing.
      return null;
    }
  }

  static FileKind _kindOf(FileSystemEntityType type) => switch (type) {
    FileSystemEntityType.directory => FileKind.dir,
    FileSystemEntityType.file => FileKind.file,
    FileSystemEntityType.link => FileKind.link,
    _ => FileKind.other,
  };
}
