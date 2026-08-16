import 'dart:io';

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

  final host = [base, ...parts].join('/');
  // And resolved again at the end, because a symlink *inside* the rootfs can
  // point out of it — `ln -s / /tmp/out` is one reviewed command away, and
  // `File.readAsBytes` would follow it without asking anybody.
  final toResolve = forWrite ? host.substring(0, host.lastIndexOf('/')) : host;
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
  if (real != base && !real.startsWith('$base/')) return null;
  return forWrite ? '$real/${parts.last}' : real;
}
