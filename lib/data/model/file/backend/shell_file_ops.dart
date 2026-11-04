import 'package:server_box/data/model/file/file_backend.dart';
import 'package:server_box/src/rust/api/files.dart' as ffi;

/// Reading a filesystem's shape with nothing but a POSIX shell, by the
/// commands and the reader in `sbm_parser::files`.
///
/// `SftpFileBackend` escalates a refused listing through `sudo`, where only a
/// command will do; `ScpFileBackend` has no protocol for metadata at all, so
/// this is its normal path.

/// One directory level.
String shellListCommand(String path) => ffi.filesListCommand(path: path);

final _markers = ffi.filesStatMarkers();

/// What the stat command (`sbm_parser::files::stat_command`) prints when there
/// is nothing at the path.
final kShellStatAbsentMark = _markers.absentMark;

/// What the stat command prints when it could not look.
final kShellStatDeniedMark = _markers.deniedMark;

/// The stat command found nothing at the path.
final kShellStatAbsent = _markers.absentExit;

/// The stat command could not look.
final kShellStatDenied = _markers.deniedExit;

/// Every entry [shellListCommand] or the stat command printed.
///
/// Throws [ShellFileRecordException] for output that is not a listing: one cut
/// short, which would otherwise read as a complete one, or one that is not
/// these commands' at all.
List<FileEntry> parseShellFileRecords(String output) {
  final List<ffi.ShellFileRecord> records;
  try {
    records = ffi.filesParseRecords(output: output);
  } on String catch (e) {
    throw ShellFileRecordException(e);
  }
  return [
    for (final r in records)
      FileEntry(
        name: r.name,
        kind: FileKind.values.byName(r.kind),
        size: r.size,
        modified: shellFileTime(r.mtime),
        mode: r.mode,
      ),
  ];
}

/// The far side's output is not a listing this can read.
///
/// Distinct from a command that failed, which says so in its own words: this
/// is a command that reported success and printed something else.
final class ShellFileRecordException implements Exception {
  const ShellFileRecordException(this.message);

  final String message;

  @override
  String toString() => 'Unreadable listing: $message';
}

/// `stat -c %Y` counts seconds; the rest of the app counts milliseconds.
DateTime? shellFileTime(int? seconds) => seconds == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

/// `mv`, refusing a destination that is a directory: `mv a b` moves `a` into
/// `b` when it is one, where SFTP's own rename refuses.
String shellRenameCommand(String from, String to) =>
    ffi.filesRenameCommand(from: from, to: to);
