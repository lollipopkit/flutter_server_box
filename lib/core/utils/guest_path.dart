import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:path/path.dart' as p;

/// The host path a guest path names, or null when it names nothing inside.
///
/// The Agent's file tools are `dart:io` on the host — they never enter the
/// guest — so without this a model that was told it is inside a container would
/// be reading the phone. That matters more than it sounds: the file tools are
/// the one pair that is deliberately *not* reviewed before it runs, on the
/// grounds that reading a file is not a command, and the app's own stores and
/// keys are on the same filesystem.
///
/// [forWrite] resolves the parent instead of the target, because what is being
/// written does not exist yet.
///
/// Shared by both userlands rather than owned by either. Android unpacks a
/// rootfs and enters it with proot, iOS runs an interpreter over an ordinary
/// directory tree, and neither difference reaches this: a guest path is a path
/// under a root, and what has to be refused is a way out of it.
Future<String?> resolveWithinRoot(
  String root,
  String guest, {
  bool forWrite = false,
}) async {
  // Guest paths are absolute; a relative one has no meaning here, since the
  // guest's working directory is not this process's.
  if (!guest.startsWith('/')) return null;

  // Lexical first: `..` is resolved against the guest's root, so `/../etc`
  // is `/etc` inside rather than an escape to be caught later.
  final parts = <String>[];
  for (final segment in guest.split('/')) {
    switch (segment) {
      case '' || '.':
        continue;
      case '..':
        if (parts.isNotEmpty) parts.removeLast();
      default:
        parts.add(segment);
    }
  }

  // Resolved, not compared as written: on Android `/data/user/0` is a symlink
  // to `/data/data`, so the root itself has two spellings and a string
  // comparison would reject everything.
  final String base;
  try {
    base = await Directory(root).resolveSymbolicLinks();
  } catch (_) {
    // No rootfs on disk. Nothing is inside a directory that is not there.
    return null;
  }
  if (parts.isEmpty) return base;

  // The guest's separator is `/` and the host's is whatever it is. Everything
  // above split a guest path and so is `/`; from here down these are host
  // paths, and `resolveSymbolicLinks` answers in the host's spelling — on
  // Windows a `\` one, which a `/` comparison below would never match.
  final separator = Platform.pathSeparator;
  final host = [base, ...parts].join(separator);
  // And resolved again at the end, because a symlink *inside* the rootfs can
  // point out of it — `ln -s / /tmp/out` is one reviewed command away, and
  // `File.readAsBytes` would follow it without asking anybody.
  final toResolve = forWrite
      ? host.substring(0, host.lastIndexOf(separator))
      : host;
  String? real;
  try {
    real = await Directory(toResolve).resolveSymbolicLinks();
  } on FileSystemException {
    // A file, not a directory — or nothing at all. `File` resolves the first
    // and refuses the second, which is the answer either way.
    try {
      real = await File(toResolve).resolveSymbolicLinks();
    } catch (_) {
      return null;
    }
  }
  if (real != base && !real.startsWith('$base$separator')) return null;
  return forWrite ? '$real$separator${parts.last}' : real;
}

/// Returns a regular-file destination inside [root], creating missing parent
/// directories without following archive-provided links.
///
/// Rootfs installation writes a handful of trusted configuration files after
/// extraction. A tar member may already occupy one of those final paths with
/// a symlink, so an ordinary [File.writeAsString] would follow it outside the
/// tree even when every parent is confined.
Future<File> rootfsFileForWrite(
  String root,
  String guestPath, {
  bool replaceFinalSymlink = false,
}) async {
  if (!guestPath.startsWith('/')) {
    throw ArgumentError.value(guestPath, 'guestPath', 'must be absolute');
  }

  final parts = <String>[];
  for (final segment in guestPath.split('/')) {
    switch (segment) {
      case '' || '.':
        continue;
      case '..':
        if (parts.isEmpty) {
          throw StateError('Rootfs write escapes the root: $guestPath');
        }
        parts.removeLast();
      default:
        parts.add(segment);
    }
  }
  if (parts.isEmpty) {
    throw StateError('Rootfs write does not name a file: $guestPath');
  }

  final base = await Directory(root).resolveSymbolicLinks();
  var parent = base;
  for (final segment in parts.take(parts.length - 1)) {
    parent = '$parent${Platform.pathSeparator}$segment';
    switch (await FileSystemEntity.type(parent, followLinks: false)) {
      case FileSystemEntityType.notFound:
        await Directory(parent).create();
        break;
      case FileSystemEntityType.directory:
        break;
      case FileSystemEntityType.link:
        throw StateError('Rootfs write has a symlinked parent: $guestPath');
      default:
        throw StateError('Rootfs write has a non-directory parent: $guestPath');
    }
  }

  final target = '$parent${Platform.pathSeparator}${parts.last}';
  final type = await FileSystemEntity.type(target, followLinks: false);
  if (type == FileSystemEntityType.link && replaceFinalSymlink) {
    String resolved;
    try {
      final linkTarget = await Link(target).target();
      final guestCandidate = linkTarget.startsWith('/')
          ? p.joinAll([
              base,
              ...p.posix
                  .normalize(linkTarget)
                  .split('/')
                  .where((part) => part.isNotEmpty && part != '.'),
            ])
          : null;
      final candidate =
          guestCandidate ??
          (p.isAbsolute(linkTarget)
              ? p.normalize(linkTarget)
              : p.normalize(p.join(parent, linkTarget)));
      try {
        resolved = await File(candidate).resolveSymbolicLinks();
      } on FileSystemException {
        if (guestCandidate == null || !p.isAbsolute(linkTarget)) rethrow;
        resolved = await File(p.normalize(linkTarget)).resolveSymbolicLinks();
      }
    } catch (_) {
      throw StateError('${libL10n.fail}: ${libL10n.path} ($guestPath)');
    }
    final separator = Platform.pathSeparator;
    if (resolved != base && !resolved.startsWith('$base$separator')) {
      throw StateError('${libL10n.invalid}: ${libL10n.path} ($guestPath)');
    }
    await Link(target).delete();
  } else if (type == FileSystemEntityType.link ||
      type == FileSystemEntityType.directory) {
    throw StateError('Rootfs write target is not a regular file: $guestPath');
  }
  return File(target);
}
