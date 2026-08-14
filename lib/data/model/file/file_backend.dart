import 'package:meta/meta.dart';

/// What a directory listing can say about one entry.
///
/// The union of what `FileSystemEntity` and `SftpName` know, which is not the
/// same set: this device reports no owner and no mode, and a server reports no
/// distinction between a file it cannot stat and one that is not there. What
/// only one side can answer is nullable here and declared in
/// [FileBackendTraits], so a page can leave a column out rather than draw it
/// empty.
@immutable
class FileEntry {
  const FileEntry({
    required this.name,
    required this.kind,
    this.size,
    this.modified,
    this.mode,
    this.linkTarget,
  });

  /// The last component, never a path. Where an entry lives is the business of
  /// whoever asked for the listing.
  final String name;

  final FileKind kind;

  /// Null where the backend did not say — a directory over SFTP often has no
  /// meaningful one, and neither does anything this device refused to stat.
  final int? size;

  final DateTime? modified;

  /// POSIX permission bits, or null on a backend with no notion of them.
  final int? mode;

  /// Where a symlink points, when the backend resolved it. Null for anything
  /// that is not one, and for backends that do not follow links.
  final String? linkTarget;

  bool get isDir => kind == FileKind.dir;
}

enum FileKind { file, dir, link, other }

/// What a backend can and cannot do.
///
/// Asked rather than inferred from the runtime type: "does this have
/// permissions" is a question about the filesystem behind it, and the page that
/// draws a permission row should not be reading a class name to decide.
@immutable
class FileBackendTraits {
  const FileBackendTraits({
    this.permissions = false,
    this.symlinks = false,
    this.sudoFallback = false,
    this.randomAccessReads = false,
  });

  /// Entries carry [FileEntry.mode], and it can be changed.
  final bool permissions;

  /// Entries can be links, and [FileEntry.linkTarget] may be set.
  final bool symlinks;

  /// A refused operation can be retried through a shell with sudo. Only a
  /// backend that has a shell behind it can offer this; see `sftp_sudo.dart`.
  final bool sudoFallback;

  /// [FileBackend.read] honours its `offset`, so an interrupted transfer can
  /// be resumed rather than restarted.
  final bool randomAccessReads;
}

/// Somewhere files live.
///
/// The third of this app's "where do the bytes come from" seams, beside
/// `ShellBackend` and `ServerExec`. Everything above it — the browser, the
/// transfer engine — is written against these seven methods, so that a second
/// kind of storage is a class rather than a branch in every page.
///
/// Paths are POSIX-shaped and absolute at this boundary, including on Windows,
/// where [LocalFileBackend] converts at its own edge. A backend is free to be
/// case-insensitive; nothing above assumes either way.
abstract interface class FileBackend {
  FileBackendTraits get traits;

  Future<List<FileEntry>> list(String path);

  /// Null when there is nothing there. Anything else — no permission, a broken
  /// link — throws, because "absent" and "unreadable" are different answers and
  /// a caller that conflates them deletes the wrong thing.
  Future<FileEntry?> stat(String path);

  Future<void> mkdir(String path);

  /// [recursive] is required for a directory with anything in it. Backends that
  /// cannot do it in one call do it themselves rather than making every caller
  /// walk the tree — SFTP's `rmdir` is the reason this parameter exists.
  Future<void> remove(String path, {bool recursive = false});

  Future<void> rename(String from, String to);

  /// The bytes, from [offset]. A backend without [FileBackendTraits.randomAccessReads]
  /// must throw for a non-zero one rather than quietly returning the whole file.
  Stream<List<int>> read(String path, {int offset = 0});

  /// Writes [data] to [path], replacing whatever was there.
  ///
  /// Atomic from a reader's point of view: the implementation writes elsewhere
  /// and renames, so a transfer that dies halfway leaves no half-file under the
  /// name something else is about to open. [size] is a hint for progress and
  /// pre-allocation, not a contract.
  Future<void> write(String path, Stream<List<int>> data, {int? size});

  /// Releases whatever this holds. A backend may be used again afterwards only
  /// if its own documentation says so.
  Future<void> close();
}
